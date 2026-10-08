Release notes are published as GitHub Release bodies and fetched by the app.
For an authored changelog, add `docs/releases/<version>.md` before releasing
that version. Use these sections when applicable:

- Features added
- Fixes
- Changes
- Removed
- Known limitations

The release workflow uses the authored file when present. Otherwise it groups
merged PR titles by labels (`feature`/`enhancement`, `bug`/`fix`, `removed`,
`breaking-change`, `known limitation`/`known-limitations`) and conventional
`feat:`, `fix:`, and `remove:` prefixes. Unclassified PRs appear in Changes.
Omitted categories mean no entries were supplied, not that the app has no
known limitations. Authors should explicitly record unresolved limitations.
Historical release bodies are retained; the app aggregates versions newer
than the user's previously seen version through the installed version.

Update notices compare stable public GitHub releases. Store/F-Droid rollout
availability can differ; users should install from their existing channel.
