import tempfile
import unittest
from pathlib import Path

from check_release_readiness import check_release
from prepare_release_branch import git, prepare
from release_plan import plan


class ReleaseFlowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.remote = self.root / 'remote.git'
        self.seed = self.root / 'seed'
        self.seed.mkdir()
        git(self.root, 'init', '--bare', str(self.remote))
        git(self.seed, 'init', '-b', 'main')
        git(self.seed, 'remote', 'add', 'origin', str(self.remote))
        (self.seed / 'workout-logger').mkdir()
        (self.seed / 'workout-logger/pubspec.yaml').write_text('version: 2.1.19+90\n', encoding='utf-8')
        (self.seed / 'CHANGELOG.md').write_text(
            '## [2.1.20]\n### Fixes\n- Free-tier fallback.\n'
            '## [2.1.19]\n### Changes\n- Previous.\n', encoding='utf-8')
        (self.seed / 'app.txt').write_text('First feature', encoding='utf-8')
        self.commit('Feature merge')
        git(self.seed, 'push', '-u', 'origin', 'main')
        git(self.remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        self.base = git(self.seed, 'rev-parse', 'HEAD').stdout.strip()
        self.workers = 0

    def commit(self, message):
        git(self.seed, 'add', '.')
        git(self.seed, 'commit', '-m', message)

    def worker(self):
        self.workers += 1
        path = self.root / f'worker-{self.workers}'
        git(self.root, 'clone', str(self.remote), str(path))
        return path

    def test_feature_merge_prepares_pr_and_release_merge_publishes_exact_commit(self):
        self.assertEqual(plan(self.seed, event='push', ref='refs/heads/main', before=self.base),
                         {'mode': 'prepare', 'version': '2.1.20'})
        worker = self.worker()
        branch = prepare(worker, version='2.1.20', build_floor=100)
        self.assertEqual(branch, 'codex/release-2.1.20')
        self.assertEqual(git(self.remote, 'rev-parse', 'main').stdout.strip(), self.base)
        self.assertEqual(check_release(worker, base_ref='origin/main'), '2.1.20')
        self.assertEqual(git(worker, 'diff', '--name-only', 'origin/main...HEAD').stdout.strip(),
                         'workout-logger/pubspec.yaml')
        self.assertIn('version: 2.1.20+100',
                      (worker / 'workout-logger/pubspec.yaml').read_text(encoding='utf-8'))
        git(self.seed, 'fetch', 'origin')
        git(self.seed, 'merge', '--no-ff', '--no-edit', f'origin/{branch}')
        self.assertEqual(plan(self.seed, event='push', ref='refs/heads/main', before=self.base),
                         {'mode': 'publish', 'version': '2.1.20'})
        git(self.seed, 'push', 'origin', 'main')
        self.assertIsNone(prepare(self.worker(), version='2.1.20'))

    def test_existing_release_branch_gets_new_main_features_without_force_push(self):
        branch = prepare(self.worker(), version='2.1.20')
        old_head = git(self.remote, 'rev-parse', branch).stdout.strip()
        (self.seed / 'app.txt').write_text('Second feature', encoding='utf-8')
        self.commit('Another feature merge')
        git(self.seed, 'push', 'origin', 'main')
        new_main = git(self.seed, 'rev-parse', 'HEAD').stdout.strip()
        worker = self.worker()
        self.assertEqual(prepare(worker, version='2.1.20', build_floor=101), branch)
        git(worker, 'merge-base', '--is-ancestor', old_head, 'HEAD')
        self.assertEqual((worker / 'app.txt').read_text(encoding='utf-8'), 'Second feature')
        self.assertEqual(git(self.remote, 'rev-parse', 'main').stdout.strip(), new_main)
        self.assertEqual(check_release(worker, base_ref='origin/main'), '2.1.20')

    def test_missing_target_notes_fail_for_feature_and_prepared_release(self):
        path = self.seed / 'CHANGELOG.md'
        path.write_text('## [2.1.19]\n### Fixes\n- Old.\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.20'):
            check_release(self.seed, base_ref=self.base)
        (self.seed / 'workout-logger/pubspec.yaml').write_text('version: 2.1.20+91\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'no entry for 2.1.20'):
            check_release(self.seed, base_ref=self.base)

    def test_rejects_version_or_build_regressions(self):
        path = self.seed / 'workout-logger/pubspec.yaml'
        for version in ['2.1.18+91', '2.1.20+90', '2.1.19+91']:
            path.write_text(f'version: {version}\n', encoding='utf-8')
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'advance both'):
                check_release(self.seed, base_ref=self.base)

    def test_tag_must_match_committed_version_and_manual_runs_only_verify(self):
        self.assertEqual(plan(self.seed, event='push', ref='refs/tags/v2.1.19'),
                         {'mode': 'publish', 'version': '2.1.19'})
        with self.assertRaisesRegex(ValueError, 'tag does not match'):
            plan(self.seed, event='push', ref='refs/tags/v2.1.20')
        self.assertEqual(plan(self.seed, event='workflow_dispatch', ref='refs/heads/main'),
                         {'mode': 'verify', 'version': '2.1.19'})

    def test_refuses_to_overwrite_a_human_release_branch(self):
        worker = self.worker()
        git(worker, 'switch', '-c', 'codex/release-2.1.20')
        (worker / 'workout-logger/pubspec.yaml').write_text('version: 2.1.20+91\n', encoding='utf-8')
        git(worker, 'add', '.')
        git(worker, '-c', 'user.name=Human', 'commit', '-m', 'Manual preparation')
        git(worker, 'push', 'origin', 'HEAD')
        with self.assertRaisesRegex(ValueError, 'outside bot version preparation'):
            prepare(self.worker(), version='2.1.20')
        self.assertEqual(git(self.remote, 'rev-parse', 'main').stdout.strip(), self.base)

    def test_invalid_release_event_cannot_publish(self):
        for event, ref, before in [('pull_request', 'refs/heads/main', self.base),
                                   ('push', 'refs/heads/feature', self.base),
                                   ('push', 'refs/heads/main', '0' * 40)]:
            with self.subTest(event=event, ref=ref), self.assertRaises(ValueError):
                plan(self.seed, event=event, ref=ref, before=before)


if __name__ == '__main__':
    unittest.main()
