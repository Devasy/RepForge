# Mockup inventory

All boards are AI-generated design concepts requested by the user. Values and conversations are illustrative. They are neither production screenshots nor interactive prototypes. The analysis takes precedence over any accidental visual detail or unsupported control shown in a board.

| File | Coverage |
| --- | --- |
| `01-core-flows.png` | Action-focused Home, active workout with inline timer, Train, contextual Coach |
| `02-training-experience.png` | Optional onboarding, exercise navigation/substitution, saved summary, Progress, recovery freshness, backup/restore preview |
| `03-planning-and-control.png` | Routine builder, history correction, coach approval, preferences/accessibility |

The first board is a recreated archival version of the initial concept shown in chat: its original image file was not present in the resumed workspace. Boards two and three preserve the generated files shown to the user. Phone status bars, spacing, sample numbers, and microcopy are not specifications.

Important implementation qualifications:

- Backup handoff is not proof of successful storage; the destination must be checked.
- Restore preview and selective application need real duplicate/conflict semantics first.
- Do not show both an unsaved correction form and a saved confirmation for that same edit at once; the history mockup combines states for illustration.
- Superset grouping needs explicit selected exercise controls, which the builder illustration omits.
- Inline rest and set inputs must remain usable together, including during background/resume.
- Accessibility preferences should respect OS settings; labels and contrast need real verification.
