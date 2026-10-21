import copy
import unittest

from release_plan import plan


class ReleaseSelectionTests(unittest.TestCase):
    def setUp(self):
        self.sha = 'a' * 40
        self.event = {'action': 'closed', 'pull_request': {
            'merged': True, 'merge_commit_sha': self.sha,
            'base': {'ref': 'main'},
            'head': {'ref': 'r2.1.20', 'repo': {'full_name': 'Devasy/RepForge'}},
        }}

    def select(self, event=None, event_name='pull_request', ref_name='main'):
        return plan(event_name=event_name, event=event or self.event,
                    repository='Devasy/RepForge', ref_name=ref_name, sha='b' * 40)

    def test_only_merged_release_pr_selects_exact_merge_commit_for_publication(self):
        self.assertEqual(self.select(), {'version': '2.1.20', 'branch': 'r2.1.20',
                                        'commit': self.sha, 'publish': 'true'})

    def test_regular_prs_pushes_closed_unmerged_and_forks_never_publish(self):
        for branch in ['codex/feature', 'refactor/flow', 'r2.1.20-extra']:
            event = copy.deepcopy(self.event)
            event['pull_request']['head']['ref'] = branch
            self.assertIsNone(self.select(event))
        for key, value in [('merged', False), ('base', {'ref': 'develop'})]:
            event = copy.deepcopy(self.event)
            event['pull_request'][key] = value
            self.assertIsNone(self.select(event))
        event = copy.deepcopy(self.event)
        event['pull_request']['head']['repo']['full_name'] = 'other/fork'
        self.assertIsNone(self.select(event))
        self.assertIsNone(self.select(event_name='push'))

    def test_manual_builds_only_verify_release_branches(self):
        self.assertEqual(self.select(event_name='workflow_dispatch', ref_name='r2.1.20')['publish'], 'false')
        self.assertIsNone(self.select(event_name='workflow_dispatch', ref_name='main'))

    def test_invalid_commit_cannot_be_published(self):
        self.event['pull_request']['merge_commit_sha'] = 'main'
        with self.assertRaisesRegex(ValueError, 'exact commit SHA'):
            self.select()


if __name__ == '__main__':
    unittest.main()
