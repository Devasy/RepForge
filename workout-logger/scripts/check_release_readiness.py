"""Check authored notes for the version the release workflow will actually build."""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from build_release_notes import build

ROOT = Path(__file__).resolve().parents[2]
BUMP_SCRIPT = ROOT / 'scripts/bump_version.dart'


def check_release(root=ROOT, *, current=False):
    if current:
        pubspec = (root / 'workout-logger/pubspec.yaml').read_text(encoding='utf-8')
        match = re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$',
                          pubspec, re.MULTILINE)
        if match is None:
            raise ValueError('Could not read the current release version')
        version = match[1]
    else:
        result = subprocess.run(
            [os.environ.get('DART', 'dart'), str(BUMP_SCRIPT), 'patch', '--dry-run'],
            cwd=root, check=True, capture_output=True, text=True, encoding='utf-8',
        )
        match = re.search(r'^NEW_VERSION=([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$',
                          result.stdout, re.MULTILINE)
        if match is None:
            raise ValueError('The version bump did not report a release version')
        version = match[1]
    build(version, root / 'CHANGELOG.md')
    return version


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current', action='store_true',
                        help='Check tag/manual builds, which do not bump the version')
    args = parser.parse_args()
    try:
        version = check_release(current=args.current)
        print(f'Release readiness passed: CHANGELOG.md has authored notes for {version}')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: release readiness failed: {error}', file=sys.stderr)
        sys.exit(1)
