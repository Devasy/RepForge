# Health Connect exercise and muscle mapping

Target release: `r2.2.3`. The full external-workout import is not implemented yet.
Coach can now create/edit custom exercises with primary and secondary estimated
involvement weights. Those assignments use the existing exercise model, storage,
backup format and analysis paths. Existing write proposals still require review.

## Establish source data before choosing an inference strategy

FitifySync's inspected parser reads `SELECT code, title FROM exercises` and keeps
those values in a code-to-title map. This does **not** establish that the source
catalogue lacks muscle fields: it establishes that the parser does not read them.

The next source-side investigation is a read-only schema inspection of Fitify's
`exercises` table and any related muscle/target tables. Record column names and
relationships, the app/schema version, and representative non-personal catalogue
entries. Check whether fields are primary/secondary muscle labels, broad body
regions, equipment tags, or actual numeric weights; do not conflate them.

If available, FitifySync should preserve original muscle labels/roles alongside
exercise code and title in its versioned Health Connect notes payload. Numeric
weights must carry their original meaning. A primary/secondary label alone is
not evidence of a measured activation percentage. The code and name must map to
the exact exported segment, including its position among rest segments.

## Mapping order for the future importer

1. Reuse a previously resolved `(source package, source exercise code)` mapping.
   Preserve catalogue/schema version information so source changes can be reviewed.
2. Match a specific known RepForge exercise, preserving meaningful movement and
   equipment variants. A generic HC type such as `WEIGHTLIFTING` is insufficient
   to identify a particular push-up variation.
3. When present, translate source muscle labels to RepForge's canonical muscle
   groups, retaining the original labels and their source provenance.
4. For a clearly identified unfamiliar movement, have AI propose an existing
   match or a custom exercise with a primary muscle and relevant secondary muscles.
   If AI supplies numeric weights absent from the source, mark them as estimates.
5. Leave ambiguous identities unresolved, with the raw workout/segments intact.
   Ask for clarification rather than creating a guessed exercise. Missing AI
   access must not lose the source workout or turn missing values into zeros.
6. Persist resolved mappings once so later imports do not repeatedly create the
   same exercise or ask AI to infer its muscles again. Corrections should update
   mappings without duplicating workouts or changing unrelated exercise entries.

## Involvement weights and analysis

The existing catalogue uses independent per-muscle involvement weights. They do
not have to sum to 100. Coach's optional `muscle_activations` argument supplies a
complete list of known muscles with integer weights from 1 to 100. The primary
must be present with the unique highest weight; secondary muscles cannot repeat.
Omitting the list preserves existing assignments on update, or keeps the legacy
single-primary default on creation. Changing a multi-muscle exercise's primary
requires an explicit replacement list so secondary assignments are not discarded.

Show the assignments as estimated involvement. Keep source labels, user edits,
and AI estimates distinguishable when implementing the importer provenance.
Heart-rate correlations must retain any indication that segment boundaries were
reconstructed. Preserve reps versus hold duration; unknown bodyweight resistance
must not become invented tonnage. Training exposure, exercise performance and
estimated involvement are distinct from measured muscle growth.

## Remaining release work

- Confirm which muscle information exists in Fitify's on-device catalogue.
- Agree and implement FitifySync's versioned notes contract and existing-workout
  enrichment without duplication.
- Implement HC workout reads, source staging/deduplication, saved identity maps,
  import review, and workout display/analysis integration in RepForge.
- Verify the complete import and correction flows on a real phone.

The present coach extension is a prerequisite for this workflow, not completion
of these remaining items.
