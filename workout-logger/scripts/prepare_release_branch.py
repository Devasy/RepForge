"""Push a release-preparation branch while leaving main unchanged."""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from check_release_readiness import BUMP_SCRIPT, ROOT, base_pubspec, check_release, read_version

PUBSPEC = 'workout-logger/pubspec.yaml'
BOT_NAME = 'github-actions[bot]'


def git(root, *args, check=True):
    return subprocess.run(
        ['git', '-c', f'user.name={BOT_NAME}', '-c',
         'user.email=41898282+github-actions[bot]@users.noreply.github.com', *args],
        cwd=root, check=check, capture_output=True, text=True, encoding='utf-8',
    )


def prepare(root=ROOT, *, version, build_floor=0):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) or build_floor < 0:
        raise ValueError('Invalid release version or build floor')
    git(root, 'fetch', 'origin')
    main_version, _ = read_version(base_pubspec(root, 'origin/main'))
    if tuple(map(int, main_version.split('.'))) >= tuple(map(int, version.split('.'))):
        return None
    branch = f'codex/release-{version}'
    remote = f'origin/{branch}'
    exists = git(root, 'show-ref', '--verify', f'refs/remotes/{remote}', check=False).returncode == 0
    if exists:
        files = git(root, 'diff', '--name-only', f'origin/main...{remote}').stdout.splitlines()
        authors = set(git(root, 'log', '--format=%an', f'origin/main..{remote}').stdout.splitlines())
        if files != [PUBSPEC] or authors != {BOT_NAME}:
            raise ValueError('Existing release branch contains changes outside bot version preparation')
        if read_version(base_pubspec(root, remote))[0] != version:
            raise ValueError('Existing release branch has an unexpected version')
        git(root, 'switch', '-c', branch, remote)
        git(root, 'merge', '--no-edit', 'origin/main')
    else:
        git(root, 'switch', '-c', branch, 'origin/main')
        if check_release(root) != version:
            raise ValueError('Main has advanced; recompute the release target')
        subprocess.run(
            [os.environ.get('DART', 'dart'), str(BUMP_SCRIPT), 'patch'], cwd=root,
            check=True, capture_output=True,
            env={key: value for key, value in os.environ.items() if key != 'GITHUB_OUTPUT'},
        )
    path = root / PUBSPEC
    content = path.read_text(encoding='utf-8')
    prepared_version, build = read_version(content)
    if prepared_version != version:
        raise ValueError('Prepared version does not match release plan')
    if build < build_floor:
        path.write_text(re.sub(r'^version: .*$', f'version: {version}+{build_floor}',
                               content, flags=re.MULTILINE), encoding='utf-8')
    check_release(root, current=True)
    git(root, 'add', '--', PUBSPEC)
    if git(root, 'diff', '--cached', '--quiet', check=False).returncode:
        git(root, 'commit', '-m', f'chore(release): prepare {version}')
    git(root, 'push', 'origin', f'HEAD:refs/heads/{branch}')
    return branch


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version')
    parser.add_argument('--build-floor', type=int, default=0)
    args = parser.parse_args()
    try:
        branch = prepare(version=args.version, build_floor=args.build_floor)
        print(f'Release branch: {branch or "already prepared on main"}')
        if output := os.environ.get('GITHUB_OUTPUT'):
            with Path(output).open('a', encoding='utf-8') as stream:
                stream.write(f'branch={branch or ""}\n')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
