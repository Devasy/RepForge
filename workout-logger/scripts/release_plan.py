"""Choose release preparation or publication without writing to the main branch."""
import argparse
import os
import subprocess
import sys
from pathlib import Path

from check_release_readiness import ROOT, base_pubspec, check_release, read_version


def plan(root=ROOT, *, event, ref, before=None):
    current = read_version((root / 'workout-logger/pubspec.yaml').read_text(encoding='utf-8'))
    if event == 'workflow_dispatch':
        version = check_release(root, current=True)
        mode = 'verify'
    elif event == 'push' and ref.startswith('refs/tags/v'):
        version = check_release(root, current=True)
        if ref != f'refs/tags/v{version}':
            raise ValueError('Release tag does not match pubspec.yaml')
        mode = 'publish'
    elif event == 'push' and ref == 'refs/heads/main' and before and set(before) != {'0'}:
        previous = read_version(base_pubspec(root, before))
        version = check_release(root, base_ref=before)
        mode = 'prepare' if current == previous else 'publish'
    else:
        raise ValueError('Cannot plan a release for this event or missing base commit')
    return {'mode': mode, 'version': version}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--event', default=os.environ.get('GITHUB_EVENT_NAME'))
    parser.add_argument('--ref', default=os.environ.get('GITHUB_REF'))
    parser.add_argument('--before', default=os.environ.get('BEFORE_SHA'))
    args = parser.parse_args()
    try:
        result = plan(event=args.event, ref=args.ref or '', before=args.before)
        print(f"Release plan: {result['mode']} {result['version']}")
        if output := os.environ.get('GITHUB_OUTPUT'):
            with Path(output).open('a', encoding='utf-8') as stream:
                stream.write(''.join(f'{key}={value}\n' for key, value in result.items()))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
