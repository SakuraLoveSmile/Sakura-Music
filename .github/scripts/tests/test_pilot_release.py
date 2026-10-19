import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'pilot_release.py'
spec = importlib.util.spec_from_file_location('pilot_release', SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def fixture():
    manifest = dict(schema=1, batch_id='batch-1', repository='owner/repo', project_id='music',
                    root_task_id='root', target_sha='a' * 40,
                    members=[dict(task_id='root', execution_run_id='run-1', plan_sha256='b' * 64,
                                  requirements_sha256='c' * 64, head_sha='d' * 40)],
                    channel='prerelease', version='0.3.1', tag='v0.3.1-pilot.1800000000',
                    build_number=1800000000, required_assets=list(pilot.ASSETS))
    raw = pilot.canonical(manifest)
    return manifest, dict(TARGET_SHA=manifest['target_sha'], RELEASE_BATCH_ID='batch-1',
                         TASK_MANIFEST_JSON=raw.decode(), TASK_MANIFEST_SHA256=hashlib.sha256(raw).hexdigest(),
                         TAG_NAME=manifest['tag'], GITHUB_REPOSITORY='owner/repo',
                         GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1')


class ContractTests(unittest.TestCase):
    def test_valid_manifest(self):
        m, env = fixture()
        self.assertEqual(pilot.validate(env), m)

    def test_tampering_and_unsafe_input(self):
        m, env = fixture()
        for field, value in [('TARGET_SHA', 'main'), ('RELEASE_BATCH_ID', '../bad'),
                             ('TAG_NAME', '$(touch hacked)'), ('GITHUB_REPOSITORY', 'other/repo'),
                             ('TASK_MANIFEST_SHA256', '0' * 64)]:
            with self.subTest(field=field):
                with self.assertRaises(ValueError):
                    pilot.validate(dict(env, **{field: value}))

    def test_bad_manifests(self):
        m, env = fixture()
        cases = [dict(m, build_number=0), dict(m, build_number=True), dict(m, build_number=2147483648),
                 dict(m, channel='prod'), dict(m, version='0.3.1-beta'), dict(m, required_assets=['../oops']),
                 dict(m, required_assets=[]), dict(m, members=m['members'] * 2),
                 dict(m, members=[dict(m['members'][0], plan_sha256='invalid')])]
        for bad in cases:
            raw = pilot.canonical(bad)
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                pilot.validate(dict(env, TASK_MANIFEST_JSON=raw.decode(),
                                    TASK_MANIFEST_SHA256=hashlib.sha256(raw).hexdigest()))

    def test_noncanonical_and_duplicate_keys_rejected(self):
        m, env = fixture()
        for raw in [json.dumps(m).encode(), pilot.canonical(m)[:-1] + b',"schema":1}']:
            with self.assertRaises(ValueError):
                pilot.validate(dict(env, TASK_MANIFEST_JSON=raw.decode(),
                                    TASK_MANIFEST_SHA256=hashlib.sha256(raw).hexdigest()))

    def test_assets_must_be_complete_unique_and_positive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in pilot.ASSETS:
                (root / name).write_bytes(name.encode())
            self.assertEqual(len(pilot.collect_assets(root)), 9)
            (root / pilot.ASSETS[0]).write_bytes(b'')
            with self.assertRaises(ValueError):
                pilot.collect_assets(root)
            (root / pilot.ASSETS[0]).unlink()
            with self.assertRaises(ValueError):
                pilot.collect_assets(root)

class FakeGitHub:
    def __init__(self):
        self.ref = None
        self.annotation = None
        self.release = None
        self.assets = {}
        self.calls = []
        self.releases = []
        self.fail_after = None
        self.counter = 0
        self.next_asset_id = 1

    def __call__(self, method, path, **kwargs):
        from urllib.parse import parse_qs, urlsplit
        self.calls.append((method, path, kwargs))
        result = None
        if method == 'GET':
            if '/git/ref/tags/' in path: result = self.ref
            elif '/git/tags/' in path: result = self.annotation
            elif '/releases/tags/' in path: result = self.release
            elif '/assets?' in path: result = list(self.assets.values())
            elif '/releases/assets/' in path:
                result = next(a['_body'] for a in self.assets.values() if str(a['id']) == path.rsplit('/', 1)[1])
            elif '/releases?' in path: result = self.releases
            else: raise AssertionError(path)
            return copy.deepcopy(result)
        if method == 'POST' and path.endswith('/git/tags'):
            data = kwargs['data']
            self.annotation = dict(sha='e' * 40, tag=data['tag'], message=data['message'],
                                   object=dict(type='commit', sha=data['object'], url='extra field'))
            result = self.annotation
        elif method == 'POST' and path.endswith('/git/refs'):
            self.ref = dict(object=dict(type='tag', sha='e' * 40))
            result = self.ref
        elif method == 'POST' and path.endswith('/releases'):
            self.release = dict(kwargs['data'], id=42, upload_url='https://uploads.github.com/repos/owner/repo/releases/42/assets{?name,label}')
            result = self.release
        elif method == 'POST' and path.startswith('https://uploads.'):
            name = parse_qs(urlsplit(path).query)['name'][0]
            if name in self.assets: raise AssertionError('Duplicate asset upload')
            body = kwargs['body']
            result = dict(id=self.next_asset_id, name=name, size=len(body), digest='sha256:' + hashlib.sha256(body).hexdigest(), _body=body)
            self.next_asset_id += 1
            self.assets[name] = result
        elif method == 'DELETE':
            name = next(n for n, a in self.assets.items() if str(a['id']) == path.rsplit('/', 1)[1])
            del self.assets[name]
        elif method == 'PATCH':
            self.release.update(kwargs['data'])
            result = self.release
        else: raise AssertionError((method, path))
        self.counter += 1
        if self.counter == self.fail_after:
            raise OSError('Lost response after remote write')
        return copy.deepcopy(result)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in pilot.ASSETS: (self.root / name).write_bytes(name.encode())
        self.manifest, self.env = fixture()
        self.remote = FakeGitHub()

    def publish(self, env=None):
        return pilot.publish(self.manifest, env or self.env, self.root, self.remote)

    def test_draft_then_publish_and_exact_provenance(self):
        result = self.publish()
        self.assertFalse(self.remote.release['draft'])
        self.assertEqual(self.remote.release['make_latest'], 'false')
        self.assertEqual(self.remote.assets['kaneopilot-release.json']['_body'], (self.root / 'kaneopilot-release.json').read_bytes())
        self.assertEqual(result['assets'], json.loads(self.remote.assets['kaneopilot-release.json']['_body'])['assets'])
        self.assertFalse((self.root / 'latest.json').exists())

    def test_all_remote_write_failure_boundaries_recover(self):
        # Annotated tag, ref, draft, each of 10 assets, and publish response.
        for boundary in range(1, 15):
            with self.subTest(boundary=boundary):
                self.remote = FakeGitHub()
                self.remote.fail_after = boundary
                with self.assertRaises(OSError): self.publish()
                installed = {n: a['_body'] for n, a in self.remote.assets.items() if n in pilot.ASSETS}
                start = len(self.remote.calls)
                self.remote.fail_after = None
                self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
                self.assertFalse(self.remote.release['draft'])
                self.assertEqual(json.loads(self.remote.assets['kaneopilot-release.json']['_body'])['run_attempt'], 2)
                for name, content in installed.items():
                    self.assertEqual(self.remote.assets[name]['_body'], content)
                    self.assertFalse(any(method == 'POST' and 'name=' + name in path for method, path, _ in self.remote.calls[start:]))

    def test_published_same_owner_updates_only_provenance(self):
        self.publish()
        self.remote.calls.clear()
        self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
        uploads = [path for method, path, _ in self.remote.calls if method == 'POST']
        self.assertEqual(len(uploads), 1)
        self.assertIn('name=kaneopilot-release.json', uploads[0])
        self.assertEqual(json.loads(self.remote.assets['kaneopilot-release.json']['_body'])['run_attempt'], 2)

    def test_provenance_delete_upload_and_publish_response_losses_recover(self):
        for boundary in (1, 2, 3):
            with self.subTest(boundary=boundary):
                self.remote = FakeGitHub()
                self.publish()
                self.remote.fail_after = self.remote.counter + boundary
                with self.assertRaises(OSError): self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
                self.remote.fail_after = None
                self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='3'))
                self.assertEqual(json.loads(self.remote.assets['kaneopilot-release.json']['_body'])['run_attempt'], 3)
                self.assertFalse(self.remote.release['draft'])

    def test_final_state_is_rechecked(self):
        original = self.remote.__call__
        def changed(method, path, **kwargs):
            result = original(method, path, **kwargs)
            if method == 'PATCH': self.remote.release['draft'] = True
            return result
        with self.assertRaises(ValueError): pilot.publish(self.manifest, self.env, self.root, changed)

    def test_foreign_owner_and_changed_installer_are_read_only(self):
        self.publish()
        for env in (dict(self.env, GITHUB_RUN_ID='999'),):
            self.remote.calls.clear()
            with self.assertRaises(ValueError): self.publish(env)
            self.assertTrue(all(method == 'GET' for method, _, _ in self.remote.calls))
        (self.root / pilot.ASSETS[0]).write_bytes(b'different build')
        self.remote.calls.clear()
        with self.assertRaises(ValueError): self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
        self.assertTrue(all(method == 'GET' for method, _, _ in self.remote.calls))

    def test_foreign_provenance_or_newer_attempt_is_read_only(self):
        self.publish()
        old = self.remote.assets['kaneopilot-release.json']
        for change in (dict(workflow_run_id=999), dict(run_attempt=3)):
            raw = json.loads(old['_body']); raw.update(change); raw = pilot.canonical(raw)
            self.remote.assets['kaneopilot-release.json'] = dict(old, _body=raw, size=len(raw), digest='sha256:' + hashlib.sha256(raw).hexdigest())
            self.remote.calls.clear()
            with self.assertRaises(ValueError): self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
            self.assertTrue(all(method == 'GET' for method, _, _ in self.remote.calls))

    def test_foreign_tag_rejected(self):
        self.remote.ref = dict(object=dict(type='commit', sha='a' * 40))
        with self.assertRaises(ValueError): self.publish()
        self.assertTrue(all(method == 'GET' for method, _, _ in self.remote.calls))

    def test_stable_legacy_mode_and_newer_stable_guard(self):
        self.manifest.update(channel='stable', tag='v0.3.1')
        self.remote.releases = [dict(tag_name='v0.3.2', draft=False, prerelease=False)]
        self.publish()
        self.assertEqual(self.remote.release['make_latest'], 'false')
        self.assertEqual(json.loads((self.root / 'latest.json').read_bytes())['tag_name'], 'v0.3.1')
        self.remote.releases = []
        self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
        self.assertEqual(self.remote.release['make_latest'], 'legacy')
        self.assertFalse(any(kwargs.get('data', {}).get('make_latest') == 'true' for _, _, kwargs in self.remote.calls))

    def test_owned_draft_starter_installer_is_replaced(self):
        self.remote.fail_after = 3  # The draft exists; no asset upload yet.
        with self.assertRaises(OSError): self.publish()
        self.remote.fail_after = None
        name = pilot.ASSETS[0]
        self.remote.assets[name] = dict(id=9001, name=name, state='starter', size=0, _body=b'')
        self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
        self.assertIn(('DELETE', '/repos/owner/repo/releases/assets/9001', {}), self.remote.calls)
        self.assertGreater(self.remote.assets[name]['size'], 0)
        self.assertFalse(self.remote.release['draft'])

    def test_owned_provenance_starter_recovers_draft_and_published(self):
        for draft in (True, False):
            with self.subTest(draft=draft):
                self.remote = FakeGitHub()
                self.publish()
                self.remote.release['draft'] = draft
                name = 'kaneopilot-release.json'
                self.remote.assets[name] = dict(id=9002, name=name, state='starter', size=0, _body=b'')
                self.remote.calls.clear()
                self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
                self.assertIn(('DELETE', '/repos/owner/repo/releases/assets/9002', {}), self.remote.calls)
                self.assertEqual(json.loads(self.remote.assets[name]['_body'])['run_attempt'], 2)

    def test_unknown_nonempty_and_uploaded_assets_are_never_deleted(self):
        for name, state, size, draft in [(pilot.ASSETS[0], 'uploaded', 0, True),
                                         (pilot.ASSETS[0], 'unknown', 0, True),
                                         (pilot.ASSETS[0], 'starter', 5, True),
                                         (pilot.ASSETS[0], 'starter', 0, False),
                                         ('unexpected.apk', 'starter', 0, True),
                                         ('kaneopilot-release.json', 'uploaded', 0, True),
                                         ('kaneopilot-release.json', 'starter', 5, True)]:
            with self.subTest(name=name, state=state, size=size, draft=draft):
                self.remote = FakeGitHub()
                self.publish()
                self.remote.release['draft'] = draft
                self.remote.assets[name] = dict(id=9003, name=name, state=state, size=size, _body=b'bad')
                self.remote.calls.clear()
                with self.assertRaises(ValueError): self.publish(dict(self.env, GITHUB_RUN_ATTEMPT='2'))
                self.assertTrue(all(method == 'GET' for method, _, _ in self.remote.calls))

    def test_asset_digest_failure_never_finalizes(self):
        original = self.remote.__call__
        def corrupt(method, path, **kwargs):
            result = original(method, path, **kwargs)
            if method == 'POST' and path.startswith('https://uploads.'):
                result['digest'] = 'sha256:' + '0' * 64
            return result
        with self.assertRaises(ValueError): pilot.publish(self.manifest, self.env, self.root, corrupt)
        self.assertTrue(self.remote.release['draft'])


class LegacyManifestTests(unittest.TestCase):
    def remote(self):
        repository, tag = 'owner/repo', 'v1.2.3'
        release = dict(id=42, tag_name=tag, draft=False, prerelease=False, body='notes',
                       html_url='https://github.com/' + repository + '/releases/tag/' + tag,
                       published_at='2026-10-19T00:00:00Z')
        assets = [dict(id=i + 1, name=name, size=10, digest='sha256:' + 'a' * 64,
                       browser_download_url='https://github.com/' + repository + '/releases/download/' + tag + '/' + name)
                  for i, name in enumerate(pilot.ASSETS)]
        def request(method, path, **kwargs):
            self.assertEqual(method, 'GET')
            return copy.deepcopy(assets if '/assets?' in path else release)
        return repository, tag, release, assets, request

    def test_same_tag_rerun_uses_retained_remote_assets(self):
        repository, tag, release, assets, request = self.remote()
        manifest = pilot.legacy_manifest(repository, tag, request)
        self.assertEqual(manifest['assets'], [{k: asset[k] for k in ('name', 'size', 'digest', 'browser_download_url')}
                                             for asset in sorted(assets, key=lambda a: a['name'])])
        self.assertTrue(all(asset['digest'] == 'sha256:' + 'a' * 64 for asset in manifest['assets']))
        # Local rebuilt bytes are deliberately unrelated; none enter the manifest.
        self.assertNotEqual(manifest['assets'][0]['digest'], 'sha256:' + hashlib.sha256(b'new build').hexdigest())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / 'release').mkdir()
            current = root / 'release/latest.json'; current.write_bytes(pilot.canonical(manifest))
            candidate = root / 'candidate.json'; candidate.write_bytes(pilot.canonical(manifest))
            commands = []
            def git(cmd, **kwargs):
                import subprocess
                commands.append(cmd)
                return subprocess.CompletedProcess(cmd, 0, '', '')
            self.assertEqual(pilot.update_latest(root, candidate, git), 'unchanged')
            self.assertFalse(any('commit' in cmd or 'push' in cmd for cmd in commands))
            stale = copy.deepcopy(manifest); stale['assets'][0]['digest'] = 'sha256:' + 'b' * 64
            current.write_bytes(pilot.canonical(stale))
            commands.clear()
            with self.assertRaises(ValueError): pilot.update_latest(root, candidate, git)
            self.assertEqual(json.loads(current.read_bytes()), stale)
            self.assertFalse(any('commit' in cmd or 'push' in cmd for cmd in commands))

    def test_missing_digest_wrong_url_duplicate_and_nonpositive_remote_assets_fail(self):
        for mutate in ('missing_digest', 'wrong_url', 'duplicate', 'empty'):
            with self.subTest(mutate=mutate):
                repository, tag, release, assets, request = self.remote()
                if mutate == 'missing_digest': assets[0].pop('digest')
                elif mutate == 'wrong_url': assets[0]['browser_download_url'] = 'https://example.invalid/package'
                elif mutate == 'duplicate': assets.append(copy.deepcopy(assets[0]))
                else: assets[0]['size'] = 0
                with self.assertRaises(ValueError): pilot.legacy_manifest(repository, tag, request)


class StableGitTests(unittest.TestCase):
    def test_reverse_order_and_racing_push_do_not_regress(self):
        import subprocess
        def git(where, *args):
            return subprocess.run(['git', '-C', str(where), *args], check=True, text=True, capture_output=True)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bare, clone, other = root / 'origin', root / 'clone', root / 'other'
            git(root, 'init', '--bare', str(bare))
            git(root, 'clone', str(bare), str(clone))
            git(clone, 'checkout', '-b', 'main')
            git(clone, 'config', 'user.name', 'test'); git(clone, 'config', 'user.email', 'test@example.invalid')
            (clone / 'release').mkdir(); (clone / 'release/latest.json').write_bytes(pilot.canonical(dict(tag_name='v0.3.0')))
            git(clone, 'add', '.'); git(clone, 'commit', '-m', 'initial'); git(clone, 'push', 'origin', 'main')
            git(root, 'clone', '-b', 'main', str(bare), str(other))
            candidate = root / 'candidate.json'; candidate.write_bytes(pilot.canonical(dict(tag_name='v0.3.1')))
            raced = []
            def race(cmd, **kwargs):
                if 'push' in cmd and not raced:
                    raced.append(True)
                    git(other, 'config', 'user.name', 'other'); git(other, 'config', 'user.email', 'other@example.invalid')
                    (other / 'release/latest.json').write_bytes(pilot.canonical(dict(tag_name='v0.3.2')))
                    git(other, 'add', '.'); git(other, 'commit', '-m', 'newer stable'); git(other, 'push', 'origin', 'main')
                return subprocess.run(cmd, **kwargs)
            self.assertEqual(pilot.update_latest(clone, candidate, run=race), 'unchanged')
            self.assertEqual(json.loads(git(bare, 'show', 'main:release/latest.json').stdout)['tag_name'], 'v0.3.2')
            self.assertEqual(pilot.update_latest(clone, candidate), 'unchanged')
            candidate.write_bytes(pilot.canonical(dict(tag_name='v0.3.3')))
            self.assertEqual(pilot.update_latest(clone, candidate), 'updated')
            self.assertEqual(json.loads(git(bare, 'show', 'main:release/latest.json').stdout)['tag_name'], 'v0.3.3')


if __name__ == '__main__': unittest.main()
