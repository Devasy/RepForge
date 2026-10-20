"""Check authored notes for the version the release workflow will actually build."""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from build_release_notes import build

ROOT = Path(__file__).resolve().parents[2]
BUMP_SCRIPT = ROOT / 'scripts/bump_version.dart'


def read_version(pubspec):
    match = re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$',
                      pubspec, re.MULTILINE)
    if match is None:
        raise ValueError('Could not read the release version')
    return match[1], int(match[2] or 0)


def base_pubspec(root, ref):
    if ref.startswith('-') or not re.fullmatch(r'[a-zA-Z0-9_./-]+', ref):
        raise ValueError('Invalid base reference')
    return subprocess.run(
        ['git', 'show', f'{ref}:workout-logger/pubspec.yaml'], cwd=root,
        check=True, capture_output=True, text=True, encoding='utf-8',
    ).stdout


def next_version(pubspec):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / 'workout-logger').mkdir()
        (root / 'workout-logger/pubspec.yaml').write_text(pubspec, encoding='utf-8')
        result = subprocess.run(
            [os.environ.get('DART', 'dart'), str(BUMP_SCRIPT), 'patch', '--dry-run'],
            cwd=root, check=True, capture_output=True, text=True, encoding='utf-8',
        )
        match = re.search(r'^NEW_VERSION=([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$',
                          result.stdout, re.MULTILINE)
        if match is None:
            raise ValueError('The version bump did not report a release version')
        return match[1]


def check_release(root=ROOT, *, current=False, base_ref=None):
    pubspec = (root / 'workout-logger/pubspec.yaml').read_text(encoding='utf-8')
    version, build_number = read_version(pubspec)
    if not current:
        baseline = base_pubspec(root, base_ref) if base_ref else pubspec
        base_version, base_build = read_version(baseline)
        if (version, build_number) == (base_version, base_build):
            version = next_version(baseline)
        elif (tuple(map(int, version.split('.'))) <= tuple(map(int, base_version.split('.')))
              or build_number <= base_build):
            raise ValueError('A prepared release must advance both version and build number')
    build(version, root / 'CHANGELOG.md')
    return version


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--current', action='store_true',
                        help='Check tag/manual builds, which do not bump the version')
    parser.add_argument('--base-ref', help='Compare a feature or release PR with this Git base')
    args = parser.parse_args()
    try:
        version = check_release(current=args.current, base_ref=args.base_ref)
        print(f'Release readiness passed: CHANGELOG.md has authored notes for {version}')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: release readiness failed: {error}', file=sys.stderr)
        sys.exit(1)
