"""Update pubspec from the current rMAJOR.MINOR.PATCH branch; never edit main."""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from build_release_notes import build
from check_release_readiness import PUBSPEC, ROOT, base_pubspec, branch_version, read_version, require_advance


def prepare(root=ROOT, *, branch, base_ref='origin/main'):
    version = branch_version(branch)
    if version is None:
        raise ValueError('Version preparation only accepts rMAJOR.MINOR.PATCH branches')
    checked_out = subprocess.run(
        ['git', 'branch', '--show-current'], cwd=root, check=True,
        capture_output=True, text=True, encoding='utf-8',
    ).stdout.strip()
    if checked_out != branch:
        raise ValueError('Check out the named release branch before preparing its version')
    build(version, root / 'CHANGELOG.md')
    baseline = base_pubspec(root, base_ref)
    base_version, base_build = read_version(baseline)
    require_advance(version, base_build + 1, baseline)
    path = root / PUBSPEC
    content = path.read_text(encoding='utf-8')
    current_version, current_build = read_version(content)
    if current_version not in {base_version, version}:
        raise ValueError('Refusing to overwrite a different version already in pubspec')
    prepared_build = max(current_build, base_build + 1)
    if (current_version, current_build) == (version, prepared_build):
        return False
    path.write_text(re.sub(r'^version: .*$', f'version: {version}+{prepared_build}',
                           content, flags=re.MULTILINE), encoding='utf-8')
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--branch', required=True)
    parser.add_argument('--base-ref', default='origin/main')
    args = parser.parse_args()
    try:
        changed = prepare(branch=args.branch, base_ref=args.base_ref)
        print(f'Release version {"prepared" if changed else "already matches branch"}: {args.branch}')
        if output := os.environ.get('GITHUB_OUTPUT'):
            with Path(output).open('a', encoding='utf-8') as stream:
                stream.write(f'changed={str(changed).lower()}\n')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
