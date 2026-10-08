"""Validate the CHANGELOG.md protocol and extract a release's authored notes."""
import argparse
import re
import sys
from pathlib import Path

CATEGORIES = {'Features added', 'Fixes', 'Changes', 'Removed', 'Known limitations'}
HEADING = re.compile(r'## \[(Unreleased|[0-9]+\.[0-9]+\.[0-9]+)\]')


def parse_changelog(markdown):
    entries = {}
    version = None
    category = None
    sections = {}

    def finish():
        if version is None or version == 'Unreleased':
            return
        if not sections or any(not items for items in sections.values()):
            raise ValueError(f'Changelog {version} must contain nonempty categories')
        entries[version] = '\n\n'.join(
            f'### {name}\n' + '\n'.join(items) for name, items in sections.items()
        )

    seen = set()
    for line in markdown.splitlines():
        if not line.strip():
            continue
        match = HEADING.fullmatch(line)
        if match:
            finish()
            version = match[1]
            if version in seen:
                raise ValueError(f'Duplicate changelog version: {version}')
            seen.add(version)
            category = None
            sections = {}
        elif line.startswith('## '):
            raise ValueError(f'Invalid changelog version heading: {line}')
        elif version is None:
            continue
        elif line.startswith('### '):
            category = line[4:]
            if category not in CATEGORIES or category in sections:
                raise ValueError(f'Invalid or duplicate changelog category: {category}')
            sections[category] = []
        elif line.startswith('- ') and line[2:].strip() and category is not None:
            sections[category].append(line)
        else:
            raise ValueError(f'Expected a category or single-line bullet: {line}')
    finish()
    if not seen:
        raise ValueError('No changelog entries found')
    return entries


def build(version, path=Path('CHANGELOG.md')):
    entries = parse_changelog(path.read_text(encoding='utf-8'))
    if version not in entries:
        raise ValueError(f'CHANGELOG.md has no entry for {version}; author release notes before releasing')
    return entries[version]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version', nargs='?')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        if args.check:
            parse_changelog(Path('CHANGELOG.md').read_text(encoding='utf-8'))
        elif args.version:
            print(build(args.version))
        else:
            parser.error('provide a version or --check')
    except (ValueError, OSError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
