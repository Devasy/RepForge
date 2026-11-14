# Home Health Metric Cards Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show real HRV RMSSD and skin-temperature graphs on Home alongside heart rate and sleep.

**Architecture:** A small HealthMetricsService reads the existing Health Connect interface and builds daily series. Two instances of one card widget show independent access, loading, empty, error and chart states. Production uses a strict reader so failed reads are not reported as empty successful results.

**Tech Stack:** Existing Flutter, Provider, fl_chart and RepForge GlassCard/theme components. No new dependencies or database migration.

**Spec:** The user requested both graphs as Home cards like the existing HR/sleep cards. Preserve both permissions and all existing saved history. No new readiness formula or diagnostic claims.

## Constraints and review focus

- Cards remain discoverable without a readiness baseline or configured Coach.
- Each access action requests only that metric; ordinary readiness setup requests sleep, HR and resting HR.
- Plot 7 local calendar days through now; exclude future and invalid samples, retain gaps, support a single real reading.
- HRV is RMSSD in milliseconds and daily averages are labelled.
- Reconstruct absolute skin temperature only from an available baseline plus delta. Separate sources, locations and absolute versus delta series. Delta-only series with different source record baselines are not joined.
- Denied/unavailable/read failure/no samples are separate states; resume/refresh rechecks access.
- Automated fixture data stays in tests. Approval by Google and live-device readings are separate from local test results.

## Tasks

1. [ ] Test then implement daily series and per-metric permission access in `lib/services/health_metrics_service.dart`, `lib/services/health_connect_service.dart`, and the existing interface file. Tests: `test/health_metrics_service_test.dart`.
2. [ ] Test then implement `lib/screens/widgets/health_metric_card.dart` and its chart, wire cards into Home and the service into main/TestHarness. Tests: `test/health_metric_card_test.dart`, existing Home/readiness tests. Keep established dark glass/Geist styling.
3. [ ] Update Profile copy, changelog and reviewer guide; run focused/full Flutter tests, analysis, debug APK build, inspect final merged Android permissions, then prepare a reviewable PR and debug artifact. Live verification remains required before describing a recording or Google approval as complete.
