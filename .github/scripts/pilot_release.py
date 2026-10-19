#!/usr/bin/env python3
"""Strict Pilot workflow adapter. No dependency on the target source checkout.

Read workflow_dispatch fields from the event JSON; never interpolate them into
shell source. Recovery requires this exact batch/run/target owner; installers are never replaced.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ASSETS = (
    'SakuraMusic-android-arm64-v8a.apk', 'SakuraMusic-android-armeabi-v7a.apk',
    'SakuraMusic-android-x86_64.apk', 'SakuraMusic-android-universal.apk',
    'SakuraMusic-windows-x64.zip', 'SakuraMusic-macos.zip', 'SakuraMusic-macos.dmg',
    'SakuraMusic-ios-unsigned.ipa', 'SakuraMusic-ios-Runner.app.zip',
)
INPUTS = ('target_sha', 'release_batch_id', 'task_manifest_json', 'task_manifest_sha256', 'tag_name')
SHA = re.compile(r'[0-9a-f]{40}')
HASH = re.compile(r'[0-9a-f]{64}')
IDENTITY = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,199}')
VERSION = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def matches(pattern, value):
    return isinstance(value, str) and pattern.fullmatch(value) is not None


def validate(env):
    fields = {key: env.get(key.upper(), '') for key in INPUTS}
    require(all(isinstance(x, str) for x in fields.values()), 'All inputs must be strings')
    require(len(canonical(fields)) <= 60 * 1024, 'Inputs exceed 60 KiB')
    raw = fields['task_manifest_json'].encode('utf-8')
    require(hashlib.sha256(raw).hexdigest() == fields['task_manifest_sha256'], 'Task manifest hash mismatch')
    manifest = json.loads(raw)
    require(isinstance(manifest, dict) and canonical(manifest) == raw, 'Manifest must be canonical JSON')
    require(type(manifest.get('schema')) is int and manifest['schema'] == 1, 'Unsupported schema')
    require(matches(SHA, fields['target_sha']), 'target_sha must be a full lowercase commit SHA')
    require(matches(IDENTITY, fields['release_batch_id']), 'Invalid batch id')
    require(manifest.get('batch_id') == fields['release_batch_id'], 'Batch mismatch')
    require(manifest.get('target_sha') == fields['target_sha'], 'Target SHA mismatch')
    require(manifest.get('repository') == env['GITHUB_REPOSITORY'], 'Repository mismatch')
    for key in ('project_id', 'root_task_id'):
        require(matches(IDENTITY, manifest.get(key)), 'Invalid ' + key)
    require(manifest.get('channel') in ('prerelease', 'stable'), 'Invalid release channel')
    require(matches(VERSION, manifest.get('version')), 'Version must be three numeric components')
    number = manifest.get('build_number')
    require(type(number) is int and 0 < number <= 2147483647, 'Invalid build number')
    expected = 'v' + manifest['version']
    if manifest['channel'] == 'prerelease':
        expected += '-pilot.' + str(number)
    require(manifest.get('tag') == fields['tag_name'] == expected, 'Tag mismatch')
    required = manifest.get('required_assets')
    require(isinstance(required, list) and required and all(isinstance(x, str) for x in required), 'Missing assets')
    require(len(set(required)) == len(required) and set(required) <= set(ASSETS), 'Unsupported/duplicate assets')
    members = manifest.get('members')
    require(isinstance(members, list) and members, 'Members required')
    seen = set()
    for member in members:
        require(isinstance(member, dict), 'Invalid member')
        for key in ('task_id', 'execution_run_id'):
            require(matches(IDENTITY, member.get(key)), 'Invalid member ' + key)
        require(member['task_id'] not in seen, 'Duplicate member task')
        seen.add(member['task_id'])
        for key in ('plan_sha256', 'requirements_sha256'):
            require(matches(HASH, member.get(key)), 'Invalid member ' + key)
        require(matches(SHA, member.get('head_sha')), 'Invalid member head_sha')
    for key in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'):
        require(re.fullmatch(r'[1-9][0-9]*', env.get(key, '')) is not None, 'Invalid ' + key)
    return manifest


def collect_assets(root):
    files = {}
    for path in sorted(root.rglob('*')):
        require(not path.is_symlink(), 'Symlink artifact forbidden')
        if not path.is_file():
            continue
        if path.parent == root and path.name in ('kaneopilot-release.json', 'latest.json'):
            continue
        require(path.name in ASSETS, 'Unexpected build artifact: ' + path.name)
        require(path.name not in files, 'Duplicate build artifact: ' + path.name)
        require(path.stat().st_size > 0, 'Empty build artifact: ' + path.name)
        files[path.name] = path
    require(set(files) == set(ASSETS), 'The nine platform assets are all required')
    return files


def api(method, path, data=None, body=None, content_type='application/json'):
    repository = os.environ['GITHUB_REPOSITORY']
    base = 'https://api.github.com'
    if path.startswith('https://'):
        require(path.startswith('https://uploads.github.com/repos/' + repository + '/releases/'), 'Unexpected upload host/path')
        url = path
    else:
        require(path.startswith('/repos/' + repository + '/'), 'Unexpected API path')
        url = base + path
    if data is not None:
        body = canonical(data)
    headers = {'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
               'Accept': 'application/octet-stream' if method == 'GET' and content_type == 'application/octet-stream' else 'application/vnd.github+json', 'X-GitHub-Api-Version': '2026-03-10',
               'Content-Type': content_type}
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    # Redirects could leak the token or turn writes into another request.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, hdrs, newurl):
            return None
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=120) as response:
            raw = response.read(1024 * 1024 + 1)
            require(len(raw) <= 1024 * 1024, 'GitHub response exceeds the bounded metadata limit')
            if method == 'GET' and content_type == 'application/octet-stream':
                return raw
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        if method == 'GET' and content_type == 'application/octet-stream' and error.code in (301, 302, 307, 308):
            location = error.headers.get('Location', '')
            parsed = urllib.parse.urlsplit(location)
            require(parsed.scheme == 'https' and parsed.hostname in ('release-assets.githubusercontent.com', 'objects.githubusercontent.com'),
                    'Unexpected provenance download host')
            # No Authorization header crosses the API-to-storage redirect.
            with urllib.request.build_opener(NoRedirect).open(location, timeout=120) as response:
                raw = response.read(1024 * 1024 + 1)
                require(len(raw) <= 1024 * 1024, 'Provenance exceeds 1 MiB')
                return raw
        if method == 'GET' and error.code == 404:

            return None
        raise ValueError('GitHub API %s %s failed (HTTP %s); reconcile partial release before retry' %
                         (method, path.split('?')[0], error.code)) from None


def owner_marker(manifest, env):
    owner = dict(schema=1, batch_id=manifest['batch_id'], repository=manifest['repository'],
                 target_sha=manifest['target_sha'], workflow_run_id=int(env['GITHUB_RUN_ID']),
                 task_manifest_sha256=hashlib.sha256(canonical(manifest)).hexdigest())
    return 'kaneopilot-owner:' + canonical(owner).decode('utf-8')


def prepare(manifest, env, root):
    files = collect_assets(root)
    assets = [dict(name=name, size=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
              for name, path in sorted(files.items())]
    provenance = dict(schema=1, batch_id=manifest['batch_id'], repository=manifest['repository'],
                      target_sha=manifest['target_sha'], task_manifest=manifest,
                      task_manifest_sha256=hashlib.sha256(canonical(manifest)).hexdigest(),
                      workflow_run_id=int(env['GITHUB_RUN_ID']), run_attempt=int(env['GITHUB_RUN_ATTEMPT']),
                      channel=manifest['channel'], version=manifest['version'], tag=manifest['tag'],
                      build_number=manifest['build_number'], assets=assets)
    (root / 'kaneopilot-release.json').write_bytes(canonical(provenance))
    return provenance


def stable_version(tag):
    require(isinstance(tag, str) and tag.startswith('v') and matches(VERSION, tag[1:]),
            'Stable manifest must use an exact vX.Y.Z tag')
    return tuple(int(x) for x in tag[1:].split('.'))


def stable_latest_mode(prefix, version, request):
    # GitHub documents `legacy` as choosing by creation date and higher
    # semantic version. Never force true. The full-list guard also keeps an
    # already published higher stable version out of this older update.
    for page in range(1, 1001):
        releases = request('GET', prefix + '/releases?per_page=100&page=' + str(page))
        require(isinstance(releases, list), 'Cannot prove the complete stable release list')
        for release in releases:
            tag = release.get('tag_name', '')
            if not release.get('draft') and not release.get('prerelease') and isinstance(tag, str) and matches(VERSION, tag[1:] if tag.startswith('v') else ''):
                if stable_version(tag) > version:
                    return 'false'
        if len(releases) < 100:
            return 'legacy'
    raise ValueError('Stable release list is incomplete')


def empty_upload_starter(asset):
    # GitHub documents failed-upload placeholders as starter + zero bytes.
    # A zero-sized uploaded/unknown-state asset is not this recoverable case.
    return (isinstance(asset, dict) and asset.get('state') == 'starter' and
            type(asset.get('size')) is int and asset['size'] == 0)


def publish(manifest, env, root, request=api):
    provenance = prepare(manifest, env, root)
    files = collect_assets(root)
    content = canonical(provenance)
    repository = manifest['repository']
    prefix = '/repos/' + repository
    tag = urllib.parse.quote(manifest['tag'], safe='')
    marker = owner_marker(manifest, env)
    ref = request('GET', prefix + '/git/ref/tags/' + tag)
    release = request('GET', prefix + '/releases/tags/' + tag)
    if ref is not None:
        obj = ref.get('object', {})
        require(obj.get('type') == 'tag' and matches(SHA, obj.get('sha')), 'Foreign tag; refusing recovery')
        annotation = request('GET', prefix + '/git/tags/' + obj['sha'])
        require(isinstance(annotation, dict) and annotation.get('message') == marker and
                annotation.get('object', {}).get('type') == 'commit' and
                annotation.get('object', {}).get('sha') == manifest['target_sha'] and
                annotation.get('tag') == manifest['tag'], 'Tag owner or target mismatch')
    else:
        require(release is None, 'Release exists without owned tag')
        annotation = request('POST', prefix + '/git/tags', data=dict(tag=manifest['tag'], message=marker,
                             object=manifest['target_sha'], type='commit'))
        require(matches(SHA, annotation.get('sha')), 'Invalid annotated tag response')
        request('POST', prefix + '/git/refs', data=dict(ref='refs/tags/' + manifest['tag'], sha=annotation['sha']))
    prerelease = manifest['channel'] == 'prerelease'
    if release is None:
        release = request('POST', prefix + '/releases', data=dict(tag_name=manifest['tag'],
                          target_commitish=manifest['target_sha'], name=manifest['tag'], draft=True,
                          prerelease=prerelease, make_latest='false',
                          body=marker + '\n\niOS assets are unsigned; signing is required before device installation.'))
    else:
        require(release.get('body', '').split('\n', 1)[0] == marker and
                release.get('tag_name') == manifest['tag'] and release.get('prerelease') is prerelease,
                'Release owner/channel mismatch; refusing recovery')
    release_id = release['id']
    upload = release['upload_url'].split('{')[0]
    expected_upload = 'https://uploads.github.com/repos/' + repository + '/releases/' + str(release_id) + '/assets'
    require(upload == expected_upload, 'Unexpected release upload endpoint')
    existing = {}
    for page in range(1, 1001):
        values = request('GET', prefix + '/releases/' + str(release_id) + '/assets?per_page=100&page=' + str(page))
        require(isinstance(values, list), 'Cannot inspect existing release assets')
        for asset in values:
            name = asset.get('name')
            require(name in ASSETS or name == 'kaneopilot-release.json', 'Unexpected existing asset')
            require(name not in existing, 'Ambiguous duplicate release asset')
            existing[name] = asset
        if len(values) < 100:
            break
    else:
        raise ValueError('Release asset list is incomplete')
    # Inspect every installer before any recovery mutation. Rebuilding a
    # different binary is never permission to replace an already uploaded one.
    for asset in provenance['assets']:
        old = existing.get(asset['name'])
        if empty_upload_starter(old):
            require(release.get('draft') is True, 'Published installer placeholder cannot be replaced')
        elif old is not None:
            require(old.get('size') == asset['size'] and old.get('digest') == 'sha256:' + asset['sha256'],
                    'Existing installer differs; refusing replacement')
        else:
            require(release.get('draft') is True, 'Published release is missing an installer')
    prior = existing.get('kaneopilot-release.json')
    if prior is not None and not empty_upload_starter(prior):
        raw = request('GET', prefix + '/releases/assets/' + str(prior['id']), content_type='application/octet-stream')
        require(isinstance(raw, bytes) and len(raw) == prior.get('size') and
                'sha256:' + hashlib.sha256(raw).hexdigest() == prior.get('digest'), 'Prior provenance digest mismatch')
        previous = json.loads(raw)
        expected = dict(provenance)
        previous_attempt = previous.get('run_attempt')
        require(type(previous_attempt) is int and 1 <= previous_attempt <= provenance['run_attempt'], 'Invalid previous attempt')
        expected['run_attempt'] = previous_attempt
        require(previous == expected and canonical(previous) == raw, 'Previous provenance identity or installers mismatch')
    for name, body in [(name, path.read_bytes()) for name, path in sorted(files.items())] + [('kaneopilot-release.json', content)]:
        old = existing.get(name)
        digest = 'sha256:' + hashlib.sha256(body).hexdigest()
        if old is not None and old.get('size') == len(body) and old.get('digest') == digest:
            continue
        if old is not None:
            require(name == 'kaneopilot-release.json' or
                    (release.get('draft') is True and empty_upload_starter(old)),
                    'Installer replacement forbidden')
            # Owner is already established by both immutable tag and release.
            # Only provenance may advance to this same run's current attempt.
            # Official starter/0 failed-upload placeholders contain no package;
            # only an owned draft may clear those for installer uploads.
            request('DELETE', prefix + '/releases/assets/' + str(old['id']))
        result = request('POST', upload + '?name=' + urllib.parse.quote(name, safe=''),
                         body=body, content_type='application/octet-stream')
        require(result.get('size') == len(body) and result.get('digest') == digest,
                'Uploaded asset digest/size mismatch; reconcile this owned release')
    mode = 'false' if prerelease else stable_latest_mode(prefix, stable_version(manifest['tag']), request)
    request('PATCH', prefix + '/releases/' + str(release_id),
            data=dict(draft=False, prerelease=prerelease, make_latest=mode))
    final = request('GET', prefix + '/releases/tags/' + tag)
    require(isinstance(final, dict) and final.get('id') == release_id and final.get('draft') is False and
            final.get('prerelease') is prerelease and final.get('body', '').split('\n', 1)[0] == marker,
            'Published release state changed during reconciliation')
    final_assets = request('GET', prefix + '/releases/' + str(release_id) + '/assets?per_page=100&page=1')
    require(isinstance(final_assets, list) and len(final_assets) == len(ASSETS) + 1 and
            len({a.get('name') for a in final_assets}) == len(final_assets), 'Final release assets are incomplete or ambiguous')
    expected_assets = {a['name']: (a['size'], 'sha256:' + a['sha256']) for a in provenance['assets']}
    expected_assets['kaneopilot-release.json'] = (len(content), 'sha256:' + hashlib.sha256(content).hexdigest())
    for asset in final_assets:
        require(expected_assets.get(asset.get('name')) == (asset.get('size'), asset.get('digest')),
                'Final release asset digest mismatch')
    final_manifest = next(a for a in final_assets if a['name'] == 'kaneopilot-release.json')
    require(request('GET', prefix + '/releases/assets/' + str(final_manifest['id']), content_type='application/octet-stream') == content,
            'Final provenance differs from this attempt artifact')
    final_ref = request('GET', prefix + '/git/ref/tags/' + tag)
    require(final_ref == ref if ref is not None else final_ref.get('object', {}).get('sha') == annotation['sha'],
            'Tag changed during publication')
    if not prerelease:
        latest = dict(tag_name=manifest['tag'], html_url='https://github.com/' + repository + '/releases/tag/' + manifest['tag'],
                      body='', published_at=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                      assets=[dict(name=a['name'], size=a['size'], digest='sha256:' + a['sha256'],
                      browser_download_url='https://github.com/' + repository + '/releases/download/' + manifest['tag'] + '/' + a['name']) for a in provenance['assets']])
        (root / 'latest.json').write_bytes(canonical(latest))
    return provenance


def legacy_manifest(repository, tag, request=api):
    """Describe retained GitHub packages, never this rerun's rebuilt files."""
    stable_version(tag)
    prefix = '/repos/' + repository
    release = request('GET', prefix + '/releases/tags/' + urllib.parse.quote(tag, safe=''))
    require(isinstance(release, dict) and release.get('tag_name') == tag and
            release.get('draft') is False and release.get('prerelease') is False,
            'Stable release is not published')
    page_url = 'https://github.com/' + repository + '/releases/tag/' + tag
    require(release.get('html_url') == page_url, 'Unexpected stable Release URL')
    assets = {}
    for page in range(1, 1001):
        values = request('GET', prefix + '/releases/' + str(release['id']) + '/assets?per_page=100&page=' + str(page))
        require(isinstance(values, list), 'Cannot read stable release assets')
        for asset in values:
            name = asset.get('name')
            if name not in ASSETS:
                continue
            require(name not in assets, 'Ambiguous stable release asset')
            require(type(asset.get('size')) is int and asset['size'] > 0 and
                    isinstance(asset.get('digest'), str) and matches(HASH, asset['digest'].removeprefix('sha256:')) and
                    asset['digest'].startswith('sha256:'), 'Stable release asset lacks size or SHA-256')
            expected_url = 'https://github.com/' + repository + '/releases/download/' + tag + '/' + urllib.parse.quote(name, safe='')
            require(asset.get('browser_download_url') == expected_url, 'Unexpected stable asset download URL')
            assets[name] = {key: asset[key] for key in ('name', 'size', 'digest', 'browser_download_url')}
        if len(values) < 100:
            break
    else:
        raise ValueError('Stable asset list is incomplete')
    require(set(assets) == set(ASSETS), 'Stable release is missing a platform package')
    return dict(tag_name=tag, html_url=page_url, body=release.get('body') or '',
                published_at=release.get('published_at'), assets=[assets[name] for name in sorted(assets)])


def stable_manifest_identity(manifest):
    """Compare immutable package identities while ignoring release note dates."""
    assets = manifest.get('assets')
    require(isinstance(assets, list), 'Existing stable manifest lacks asset identities')
    values = {}
    for asset in assets:
        require(isinstance(asset, dict), 'Invalid stable manifest asset')
        name = asset.get('name')
        require(name in ASSETS and name not in values, 'Ambiguous stable manifest asset')
        require(all(key in asset for key in ('size', 'digest', 'browser_download_url')), 'Incomplete stable manifest asset')
        values[name] = {key: asset[key] for key in ('name', 'size', 'digest', 'browser_download_url')}
    require(set(values) == set(ASSETS), 'Existing stable manifest is missing package identities')
    return manifest.get('html_url'), [values[name] for name in sorted(values)]


def update_latest(repository, candidate_path, run=None):
    """Optimistic git CAS: a rejected push re-fetches and re-compares versions."""
    import subprocess
    if run is None:
        run = subprocess.run
    candidate = json.loads(Path(candidate_path).read_bytes())
    version = stable_version(candidate.get('tag_name'))
    repository = Path(repository).resolve()
    def git(*args, check=True):
        result = run(['git', '-C', str(repository), *args], text=True, capture_output=True)
        require(not check or result.returncode == 0, 'Stable manifest git operation failed: ' + args[0])
        return result
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', 'github-actions[bot]@users.noreply.github.com')
    for _ in range(3):
        git('fetch', 'origin', 'main')
        git('checkout', '-B', 'pilot-stable-manifest', 'FETCH_HEAD')
        path = repository / 'release/latest.json'
        if path.exists():
            current = json.loads(path.read_bytes())
            current_version = stable_version(current.get('tag_name'))
            if current_version > version:
                return 'unchanged'
            if current_version == version:
                require(stable_manifest_identity(current) == stable_manifest_identity(candidate),
                        'Same-tag stable manifest differs from retained GitHub packages; reconciliation required')
                return 'unchanged'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(canonical(candidate))
        git('add', 'release/latest.json')
        git('commit', '-m', '[skip ci] chore: update latest.json manifest for ' + candidate['tag_name'])
        if git('push', 'origin', 'HEAD:main', check=False).returncode == 0:
            return 'updated'
    raise ValueError('Stable manifest push conflicted repeatedly; rerun to reconcile')

def event_env():
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
    require(os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'Only workflow_dispatch is supported')
    inputs = event.get('inputs', {})
    require(set(inputs) == set(INPUTS), 'Exactly five dispatch inputs required')
    env = dict(os.environ)
    env.update({key.upper(): inputs[key] for key in INPUTS})
    return env


def main():
    if sys.argv[1] == 'legacy-manifest':
        path = Path(sys.argv[3])
        result = legacy_manifest(os.environ['GITHUB_REPOSITORY'], sys.argv[2])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(canonical(result))
        return
    if sys.argv[1] == 'update-latest':
        update_latest(sys.argv[2], sys.argv[3])
        return
    env = event_env()
    manifest = validate(env)
    if sys.argv[1] == 'validate':
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
            for key in ('target_sha', 'version', 'build_number', 'channel', 'tag'):
                output.write('%s=%s\n' % (key, manifest[key]))
    elif sys.argv[1] == 'prepare':
        prepare(manifest, env, Path(sys.argv[2]))
    elif sys.argv[1] == 'publish':
        publish(manifest, env, Path(sys.argv[2]))
    else:
        raise ValueError('Unknown command')

if __name__ == '__main__':
    main()
