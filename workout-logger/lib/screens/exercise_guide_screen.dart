import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/exercise_guide_cache.dart';
import '../theme/app_theme.dart';
import 'widgets/exercise_demonstration_section.dart';

class ExerciseGuideScreen extends StatelessWidget {
  const ExerciseGuideScreen({super.key, required this.exercise, this.cache});
  final Exercise exercise;
  final ExerciseGuideCache? cache;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exercise guide')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ExerciseDemonstrationSection(
              exercise: exercise,
              cache: cache,
            ),
          ),
        ),
      ),
    ),
  );
}
