# Changelog

User-facing changes. Follow [the changelog format](docs/changelog-format.md).

## [Unreleased]

## [2.1.6]

### Features added
- Discover available stable Gemini Flash models from Google in AI settings.
- Read upgrade notes from the repository CHANGELOG.md, including skipped releases, and show an update notice in Profile.
- Choose assisted or weighted load for pull-ups, chin-ups and dips; log push-ups with added weight.

### Fixes
- Preserve training programs, personal records, coach and optimizer chats, and attachments in backups; reject malformed backups before importing.
- Preserve workout effort in SQLite and imported data.
- Keep legacy raw-load history separate from bodyweight-based trend and progression calculations (#67).
- Progress assisted exercises by reducing assistance; preserve bodyweight at logging time (#68).
- Preserve separate handle records with canonical exercise IDs across migrations and backups (#69).

### Known limitations
- Historical sets without a recorded bodyweight retain their original values. They cannot be converted reliably and are excluded from comparisons with the new load convention.
- Update notices use public GitHub releases; availability may differ by installation channel.
- Model discovery requires a valid Gemini API key. Refreshing the list preserves the selected model.
