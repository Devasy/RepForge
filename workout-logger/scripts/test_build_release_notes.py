import tempfile
import unittest
from pathlib import Path
from build_release_notes import build, parse_changelog


class ChangelogTests(unittest.TestCase):
    def test_extract_exact_version_and_ignore_unreleased(self):
        notes = '# Changelog\n## [Unreleased]\n### Changes\n- Draft.\n## [2.1.6]\n### Fixes\n- Fixed.\n## [2.1.5]\n### Removed\n- Old.\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'CHANGELOG.md'
            path.write_text(notes)
            self.assertEqual(build('2.1.6', path), '### Fixes\n- Fixed.')
            with self.assertRaises(ValueError):
                build('2.1.7', path)
            with self.assertRaises(ValueError):
                build('Unreleased', path)

    def test_reject_malformed_entries(self):
        for markdown in [
            '', '## [2.1.6]\n',
            '## [2.1.6-beta]\n### Fixes\n- Fix.',
            '## [2.1.6] - 2026-10-08\n### Fixes\n- Fix.',
            '## [2.1.6]\n### Fixed\n- Fix.',
            '## [2.1.6]\n### Fixes\n',
            '## [2.1.6]\n- Orphan bullet.',
            '## [2.1.6]\n### Fixes\n- Fix.\n  Continuation.',
            '## [2.1.6]\n### Fixes\n- Fix.\n### Fixes\n- Duplicate.',
            '## [2.1.6]\n### Fixes\n- Fix.\n## [2.1.6]\n### Changes\n- Duplicate.',
        ]:
            with self.subTest(markdown=markdown), self.assertRaises(ValueError):
                parse_changelog(markdown)

    def test_repository_changelog(self):
        root = Path(__file__).resolve().parents[2]
        self.assertIn('Features added', build('2.1.6', root / 'CHANGELOG.md'))


if __name__ == '__main__':
    unittest.main()
