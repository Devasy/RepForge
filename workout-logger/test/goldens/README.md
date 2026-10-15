# Exercise UI captures

The exercise player, full guide, and catalogue pose gallery have exact pixel
regression tests. Host font rendering differs between Windows and Linux, so
each host has its own reviewed baseline rather than a relaxed comparator.

Regenerate on the matching host after a deliberate visual change:

```sh
flutter test --update-goldens test/exercise_animation_player_test.dart test/exercise_animation_gallery_test.dart test/exercise_guide_screen_visual_test.dart
```

Review the generated images before committing them. CI uploads actual and diff
images as `exercise-visual-failures` when a visual comparison fails.
