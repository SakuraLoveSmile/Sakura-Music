"""Offline release identity and independently monotonic update channel checks."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from test_pilot_release import pilot, fixture, FakeGitHub
import test_pilot_release as release_tests


def candidate(version='1.2.3', build=7, prerelease=True, tag=None):
    tag = tag or ('v' + version + ('-pilot.' + str(build) if prerelease else ''))
    page = 'https://github.com/owner/repo/releases/'
    return dict(version=version, build_number=build, prerelease=prerelease, draft=False,
                tag_name=tag, html_url=page + 'tag/' + tag, body='', published_at='2026-10-19T00:00:00Z',
                assets=[dict(name=n, size=10, digest='sha256:' + 'a' * 64,
                             browser_download_url=page + 'download/' + tag + '/' + n) for n in pilot.ASSETS])


class ChannelTests(unittest.TestCase):
    def test_pilot_generates_preview_candidate_with_real_metadata(self):
        m, env = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in pilot.ASSETS:
                (root / name).write_bytes(name.encode())
            pilot.publish(m, env, root, FakeGitHub())
            value = json.loads((root / 'candidate.json').read_bytes())
            self.assertEqual((value['version'], value['build_number'], value['prerelease'], value['draft']),
                             (m['version'], m['build_number'], True, False))

    def test_same_tag_build_or_package_disagreement_blocks(self):
        current = candidate()
        for changed in (candidate(build=8, tag=current['tag_name']), copy.deepcopy(current)):
            if changed['build_number'] == 7:
                changed['assets'][0]['digest'] = 'sha256:' + 'b' * 64
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                pilot.channel_should_advance(current, changed)

    def test_same_numeric_version_orders_builds_and_rejects_downgrade(self):
        self.assertTrue(pilot.channel_should_advance(candidate(build=7), candidate(build=8)))
        self.assertFalse(pilot.channel_should_advance(candidate(build=8), candidate(build=7)))
        self.assertFalse(pilot.channel_should_advance(candidate('2.0.0', 1), candidate('1.9.9', 999)))
        self.assertFalse(pilot.channel_should_advance(candidate(), candidate()))

    def test_same_order_different_tag_cannot_replace_package(self):
        with self.assertRaises(ValueError):
            pilot.channel_should_advance(candidate(), candidate(prerelease=False))

    def test_legacy_same_tag_never_invents_missing_build_number(self):
        old = candidate(prerelease=False)
        for key in ('version', 'build_number', 'prerelease', 'draft'):
            old.pop(key)
        with self.assertRaisesRegex(ValueError, 'identity is missing'):
            pilot.channel_should_advance(old, candidate(prerelease=False))
        self.assertTrue(pilot.channel_should_advance(old, candidate('1.2.4', 8, False)))

    def test_conflicting_second_feed_cannot_partially_write_first_feed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'release').mkdir()
            latest = root / 'release/latest.json'
            latest.write_bytes(pilot.canonical(candidate('1.2.2', 6, False)))
            old = latest.read_bytes()
            preview = candidate(prerelease=False)
            preview['assets'][0]['digest'] = 'sha256:' + 'b' * 64
            (root / 'release/preview.json').write_bytes(pilot.canonical(preview))
            path = root / 'candidate.json'
            path.write_bytes(pilot.canonical(candidate(prerelease=False)))
            commands = []
            def git(cmd, **kwargs):
                commands.append(cmd)
                return subprocess.CompletedProcess(cmd, 0, '', '')
            with self.assertRaises(ValueError):
                pilot.update_channels(root, path, git)
            self.assertEqual(latest.read_bytes(), old)
            self.assertFalse(any('commit' in cmd or 'push' in cmd for cmd in commands))

    def test_legacy_source_metadata_is_exact_pubspec_build(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'pubspec.yaml'
            path.write_text('name: music\nversion: 1.2.3-beta.1+47\n')
            self.assertEqual(pilot.source_version(path, 'v1.2.3-beta.1'),
                             dict(version='1.2.3', build_number=47, prerelease=True, draft=False))
            for text, tag in [('1.2.3+0', 'v1.2.3'), ('1.2.3', 'v1.2.3'),
                              ('1.2.3+2147483648', 'v1.2.3'), ('1.2.3+7', 'v1.2.4')]:
                path.write_text('version: ' + text + '\n')
                with self.subTest(text=text), self.assertRaises(ValueError):
                    pilot.source_version(path, tag)

    def test_both_channels_recompare_after_race_independently(self):
        def git(where, *args):
            return subprocess.run(['git', '-C', str(where), *args], check=True, text=True, capture_output=True)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bare, clone, other = root / 'origin', root / 'clone', root / 'other'
            git(root, 'init', '--bare', str(bare)); git(root, 'clone', str(bare), str(clone))
            git(clone, 'checkout', '-b', 'main')
            git(clone, 'config', 'user.name', 'test'); git(clone, 'config', 'user.email', 'test@example.invalid')
            (clone / 'release').mkdir()
            for feed in ('latest', 'preview'):
                (clone / ('release/' + feed + '.json')).write_bytes(pilot.canonical(candidate('1.0.0', 1, False)))
            git(clone, 'add', '.'); git(clone, 'commit', '-m', 'initial'); git(clone, 'push', 'origin', 'main')
            git(root, 'clone', '-b', 'main', str(bare), str(other))
            path = root / 'candidate.json'; path.write_bytes(pilot.canonical(candidate('1.1.0', 2, False)))
            raced = []
            def race(cmd, **kwargs):
                if 'push' in cmd and not raced:
                    raced.append(True)
                    git(other, 'config', 'user.name', 'test'); git(other, 'config', 'user.email', 'test@example.invalid')
                    (other / 'release/preview.json').write_bytes(pilot.canonical(candidate('1.2.0', 3)))
                    git(other, 'add', '.'); git(other, 'commit', '-m', 'newer preview'); git(other, 'push', 'origin', 'main')
                return subprocess.run(cmd, **kwargs)
            self.assertEqual(pilot.update_channels(clone, path, race), 'updated')
            latest = json.loads(git(bare, 'show', 'main:release/latest.json').stdout)
            preview = json.loads(git(bare, 'show', 'main:release/preview.json').stdout)
            self.assertEqual(latest['version'], '1.1.0'); self.assertEqual(preview['version'], '1.2.0')
            path.write_bytes(pilot.canonical(candidate('1.2.0', 4)))
            self.assertEqual(pilot.update_channels(clone, path), 'updated')
            self.assertEqual(json.loads(git(bare, 'show', 'main:release/latest.json').stdout), latest)
            self.assertEqual(json.loads(git(bare, 'show', 'main:release/preview.json').stdout)['build_number'], 4)


class LegacyTagGuardTests(unittest.TestCase):
    def test_moved_or_deleted_tag_blocks_publish_and_candidate(self):
        for command in ('legacy-preflight', 'legacy-manifest'):
            for ref in (None, dict(object=dict(type='commit', sha='b' * 40))):
                with self.subTest(command=command, ref=ref):
                    fixture_case = release_tests.LegacyManifestTests()
                    self.addCleanup(fixture_case.doCleanups)
                    repository, tag, release, assets, remote = fixture_case.remote()
                    calls = []
                    def request(method, path, **kwargs):
                        calls.append((method, path))
                        if '/git/ref/tags/' in path:
                            return ref
                        return remote(method, path, **kwargs)
                    output = fixture_case.root.parent / 'candidate.json'
                    argv = ['pilot_release.py', command, tag, str(fixture_case.source), str(fixture_case.root)]
                    if command == 'legacy-manifest':
                        argv.append(str(output))
                    argv.append('a' * 40)
                    publish, advance = Mock(), Mock()
                    with patch.object(pilot, 'api', request), patch.object(pilot.sys, 'argv', argv), \
                         patch.dict(pilot.os.environ, GITHUB_REPOSITORY=repository):
                        with self.assertRaisesRegex(ValueError, 'tag'):
                            pilot.main()
                            if command == 'legacy-preflight':
                                publish()
                            advance()
                    publish.assert_not_called()
                    advance.assert_not_called()
                    self.assertFalse(output.exists())
                    self.assertTrue(all(method == 'GET' for method, _ in calls))
                    self.assertTrue(any('/git/ref/tags/' in path for _, path in calls))


    def test_tag_moved_after_preflight_blocks_candidate_and_advancement(self):
        for next_ref in (None, dict(object=dict(type='commit', sha='b' * 40))):
            with self.subTest(next_ref=next_ref):
                fixture_case = release_tests.LegacyManifestTests()
                self.addCleanup(fixture_case.doCleanups)
                repository, tag, release, assets, remote = fixture_case.remote()
                state = dict(ref=dict(object=dict(type='commit', sha='a' * 40)))
                def request(method, path, **kwargs):
                    if '/git/ref/tags/' in path:
                        return state['ref']
                    return remote(method, path, **kwargs)
                output = fixture_case.root.parent / 'candidate.json'
                base = ['pilot_release.py', 'legacy-preflight', tag, str(fixture_case.source), str(fixture_case.root)]
                with patch.object(pilot, 'api', request), patch.dict(pilot.os.environ, GITHUB_REPOSITORY=repository):
                    with patch.object(pilot.sys, 'argv', [*base, 'a' * 40]):
                        pilot.main()
                    state['ref'] = next_ref
                    advance = Mock()
                    manifest_argv = [base[0], 'legacy-manifest', *base[2:], str(output), 'a' * 40]
                    with patch.object(pilot.sys, 'argv', manifest_argv), self.assertRaisesRegex(ValueError, 'tag'):
                        pilot.main()
                        advance()
                    advance.assert_not_called()
                    self.assertFalse(output.exists())

    def test_tag_resolution_accepts_lightweight_and_nested_annotations(self):
        for annotations in (0, 1, 2):
            with self.subTest(annotations=annotations):
                target = 'a' * 40
                objects = [dict(type='tag', sha=str(i) * 40) for i in range(1, annotations + 1)]
                objects.append(dict(type='commit', sha=target))
                calls = []
                def request(method, path, **kwargs):
                    calls.append((method, path))
                    if '/git/ref/tags/' in path:
                        return dict(object=objects[0])
                    sha = path.rsplit('/', 1)[1]
                    index = next(i for i, obj in enumerate(objects) if obj['sha'] == sha)
                    return dict(sha=sha, object=objects[index + 1])
                pilot.require_remote_tag('owner/repo', 'v1.2.3', target, request)
                self.assertEqual(len(calls), annotations + 2)
                self.assertTrue(all(method == 'GET' for method, _ in calls))

    def test_tag_resolution_rejects_cycles_depth_and_mid_resolution_changes(self):
        for mode in ('cycle', 'depth', 'changed', 'missing_annotation'):
            with self.subTest(mode=mode):
                calls = []
                def request(method, path, **kwargs):
                    calls.append((method, path))
                    if '/git/ref/tags/' in path:
                        if mode == 'changed':
                            return dict(object=dict(type='commit', sha=('a' if len(calls) == 1 else 'b') * 40))
                        return dict(object=dict(type='tag', sha='0' * 40))
                    if mode == 'missing_annotation':
                        return None
                    sha = path.rsplit('/', 1)[1]
                    next_sha = sha if mode == 'cycle' else format(int(sha, 16) + 1, '040x')
                    return dict(sha=sha, object=dict(type='tag', sha=next_sha))
                with self.assertRaisesRegex(ValueError, 'tag'):
                    pilot.require_remote_tag('owner/repo', 'v1.2.3', 'a' * 40, request)
                self.assertLessEqual(len(calls), 17)
                self.assertTrue(all(method == 'GET' for method, _ in calls))


if __name__ == '__main__':
    unittest.main()
