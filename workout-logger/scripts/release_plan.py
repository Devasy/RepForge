"""Select only merged same-repository release PRs or manual release-branch builds."""
import json
import os
import re
import sys
from pathlib import Path

from check_release_readiness import branch_version


def plan(*, event_name, event, repository, ref_name, sha):
    publish = False
    if event_name == 'pull_request':
        pr = event['pull_request']
        if (event.get('action') != 'closed' or not pr.get('merged')
                or pr['base']['ref'] != 'main'
                or pr['head']['repo']['full_name'].lower() != repository.lower()):
            return None
        branch = pr['head']['ref']
        commit = pr['merge_commit_sha']
        publish = True
    elif event_name == 'workflow_dispatch':
        branch, commit = ref_name, sha
    else:
        return None
    try:
        version = branch_version(branch)
    except ValueError:
        return None
    if version is None:
        return None
    if not re.fullmatch(r'[a-f0-9]{40}', commit or ''):
        raise ValueError('Release source must be an exact commit SHA')
    return {'version': version, 'branch': branch, 'commit': commit,
            'publish': str(publish).lower()}


if __name__ == '__main__':
    try:
        result = plan(event_name=os.environ['GITHUB_EVENT_NAME'],
                      event=json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8')),
                      repository=os.environ['GITHUB_REPOSITORY'],
                      ref_name=os.environ['GITHUB_REF_NAME'], sha=os.environ['GITHUB_SHA'])
        print(f'Release selection: {result or "ordinary branch; no release"}')
        if output := os.environ.get('GITHUB_OUTPUT'):
            with Path(output).open('a', encoding='utf-8') as stream:
                stream.write(f'eligible={str(result is not None).lower()}\n')
                if result:
                    stream.write(''.join(f'{key}={value}\n' for key, value in result.items()))
    except (ValueError, KeyError, OSError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
