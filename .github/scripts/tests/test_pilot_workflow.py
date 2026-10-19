"""Offline graph checks; YAML parser may be supplied by the caller's vendor path."""
from pathlib import Path
import re
import subprocess
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]


def workflow(name):
    # BaseLoader avoids YAML 1.1 treating the GitHub `on` key as a boolean.
    return yaml.load((ROOT / 'workflows' / name).read_text(), Loader=yaml.BaseLoader)


class WorkflowTests(unittest.TestCase):
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

    def test_legacy_validates_channel_before_publication(self):
        import os
        import tempfile
        w = workflow('release.yml')
        validation = w['jobs']['validate-release']
        script = next(step['run'] for step in validation['steps'] if step.get('id') == 'validate')
        for tag, channel in [('v1.2.3', 'stable'), ('v1.2.3-beta.1', 'prerelease'),
                             ('v1.2.3.1', 'prerelease'), ('v01.2.3', 'prerelease')]:
            with self.subTest(tag=tag), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'pubspec.yaml').write_text('version: ' + tag[1:] + '+7\n')
                output = root / 'output'
                env = dict(os.environ, EVENT_NAME='workflow_dispatch', INPUT_TAG_NAME=tag, GITHUB_OUTPUT=str(output))
                result = subprocess.run(['bash', '-c', script], cwd=root, env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                values = dict(line.split('=', 1) for line in output.read_text().splitlines())
                self.assertEqual(values['release_channel'], channel)
                self.assertEqual(values['prerelease'], 'false' if channel == 'stable' else 'true')
                self.assertEqual(values['make_latest'], 'legacy' if channel == 'stable' else 'false')
        publish = w['jobs']['publish-release']['steps']
        for step in publish:
            if step.get('name', '').startswith(('Generate version manifest', 'Commit manifest')):
                self.assertEqual(step['if'], "${{ needs.validate-release.outputs.release_channel == 'stable' }}")
        release = next(step for step in publish if step.get('uses', '').startswith('softprops/'))
        self.assertEqual(release['with']['prerelease'], '${{ needs.validate-release.outputs.prerelease }}')
        self.assertEqual(release['with']['make_latest'], '${{ needs.validate-release.outputs.make_latest }}')

    def test_provenance_and_stable_guard(self):
        steps = workflow('pilot-release.yml')['jobs']['publish']['steps']
        artifact = next(step for step in steps if step.get('uses', '').startswith('actions/upload-artifact'))
        self.assertEqual(artifact['with']['name'], 'kaneopilot-provenance')
        self.assertEqual(artifact['with']['path'], 'release-files/kaneopilot-release.json')
        latest = steps[-1]
        self.assertEqual(latest['if'], "${{ needs.validate.outputs.channel == 'stable' }}")
        self.assertIn('update-latest pilot-tools release-files/latest.json', latest['run'])
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
        self.assertIn('update-latest', legacy[-1]['run'])
        self.assertEqual(release['with']['overwrite_files'], 'false')
        generation = next(step for step in legacy if step.get('name') == 'Generate version manifest')
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
