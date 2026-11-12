# Optional exercise catalogue

`fitify-v1.json` supplies 937 exercise identities and their resistance/stretch
muscle scores, inspected from Fitify 1.136.0, catalogue database version 43.
It contains no account data, workout history, instructions, images or videos.

RepForge downloads this file only when **Download extended library** is selected.
The validated JSON is cached in local settings and included in existing backups.
The compact built-in library remains the default; 32 conservative source
references are included locally for its muscle details. Existing exercise IDs,
user edits and involvement weights are retained.

## Format

- `schema`: `repforge.exercise_library`; `version`: integer `1`.
- `source`: source name, package, app version and catalogue version.
- `exercises`: unique source `code`, display `name`, `exerciseType`, `resistance`
  and `stretch` maps. Scores must be integers from 1 to 10 with known muscle IDs.
- Empty maps mean unavailable source scores, not measured zero involvement.
- Source `hams` and shoulder labels are translated to RepForge's canonical IDs;
  abs, obliques, forearm flexors/extensors, hip abductors/adductors and the three
  neck regions are kept distinct.

The numbers are source intensity scores, not measured activation percentages or
muscle growth. Stretch scores never become resistance weights. For newly loaded
exercises, resistance scores are converted to the existing relative involvement
weight scale by multiplying by 10; existing exercises keep their weights.
Tied highest source scores remain tied. The source does not provide the app's
binary compound/isolation classification, so new entries use `other`. Entries
with zero source reps default to time-based logging; this is a logging default,
not evidence of a recorded hold duration.

Stable imported IDs use `fitify:<source code>`. The explicit built-in reference
map avoids duplicating 32 known movements; name similarity alone never merges
exercise variants. The full library currently produces 949 entries alongside
the 44 built-ins. The body diagram groups some source regions; numeric lists
retain all scores even where the artwork has no separate outline.

The download URL is the raw file on `r2.2.3`, so it works while the release PR
is still in draft. This catalogue does not implement Health Connect workout
import or repair movement identities missing from old Health Connect records.

Coach creation and updates accept `resistance_intensities` and
`stretch_intensities`, each a complete list of `{muscle, intensity}` pairs using
scores from 1 to 10. Legacy `muscle_activations` remains the resistance weight
representation on a 1–100 scale; do not supply both resistance representations.
All involved muscles can be recorded, and tied top resistance scores are valid.
Omitted datasets are preserved; an empty list clears that dataset. Stretch is
stored independently, included in backups, and never enters resistance load.
User/coach estimates are labelled separately from the Fitify reference scores.
