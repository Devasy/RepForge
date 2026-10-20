import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from check_release_readiness import BUMP_SCRIPT, ROOT, check_release


class ReleaseReadinessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'workout-logger').mkdir()
        self.pubspec = self.root / 'workout-logger/pubspec.yaml'
        self.pubspec.write_text('name: test_app\nversion: 2.1.19+90\n', encoding='utf-8')
        self.changelog = self.root / 'CHANGELOG.md'
        self.changelog.write_text(
            '# Changelog\n## [Unreleased]\n### Fixes\n- Draft notes.\n'
            '## [2.1.19]\n### Changes\n- Current version.\n', encoding='utf-8')

    def test_missing_2_1_20_fails_even_with_current_and_unreleased_notes(self):
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.20'):
            check_release(self.root)

    def test_exact_auto_bumped_version_passes_without_mutating_files_or_ci_output(self):
        self.changelog.write_text('## [2.1.20]\n### Fixes\n- Timeouts.\n', encoding='utf-8')
        output = self.root / 'github_output'
        output.write_text('existing=value\n', encoding='utf-8')
        before = {path: path.read_bytes() for path in [self.pubspec, self.changelog, output]}
        with patch.dict(os.environ, {'GITHUB_OUTPUT': str(output)}):
            self.assertEqual(check_release(self.root), '2.1.20')
        for path, contents in before.items():
            self.assertEqual(path.read_bytes(), contents)
        subprocess.run(
            [os.environ.get('DART', 'dart'), str(BUMP_SCRIPT), 'patch'],
            cwd=self.root, check=True, capture_output=True,
            env={key: value for key, value in os.environ.items() if key != 'GITHUB_OUTPUT'},
        )
        self.assertIn('version: 2.1.20+91', self.pubspec.read_text(encoding='utf-8'))

    def test_empty_target_notes_fail(self):
        self.changelog.write_text('## [2.1.20]\n### Fixes\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'nonempty categories'):
            check_release(self.root)

    def test_tag_or_manual_build_requires_current_version_notes(self):
        self.assertEqual(check_release(self.root, current=True), '2.1.19')
        self.changelog.write_text('## [2.1.20]\n### Fixes\n- Next.\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.19'):
            check_release(self.root, current=True)

    def test_advancing_base_requires_updated_target_entry(self):
        self.changelog.write_text('## [2.1.20]\n### Fixes\n- Next.\n', encoding='utf-8')
        self.assertEqual(check_release(self.root), '2.1.20')
        self.pubspec.write_text('version: 2.1.20+91\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.21'):
            check_release(self.root)

    def test_repository_is_ready_for_actual_auto_bump(self):
        self.assertRegex(check_release(ROOT), r'^\d+\.\d+\.\d+$')


if __name__ == '__main__':
    unittest.main()
