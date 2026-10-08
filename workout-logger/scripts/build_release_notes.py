"""Build user-facing release notes from labeled PRs or authored version notes."""
import json
import re
import sys
from pathlib import Path


def build(prs, version):
    authored = Path('docs/releases') / f'{version}.md'
    if authored.is_file():
        return authored.read_text().strip()
    groups = {name: [] for name in ['Features added', 'Fixes', 'Changes', 'Removed', 'Known limitations']}
    for pr in prs:
        title = pr['title']
        labels = {label['name'].lower() for label in pr.get('labels', [])}
        prefix = title.lower()
        if labels & {'known limitation', 'known-limitations'}:
            category = 'Known limitations'
        elif labels & {'removed', 'breaking-change'} or prefix.startswith(('remove:', 'removed:')):
            category = 'Removed'
        elif labels & {'bug', 'fix'} or re.match(r'^fix(?:\([^)]*\))?:', prefix):
            category = 'Fixes'
        elif labels & {'enhancement', 'feature'} or re.match(r'^feat(?:\([^)]*\))?:', prefix):
            category = 'Features added'
        else:
            category = 'Changes'
        groups[category].append(f"- {title} (#{pr['number']})")
    return '\n\n'.join(f"### {category}\n" + '\n'.join(items) for category, items in groups.items() if items) or 'No user-facing release notes were published.'


if __name__ == '__main__':
    print(build(json.load(sys.stdin), sys.argv[1]))
