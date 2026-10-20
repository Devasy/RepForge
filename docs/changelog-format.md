# Changelog authoring contract

`CHANGELOG.md` at the repository root is the single source for user-facing release
notes. Ordinary feature PRs can add draft notes under `## [Unreleased]` and
merge without starting a release. Cut a release branch named exactly `rX.Y.Z`
from current main, for example `r2.1.20`, and author its `## [2.1.20]` entry.
Preparation reads that branch name and updates pubspec version/build on the
release branch. Merging its checked PR to main publishes that committed version.

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
  release history. Versions 2.0.1 through 2.1.5 are reconstructed from published
  releases and tagged changes; see [the source map](changelog-history-sources.md).

The required `Release readiness` check always validates changelog format.
Ordinary PRs keep the version/build unchanged. Release PRs must have a pubspec
version matching their `rX.Y.Z` branch exactly, a semantic version and build
number newer than current main, and a nonempty changelog entry for that exact
version. Unreleased drafts cannot satisfy a release check. A typo such as
`r2.1.20-extra` is rejected. Do not reuse a published release branch.

Run the same check from the repository root:

```sh
git fetch origin main
python3 workout-logger/scripts/check_release_readiness.py --branch r2.1.20 --base-ref origin/main
```

Creating or pushing a release branch runs preparation. If its notes are missing,
preparation fails before changing pubspec; add the exact entry and push again.
Preparation is idempotent and never pushes commits to main. The bot explicitly
dispatches CI after updating the release branch. Normal branches do not need a
future release entry and version changes on them fail the check.

Only a merged same-repository `rX.Y.Z` PR targeting main can publish or deploy to
Google Play. The release workflow checks the branch version against the exact
merge commit's pubspec and notes before building. Tags are created only after
the signed builds and APK version checks pass. Manual runs on release branches
build validation artifacts without publishing. Main pushes and tag pushes do
not trigger release publication. The matching changelog entry becomes the
GitHub Release body; there is no PR-title fallback.

The app fetches `https://raw.githubusercontent.com/Devasy/RepForge/main/CHANGELOG.md`,
validates it, and shows entries where previous version < entry <= installed
version. It caches successful fetches in memory for six hours; network or parsing
failures offer Retry. Unreleased entries never reach users. Update badges still
check actual GitHub Releases, since a changelog entry can be committed before an
installable release exists.
