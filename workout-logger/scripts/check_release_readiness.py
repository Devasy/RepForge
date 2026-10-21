"""Validate release branches against their exact version and authored notes."""
import argparse
import re
import subprocess
import sys
from pathlib import Path

from build_release_notes import build, parse_changelog

ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = 'workout-logger/pubspec.yaml'


def branch_version(branch):
    match = re.fullmatch(r'r([0-9]+\.[0-9]+\.[0-9]+)', branch)
    if match:
        return match[1]
    if re.match(r'^r[0-9]', branch):
        raise ValueError('Release branches must be named rMAJOR.MINOR.PATCH')
    return None


def read_version(pubspec):
    match = re.search(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
                      pubspec, re.MULTILINE)
    if match is None:
        raise ValueError('pubspec.yaml needs version: MAJOR.MINOR.PATCH+BUILD')
    return match[1], int(match[2])


def base_pubspec(root, ref):
    if ref.startswith('-') or not re.fullmatch(r'[a-zA-Z0-9_./-]+', ref):
        raise ValueError('Invalid base reference')
    return subprocess.run(
        ['git', 'show', f'{ref}:{PUBSPEC}'], cwd=root, check=True,
        capture_output=True, text=True, encoding='utf-8',
    ).stdout


def require_advance(version, build_number, baseline):
    base_version, base_build = read_version(baseline)
    if (tuple(map(int, version.split('.'))) <= tuple(map(int, base_version.split('.')))
            or build_number <= base_build):
        raise ValueError('A release must advance both version and build number beyond main')


def check_release(root=ROOT, *, branch, base_ref=None):
    version = branch_version(branch)
    notes_path = root / 'CHANGELOG.md'
    if version is None:
        parse_changelog(notes_path.read_text(encoding='utf-8'))
        if base_ref:
            actual = read_version((root / PUBSPEC).read_text(encoding='utf-8'))
            if actual != read_version(base_pubspec(root, base_ref)):
                raise ValueError('Version changes belong on an rMAJOR.MINOR.PATCH release branch')
        return None
    build(version, notes_path)
    actual_version, build_number = read_version((root / PUBSPEC).read_text(encoding='utf-8'))
    if actual_version != version:
        raise ValueError(f'{branch} requires pubspec version {version}; release preparation must finish first')
    if base_ref:
        require_advance(version, build_number, base_pubspec(root, base_ref))
    return version


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--branch', required=True)
    parser.add_argument('--base-ref')
    args = parser.parse_args()
    try:
        version = check_release(branch=args.branch, base_ref=args.base_ref)
        print(f'Release readiness passed: {version or "ordinary branch; changelog format valid"}')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
