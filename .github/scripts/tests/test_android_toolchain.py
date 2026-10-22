"""Run the real Android toolchain setup shell against isolated downloads."""
from pathlib import Path
import hashlib
import io
import os
import subprocess
import tempfile
import unittest
import zipfile

import yaml


WORKFLOW = Path(__file__).resolve().parents[2] / 'workflows' / 'release-build.yml'


class AndroidToolchainTests(unittest.TestCase):
    def setup_step(self):
        workflow = yaml.load(WORKFLOW.read_text(), Loader=yaml.BaseLoader)
        steps = workflow['jobs']['build-android']['steps']
        matches = [step for step in steps if step.get('name') == 'Install verified CMake 3.22.1']
        self.assertEqual(len(matches), 1, 'Provision CMake before Gradle can auto-download it')
        return steps, matches[0]

    @staticmethod
    def archive():
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            for name, version in [('cmake', 'cmake version 3.22.1-g37088a8'), ('ninja', '1.10.2')]:
                info = zipfile.ZipInfo('bin/' + name)
                info.create_system = 3
                info.external_attr = 0o100755 << 16
                archive.writestr(info, '#!/bin/sh\nprintf "%s\\n" "' + version + '"\n')
        return data.getvalue()

    def run_setup(self, content, expected_digest):
        _, step = self.setup_step()
        with tempfile.TemporaryDirectory(prefix='android toolchain ') as directory:
            root = Path(directory)
            (root / 'android').mkdir()
            properties = root / 'android' / 'local.properties'
            # Flutter writes this file without a trailing newline.
            original = 'sdk.dir=/fixture/android-sdk\nflutter.sdk=/fixture/flutter'
            properties.write_text(original)
            (root / 'downloads').mkdir()
            source = root / 'downloads' / 'response'
            source.write_bytes(content)
            tools = root / 'tools'
            tools.mkdir()
            curl = tools / 'curl'
            curl.write_text(
                '#!/usr/bin/env python3\n'
                'import os, pathlib, sys\n'
                'args = sys.argv[1:]\n'
                'pathlib.Path(args[args.index("--output") + 1]).write_bytes('
                'pathlib.Path(os.environ["FIXTURE_DOWNLOAD"]).read_bytes())\n')
            curl.chmod(0o755)
            runner_temp = root / 'runner temp'
            runner_temp.mkdir()
            github_path = root / 'github path'
            github_path.touch()
            env = dict(os.environ, **step.get('env', {}))
            env.update(PATH=str(tools) + os.pathsep + os.environ['PATH'],
                       RUNNER_TEMP=str(runner_temp), GITHUB_PATH=str(github_path),
                       FIXTURE_DOWNLOAD=str(source), PILOT_CMAKE_SHA256=expected_digest)
            result = subprocess.run(['/bin/bash', '-c', step['run']], cwd=root, env=env,
                                    text=True, capture_output=True)
            return result, properties.read_text(), github_path.read_text(), original

    def test_provisions_pinned_official_package_before_either_apk_build(self):
        steps, setup = self.setup_step()
        self.assertEqual(setup['env']['PILOT_CMAKE_SHA256'],
                         '9196644852a978012caf7a4067ba1898debf6cc204c3341562771e31080d6869')
        self.assertIn('https://dl.google.com/android/repository/cmake-3.22.1-linux.zip', setup['run'])
        for index, step in enumerate(steps):
            if 'flutter build apk' in step.get('run', ''):
                self.assertLess(steps.index(setup), index)

    def test_valid_archive_keeps_flutter_properties_and_selects_verified_tools(self):
        content = self.archive()
        result, properties, path, original = self.run_setup(content, hashlib.sha256(content).hexdigest())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(properties.startswith(original))
        cmake_dir = next(line.removeprefix('cmake.dir=') for line in properties.splitlines()
                         if line.startswith('cmake.dir='))
        self.assertEqual(path.strip(), cmake_dir + '/bin')
        self.assertIn('cmake version 3.22.1-g37088a8', result.stdout)

    def test_html_download_is_rejected_before_selecting_tools(self):
        result, properties, path, original = self.run_setup(b'<html>download failed</html>', '0' * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(properties, original)
        self.assertEqual(path, '')

    def test_damaged_zip_with_matching_digest_is_rejected(self):
        content = self.archive()[:-12]
        result, properties, path, original = self.run_setup(content, hashlib.sha256(content).hexdigest())
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(properties, original)
        self.assertEqual(path, '')


if __name__ == '__main__':
    unittest.main()
