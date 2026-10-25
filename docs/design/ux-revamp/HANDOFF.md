# Next-session handoff prompt

Copy the following into a new session, then append the scope you want implemented or refined.

---

We are continuing the RepForge UX revamp planning. Repository: Devasy/RepForge. The saved design branch is `design/ux-revamp-handoff`. Check it out and read:

1. `docs/design/ux-revamp/README.md`
2. `docs/design/ux-revamp/ANALYSIS.md`
3. `docs/design/ux-revamp/mockups/README.md`
4. All three PNG boards under `docs/design/ux-revamp/mockups/`

Read applicable repository instructions and compare against current main before changing code. Keep this design bundle intact. If starting implementation, create a separate feature branch from current main and carry forward the design documents as needed; do not turn the design branch into a release branch.

Context: PR #93 released the fix for Android CursorWindow failures caused by oversized conversation rows. The user confirmed old chats now load. Conversation messages are stored in independent bounded chunks with a v7 migration; backup diagnostics remain useful and must stay. Coach SQL is restricted from conversation storage. Preserve these fixes, attachments, Unicode content, backups, and existing data.

The user liked the proposed UX direction and requested mockups for all remaining improvements. This branch saves approved visual direction and analysis, not implemented UI. It does not by itself authorize implementing every capability pictured. Follow the new session's explicit scope, then work autonomously within it.

Design intent: keep the dark/purple RepForge identity and offline-first model. Make Home action-focused, choose the next workout honestly, streamline repeated set logging, keep the timer inline while preparing the next set, allow explicit Minimize and persistent Resume, clarify Train/Routines/Programs, add contextual coaching with clear before/after approvals, show truthful health freshness, make personalization optional, simplify corrections and completion, and improve backup/restore confidence and accessibility.

Recommended first implementation scope, if authorized: Home + active workout. Start with next-workout selection and truthful labels, then corresponding-set defaults, correction/Undo, inline rest, and Minimize/Resume. Preserve program scheduling, workout conflict protection, kg/lb conversion, assisted/weighted bodyweight semantics, timed exercises, dropsets, supersets, guides, alerts, AI safety/approval behavior, Health Connect, and data persistence.

Mockups are conceptual, with illustrative data. Do not hardcode figures or copy images into the app as screens. Several details require interaction design: superset selection controls, substitution after logged sets, persisted onboarding completion without a name, selective coach proposals, historical correction effects, and backup conflict/restore semantics. Read the analysis before choosing behavior. Follow existing components and theme where possible; adapt to real screen sizes, system text scale, keyboard, and safe areas.

Use reviewable implementation slices and tests appropriate to changed behavior. Run applicable analysis/tests/release-readiness checks and summarize device-verification limits honestly. Normal feature work must not bump the release version. Do not publish, merge, or send review comments unless authorized in the new session.

My requested scope for this session: [insert implementation or mockup-refinement request here].

---

## Prior validation context

The earlier fix had 69 targeted storage/backup/readiness tests and 22 SQL-query tests passing, plus relevant static analysis. GitHub CI passed before PR #93 merged. Those results validate the prior fix, not any future UX implementation. This design-only branch needs asset/document validation rather than rerunning the app suite.
