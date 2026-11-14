# Release CI and coverage implementation plan

**Goal:** Make PR #104's patch coverage pass, migrate Actions to Node 24, and validate the release build against an eleven-minute target.

**Approach:** Keep sequential AAB/APK builds and their shared compilation. Use JDK 21 for CI while retaining Android bytecode target 17. Preserve publication guards, signing, F-Droid flags, coverage thresholds and artifact version schemes.

- [ ] Add widget tests for selected program JSON, cancellation, and read failure; verify coverage of the migrated picker lines.
- [ ] Pin verified Node 24 Actions across all four workflows and cache pure-Dart pub dependencies.
- [ ] Dispatch prepared-release checks only after a bot version commit; skip duplicate release-branch push jobs when a PR already provides checks.
- [ ] Enable Gradle task caching in CI, retain configuration-cache opt-out, add job concurrency/timeouts and PR release-APK metadata verification.
- [ ] Run local checks, obtain a focused review, update PR #104, and wait for Codecov and GitHub checks.
- [ ] Manually dispatch the release branch in validation-only mode; measure build duration without publishing or deploying.

**Baseline:** Last successful release build job: 10m05s. PR Android verification: approximately 11 minutes. The current commit also produced redundant push and dispatch runs. No runtime speedup or fixed wall-clock SLA is assumed.
