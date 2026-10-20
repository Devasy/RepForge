import tempfile
import subprocess
import unittest
from pathlib import Path

from check_release_readiness import PUBSPEC, branch_version, check_release
from prepare_release_version import prepare


class ReleaseReadinessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git('init', '-b', 'main')
        (self.root / 'workout-logger').mkdir()
        self.pubspec = self.root / PUBSPEC
        self.pubspec.write_text('version: 2.1.19+90\n', encoding='utf-8')
        self.notes = self.root / 'CHANGELOG.md'
        self.notes.write_text('## [2.1.19]\n### Changes\n- Previous.\n', encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-m', 'Baseline')
        self.base = self.git('rev-parse', 'HEAD')
        self.git('switch', '-c', 'r2.1.20')

    def git(self, *args):
        return subprocess.run(
            ['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.com', *args],
            cwd=self.root, check=True, capture_output=True, text=True, encoding='utf-8',
        ).stdout.strip()

    def author_notes(self):
        self.notes.write_text('## [2.1.20]\n### Fixes\n- Fallback.\n', encoding='utf-8')

    def test_missing_2_1_20_notes_fail_before_version_changes(self):
        before = self.pubspec.read_bytes()
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.20'):
            prepare(self.root, branch='r2.1.20', base_ref=self.base)
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.20'):
            check_release(self.root, branch='r2.1.20', base_ref=self.base)
        self.assertEqual(self.pubspec.read_bytes(), before)

    def test_branch_prepares_exact_version_and_build_idempotently(self):
        self.author_notes()
        self.assertTrue(prepare(self.root, branch='r2.1.20', base_ref=self.base))
        self.assertEqual(self.pubspec.read_text(encoding='utf-8'), 'version: 2.1.20+91\n')
        self.assertFalse(prepare(self.root, branch='r2.1.20', base_ref=self.base))
        self.assertEqual(check_release(self.root, branch='r2.1.20', base_ref=self.base), '2.1.20')
        self.assertEqual(self.git('rev-parse', 'main'), self.base)

    def test_release_pr_cannot_pass_before_branch_version_matches(self):
        self.author_notes()
        with self.assertRaisesRegex(ValueError, 'requires pubspec version 2.1.20'):
            check_release(self.root, branch='r2.1.20', base_ref=self.base)

    def test_ordinary_pr_needs_no_future_release_entry_or_version_bump(self):
        before = self.pubspec.read_bytes()
        self.assertIsNone(check_release(self.root, branch='codex/feature', base_ref=self.base))
        with self.assertRaisesRegex(ValueError, 'only accepts'):
            prepare(self.root, branch='main', base_ref=self.base)
        self.assertEqual(self.pubspec.read_bytes(), before)
        self.pubspec.write_text('version: 2.1.20+91\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Version changes belong'):
            check_release(self.root, branch='codex/feature', base_ref=self.base)

    def test_wrong_or_regressive_versions_and_builds_are_rejected(self):
        self.author_notes()
        for version in ['2.1.20+90', '2.1.18+91', '2.1.21+91']:
            self.pubspec.write_text(f'version: {version}\n', encoding='utf-8')
            with self.subTest(version=version), self.assertRaises(ValueError):
                check_release(self.root, branch='r2.1.20', base_ref=self.base)
        self.pubspec.write_text('version: 2.1.21+91\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'overwrite a different version'):
            prepare(self.root, branch='r2.1.20', base_ref=self.base)

    def test_new_main_version_makes_old_release_branch_invalid(self):
        self.author_notes()
        prepare(self.root, branch='r2.1.20', base_ref=self.base)
        self.git('add', '.')
        self.git('commit', '-m', 'Release already merged')
        with self.assertRaisesRegex(ValueError, 'advance both'):
            check_release(self.root, branch='r2.1.20', base_ref='HEAD')

    def test_release_branch_names_are_exact(self):
        self.assertEqual(branch_version('r2.1.20'), '2.1.20')
        for branch in ['r2.1.20-extra', 'r2.1', 'r2.1.20/evil']:
            with self.subTest(branch=branch), self.assertRaises(ValueError):
                branch_version(branch)
        self.assertIsNone(branch_version('refactor/flow'))

    def test_preparation_refuses_to_edit_main_even_with_a_release_argument(self):
        self.git('switch', 'main')
        self.author_notes()
        before = self.pubspec.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Check out the named release branch'):
            prepare(self.root, branch='r2.1.20', base_ref=self.base)
        self.assertEqual(self.pubspec.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
