"""Offline graph checks; YAML parser may be supplied by the caller's vendor path."""
from pathlib import Path
import json
import os
import re
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]


def workflow(name):
    # BaseLoader avoids YAML 1.1 treating the GitHub `on` key as a boolean.
    return yaml.load((ROOT / 'workflows' / name).read_text(), Loader=yaml.BaseLoader)


class WorkflowTests(unittest.TestCase):
    def assert_build_invocations(self, version, build):
        builds = workflow('release-build.yml')
        invocations = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = root / 'arguments.json'
            # Execute the workflow's real shell block. Stub only the expensive
            # compiler so argument construction runs under the runner's Bash.
            flutter = root / 'flutter'
            flutter.write_text(
                '#!/usr/bin/env python3\n'
                'import json, os, sys\n'
                'from pathlib import Path\n'
                'Path(os.environ["BUILD_ARGUMENTS"]).write_text(json.dumps(sys.argv[1:]))\n')
            flutter.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                       PILOT_BUILD_VERSION=version, PILOT_BUILD_NUMBER=build,
                       BUILD_ARGUMENTS=str(capture))
            for job in builds['jobs'].values():
                for step in job.get('steps', []):
                    script = step.get('run', '')
                    if not re.search(r'^\s*flutter build ', script, re.M):
                        continue
                    script = re.sub(r'\$\{\{.*?\}\}', 'fixture', script)
                    with self.subTest(step=step['name'], version=version):
                        result = subprocess.run(['/bin/bash', '-c', script], env=env,
                                                text=True, capture_output=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        actual = json.loads(capture.read_text())
                        command = next(line.strip() for line in script.splitlines()
                                       if line.strip().startswith('flutter build '))
                        fixed_arguments = command.removeprefix('flutter ').rsplit(' ', 1)[0].split()
                        overrides = ['--build-name', version, '--build-number', build] if version else []
                        self.assertEqual(actual, fixed_arguments + overrides)
                        invocations.append(step['name'])
        self.assertEqual(len(invocations), 5)

    def test_build_shell_without_version_overrides(self):
        self.assert_build_invocations('', '')

    def test_build_shell_with_version_overrides(self):
        self.assert_build_invocations('0.3.2', '1792423078')

    def test_five_inputs_and_exact_run_marker(self):
        w = workflow('pilot-release.yml')
        self.assertEqual(set(w['on']['workflow_dispatch']['inputs']),
                         {'target_sha', 'release_batch_id', 'task_manifest_json', 'task_manifest_sha256', 'tag_name'})
        self.assertEqual(w['run-name'], 'pilot-release-${{ inputs.release_batch_id }}')
        self.assertNotIn('concurrency', w)  # Do not replace a pending batch.
        for spec in w['on']['workflow_dispatch']['inputs'].values():
            self.assertEqual(spec, dict(spec, type='string', required='true'))

    def test_tools_and_sources_are_distinct(self):
        w = workflow('pilot-release.yml')
        for name in ('validate', 'publish'):
            checkout = w['jobs'][name]['steps'][0]
            self.assertEqual(checkout['with']['ref'], '${{ github.workflow_sha }}')
        builds = workflow('release-build.yml')
        self.assertEqual(builds['permissions']['contents'], 'read')
        for name in ('test', 'build-android', 'build-windows', 'build-macos', 'build-ios'):
            steps = builds['jobs'][name]['steps']
            self.assertEqual(steps[0]['with']['ref'], '${{ inputs.target_sha || github.sha }}')
            self.assertEqual(steps[0]['with']['persist-credentials'], 'false')
            self.assertIn('git rev-parse HEAD', steps[1]['run'])
            for step in steps:
                if step.get('name', '').startswith('Build '):
                    self.assertIn('--build-name "$PILOT_BUILD_VERSION"', step['run'])
                    self.assertIn('--build-number "$PILOT_BUILD_NUMBER"', step['run'])

    def test_both_entries_reuse_same_builds_and_legacy_is_stable(self):
        pilot = workflow('pilot-release.yml')
        legacy = workflow('release.yml')
        for w in (pilot, legacy):
            self.assertEqual(w['jobs']['packages']['uses'], './.github/workflows/release-build.yml')
        self.assertEqual(set(legacy['on']), {'push', 'workflow_dispatch'})
        publish = legacy['jobs']['publish-release']
        release = next(step for step in publish['steps'] if step.get('uses', '').startswith('softprops/'))
        self.assertEqual(release['with']['prerelease'], '${{ needs.validate-release.outputs.prerelease }}')
        self.assertIn('packages', publish['needs'])

    def test_legacy_freezes_tag_source_before_build_and_preflights_before_write(self):
        w = workflow('release.yml')
        validation = w['jobs']['validate-release']
        source = validation['steps'][1]
        self.assertEqual(source['with']['ref'], '${{ inputs.tag_name || github.ref }}')
        self.assertEqual(w['jobs']['packages']['with'],
                         {'target_sha': '${{ needs.validate-release.outputs.target_sha }}'})
        scripts = '\n'.join(step.get('run', '') for step in validation['steps'])
        self.assertIn('source-version release-source/pubspec.yaml', scripts)
        self.assertIn('refs/tags/$RELEASE_TAG^{commit}', scripts)
        publish = w['jobs']['publish-release']['steps']
        preflight = next(i for i, step in enumerate(publish) if ' legacy-preflight ' in step.get('run', ''))
        release = next(i for i, step in enumerate(publish) if step.get('uses', '').startswith('softprops/'))
        self.assertLess(preflight, release)
        for step in (publish[preflight], publish[-2]):
            self.assertEqual(step['env']['FROZEN_TARGET_SHA'], '${{ needs.validate-release.outputs.target_sha }}')
            self.assertIn(chr(34) + '$FROZEN_TARGET_SHA' + chr(34), step['run'])
        self.assertEqual(publish[release]['with']['overwrite_files'], 'false')
        self.assertEqual(publish[release]['with']['make_latest'], '${{ needs.validate-release.outputs.make_latest }}')
        self.assertNotIn('if', publish[-1])
        self.assertNotIn('if', publish[-2])
        self.assertIn('legacy-manifest', publish[-2]['run'])
        self.assertIn('release-source/pubspec.yaml release-files', publish[-2]['run'])

    def test_legacy_source_freeze_shell_rejects_head_that_is_not_the_tag(self):
        import os
        import tempfile
        w = workflow('release.yml')
        script = next(step['run'] for step in w['jobs']['validate-release']['steps'] if step.get('id') == 'validate')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'release-source'
            source.mkdir()
            def git(*args):
                return subprocess.run(['git', '-C', str(source), *args], check=True, text=True, capture_output=True)
            git('init'); git('config', 'user.name', 'test'); git('config', 'user.email', 'test@example.invalid')
            (source / 'pubspec.yaml').write_text('version: 1.2.3+7\n')
            git('add', '.'); git('commit', '-m', 'tagged'); git('tag', '--no-sign', 'v1.2.3')
            env = dict(os.environ, EVENT_NAME='workflow_dispatch', INPUT_TAG_NAME='v1.2.3',
                       GITHUB_REF_NAME='main', IS_PRERELEASE='false', GITHUB_OUTPUT=str(root / 'output'))
            result = subprocess.run(['bash', '-c', script], cwd=root, env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('target_sha=' + git('rev-parse', 'HEAD').stdout.strip(), (root / 'output').read_text())
            git('commit', '--allow-empty', '-m', 'untagged')
            result = subprocess.run(['bash', '-c', script], cwd=root, env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_provenance_and_stable_guard(self):
        steps = workflow('pilot-release.yml')['jobs']['publish']['steps']
        artifact = next(step for step in steps if step.get('uses', '').startswith('actions/upload-artifact'))
        self.assertEqual(artifact['with']['name'], 'kaneopilot-provenance')
        self.assertEqual(artifact['with']['path'], 'release-files/kaneopilot-release.json')
        latest = steps[-1]
        self.assertNotIn('if', latest)
        self.assertIn('update-channels pilot-tools release-files/candidate.json', latest['run'])
        self.assertEqual(artifact['with']['overwrite'], 'true')
        prepare = next(i for i, step in enumerate(steps) if ' prepare release-files' in step.get('run', ''))
        upload = next(i for i, step in enumerate(steps) if step.get('uses', '').startswith('actions/upload-artifact'))
        publish = next(i for i, step in enumerate(steps) if ' publish release-files' in step.get('run', ''))
        self.assertLess(prepare, upload)
        self.assertLess(upload, publish)
        for job in workflow('release-build.yml')['jobs'].values():
            for step in job.get('steps', []):
                if step.get('uses', '').startswith('actions/upload-artifact'):
                    self.assertEqual(step['with']['overwrite'], 'true')
        legacy = workflow('release.yml')['jobs']['publish-release']['steps']
        release = next(step for step in legacy if step.get('uses', '').startswith('softprops/'))
        self.assertEqual(release['with']['make_latest'], '${{ needs.validate-release.outputs.make_latest }}')
        self.assertIn('update-channels', legacy[-1]['run'])
        self.assertEqual(release['with']['overwrite_files'], 'false')
        generation = next(step for step in legacy if step.get('name', '').startswith('Generate version manifest'))
        self.assertIn('legacy-manifest', generation['run'])
        self.assertNotIn('sha256sum', generation['run'])

    def test_shell_blocks_parse_and_inputs_are_not_shell_source(self):
        count = 0
        for name in ('pilot-release.yml', 'release-build.yml', 'release.yml'):
            w = workflow(name)
            for job in w['jobs'].values():
                for step in job.get('steps', []):
                    script = step.get('run')
                    if not script: continue
                    self.assertNotIn('${{ inputs.', script)
                    if step.get('shell') == 'pwsh': continue
                    script = re.sub(r'\$\{\{.*?\}\}', 'expression', script)
                    result = subprocess.run(['bash', '-n'], input=script, text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    count += 1
        self.assertGreater(count, 20)

if __name__ == '__main__': unittest.main()
