# Changelog authoring contract

`CHANGELOG.md` at the repository root is the single source for user-facing release
notes. Developers must author the target version before merging a release PR.
The existing main-branch release workflow increments the patch version: with
pubspec at 2.1.5, author `## [2.1.6]`. Tag/manual builds use the pubspec version.

```markdown
# Changelog

## [Unreleased]

## [2.1.6]

### Features added
- Describe a user-visible feature.

### Fixes
- Describe the problem fixed.

### Changes
- Describe changed behavior.

### Removed
- Describe what was removed and its replacement, if any.

### Known limitations
- Describe an unresolved limitation.
```

Rules:
- Version headings are exactly `## [MAJOR.MINOR.PATCH]`; no `v`, dates, build
  numbers or prerelease suffixes. Each version occurs once.
- Optional `## [Unreleased]` occurs at most once and is never shown or published.
- The five category names above are case-sensitive. Omit categories with no
  changes. Each included category has at least one nonempty `- ` bullet.
- Write each bullet on one line. Nested lists, wrapped bullets, code fences and
  arbitrary prose inside entries are not supported. Inline Markdown is allowed;
  the current app presents notes as selectable text.
- A released version must have at least one category. Put introductory prose
  before the first version. Keep previous version entries so skipped upgrades
  can display all intervening notes. List newest versions first for readability.
- Keep published entries intact apart from corrections. Do not fabricate old
  release history: only 2.1.6 is authored initially.

CI validates the complete file. The release workflow requires a valid entry for
its exact target version **before committing a version bump, tagging or deploying**.
Missing/malformed notes fail the release; there is no PR-title fallback. The
matching entry becomes the GitHub Release body alongside the downloadable assets.

The app fetches `https://raw.githubusercontent.com/Devasy/RepForge/main/CHANGELOG.md`,
validates it, and shows entries where previous version < entry <= installed
version. It caches successful fetches in memory for six hours; network or parsing
failures offer Retry. Unreleased entries never reach users. Update badges still
check actual GitHub Releases, since a changelog entry can be committed before an
installable release exists.
