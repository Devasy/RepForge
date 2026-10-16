# RepForge source function index

Source review snapshot: commit `c10f924` plus the local icon work. The PR retains newer main-branch application changes.

Generated from the current Dart AST on 16 October 2026: 154 library files, 2135 named functions, methods, getters/setters and constructors. Includes private helpers and interface declarations; excludes anonymous closures and implicit constructors. Line numbers refer to the source at generation time. This is a declaration inventory, not proof of runtime behavior. See [the capability analysis](APP_CAPABILITIES_AND_ICON_2026-10-16.md) for the feature and data flow review.

## workout-logger/lib/data/body_figure.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/data/body_geometry.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/data/exercise_animations.dart

| Line | Kind | Declaration |
|---|---|---|
| 41 | constructor | `ExerciseAnimation` |
| 60 | getter | `ExerciseAnimation.isHold` |
| 62 | method | `ExerciseAnimation.forExercise` |

## workout-logger/lib/data/exercise_database.dart

| Line | Kind | Declaration |
|---|---|---|
| 26 | method | `MuscleGroups.getAll` |
| 47 | getter | `MuscleGroups.names` |
| 71 | method | `ExerciseDatabase.getAll` |
| 493 | method | `ExerciseDatabase.getById` |
| 501 | method | `ExerciseDatabase.getByMuscleGroup` |

## workout-logger/lib/data/exercise_demonstrations.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `ExerciseDemonstration` |

## workout-logger/lib/data/exercise_muscle_motion.dart

| Line | Kind | Declaration |
|---|---|---|
| 8 | constructor | `ExerciseMuscleMotion` |
| 13 | method | `ExerciseMuscleMotion.forExercise` |

## workout-logger/lib/genui/a2ui.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/genui/src/a2ui_node.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | constructor | `A2UiNode` |
| 24 | method | `A2UiNode.toString` |

## workout-logger/lib/genui/src/a2ui_panels.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `A2UiPanel` |
| 18 | method | `A2UiPanel.build` |
| 32 | constructor | `A2UiPanelTitle` |
| 43 | method | `A2UiPanelTitle.build` |
| 79 | constructor | `A2UiEmptyPanel` |
| 88 | method | `A2UiEmptyPanel.build` |
| 103 | constructor | `A2UiLegend` |
| 114 | method | `A2UiLegend.build` |

## workout-logger/lib/genui/src/a2ui_parser.dart

| Line | Kind | Declaration |
|---|---|---|
| 13 | constructor | `A2UiParser` |
| 41 | method | `A2UiParser.parse` |
| 53 | method | `A2UiParser.parseJson` |
| 110 | method | `A2UiParser.looksLikeUi` |
| 128 | method | `A2UiParser.stripFences` |
| 151 | method | `A2UiParser._parseChildren` |
| 163 | method | `A2UiParser._declaresChildren` |
| 166 | method | `A2UiParser._firstChildList` |
| 176 | method | `A2UiParser._wrap` |
| 204 | method | `A2UiParser._extractJson` |
| 261 | method | `A2UiParser._findBalancedEnd` |

## workout-logger/lib/genui/src/a2ui_prompt.dart

| Line | Kind | Declaration |
|---|---|---|
| 5 | function | `buildA2UiPromptSection` |
| 56 | function | `_example` |

## workout-logger/lib/genui/src/a2ui_props.dart

| Line | Kind | Declaration |
|---|---|---|
| 8 | constructor | `A2UiProps` |
| 46 | method | `A2UiProps.normalizeKey` |
| 58 | method | `A2UiProps.lookup` |
| 81 | method | `A2UiProps.textOrNull` |
| 89 | method | `A2UiProps.text` |
| 91 | method | `A2UiProps.numberOrNull` |
| 93 | method | `A2UiProps.number` |
| 95 | method | `A2UiProps.integer` |
| 97 | method | `A2UiProps.stringList` |
| 106 | method | `A2UiProps.numberList` |
| 115 | method | `A2UiProps.objectList` |
| 124 | method | `A2UiProps.stringKeyed` |
| 129 | method | `A2UiProps._toNumber` |

## workout-logger/lib/genui/src/a2ui_registry.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `A2UiRegistry` |
| 21 | method | `A2UiRegistry._register` |
| 47 | getter | `A2UiRegistry.specs` |
| 49 | method | `A2UiRegistry.specFor` |
| 54 | method | `A2UiRegistry.canonicalName` |
| 62 | constructor | `A2UiRegistryProvider` |
| 70 | method | `A2UiRegistryProvider.of` |
| 76 | method | `A2UiRegistryProvider.updateShouldNotify` |

## workout-logger/lib/genui/src/a2ui_renderer.dart

| Line | Kind | Declaration |
|---|---|---|
| 20 | constructor | `A2UiRenderer` |
| 27 | method | `A2UiRenderer.build` |

## workout-logger/lib/genui/src/a2ui_series.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `A2UiSeries` |
| 14 | method | `A2UiSeries.extract` |
| 45 | method | `A2UiSeries.maxValue` |
| 56 | method | `A2UiSeries.minValue` |

## workout-logger/lib/genui/src/a2ui_spec.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `A2UiDoc` |
| 36 | constructor | `A2UiSpec` |
| 38 | getter | `A2UiSpec.name` |
| 41 | getter | `A2UiSpec.aliases` |
| 45 | getter | `A2UiSpec.doc` |
| 47 | method | `A2UiSpec.parseProps` |
| 62 | method | `A2UiSpec.buildWidget` |
| 64 | method | `A2UiSpec.render` |

## workout-logger/lib/genui/src/a2ui_theme.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `A2UiTheme` |
| 41 | method | `A2UiTheme.seriesColor` |
| 82 | constructor | `A2UiThemeProvider` |
| 90 | method | `A2UiThemeProvider.of` |
| 96 | method | `A2UiThemeProvider.updateShouldNotify` |

## workout-logger/lib/genui/src/components/data_list_group.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | constructor | `A2UiListRow` |
| 24 | constructor | `DataListGroupProps` |
| 30 | getter | `DataListGroupProps.hasData` |
| 35 | constructor | `DataListGroupSpec` |
| 37 | getter | `DataListGroupSpec.name` |
| 40 | getter | `DataListGroupSpec.aliases` |
| 43 | getter | `DataListGroupSpec.doc` |
| 70 | method | `DataListGroupSpec.parseProps` |
| 90 | method | `DataListGroupSpec._row` |
| 132 | method | `DataListGroupSpec.buildWidget` |
| 177 | constructor | `_Row` |
| 187 | method | `_Row.build` |

## workout-logger/lib/genui/src/components/dynamic_chart.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | method | `A2UiChartType.parse` |
| 31 | constructor | `DynamicChartProps` |
| 48 | getter | `DynamicChartProps.hasData` |
| 53 | constructor | `DynamicChartSpec` |
| 55 | getter | `DynamicChartSpec.name` |
| 58 | getter | `DynamicChartSpec.aliases` |
| 67 | getter | `DynamicChartSpec.doc` |
| 89 | method | `DynamicChartSpec.parseProps` |
| 116 | method | `DynamicChartSpec.buildWidget` |
| 164 | method | `DynamicChartSpec._line` |
| 194 | method | `DynamicChartSpec._bar` |
| 223 | method | `DynamicChartSpec._pie` |
| 308 | function | `_yBounds` |
| 332 | function | `a2uiGridData` |
| 340 | function | `a2uiTitlesData` |

## workout-logger/lib/genui/src/components/filter_chips.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `FilterChipsProps` |
| 17 | getter | `FilterChipsProps.hasData` |
| 26 | constructor | `FilterChipsSpec` |
| 28 | getter | `FilterChipsSpec.name` |
| 31 | getter | `FilterChipsSpec.aliases` |
| 34 | getter | `FilterChipsSpec.doc` |
| 49 | method | `FilterChipsSpec.parseProps` |
| 68 | method | `FilterChipsSpec.buildWidget` |
| 96 | constructor | `_Chip` |
| 106 | method | `_Chip.build` |

## workout-logger/lib/genui/src/components/grid_container.dart

| Line | Kind | Declaration |
|---|---|---|
| 10 | constructor | `GridContainerProps` |
| 23 | constructor | `GridContainerSpec` |
| 28 | getter | `GridContainerSpec.name` |
| 31 | getter | `GridContainerSpec.aliases` |
| 34 | getter | `GridContainerSpec.doc` |
| 58 | method | `GridContainerSpec.parseProps` |
| 64 | method | `GridContainerSpec.buildWidget` |

## workout-logger/lib/genui/src/components/metric_gauge.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `MetricGaugeProps` |
| 31 | getter | `MetricGaugeProps.progress` |
| 46 | constructor | `MetricGaugeSpec` |
| 48 | getter | `MetricGaugeSpec.name` |
| 51 | getter | `MetricGaugeSpec.aliases` |
| 54 | getter | `MetricGaugeSpec.doc` |
| 74 | method | `MetricGaugeSpec.parseProps` |
| 88 | method | `MetricGaugeSpec.buildWidget` |
| 179 | constructor | `_GaugeArcPainter` |
| 194 | method | `_GaugeArcPainter.paint` |
| 217 | method | `_GaugeArcPainter.shouldRepaint` |

## workout-logger/lib/genui/src/components/radar_chart.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `RadarChartProps` |
| 25 | getter | `RadarChartProps.hasData` |
| 31 | constructor | `RadarChartSpec` |
| 33 | getter | `RadarChartSpec.name` |
| 36 | getter | `RadarChartSpec.aliases` |
| 39 | getter | `RadarChartSpec.doc` |
| 59 | method | `RadarChartSpec.parseProps` |
| 85 | method | `RadarChartSpec.buildWidget` |

## workout-logger/lib/genui/src/components/scatter_plot.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | constructor | `A2UiPoint` |
| 18 | constructor | `ScatterPlotProps` |
| 32 | getter | `ScatterPlotProps.hasData` |
| 34 | getter | `ScatterPlotProps.bounds` |
| 61 | constructor | `ScatterPlotSpec` |
| 63 | getter | `ScatterPlotSpec.name` |
| 66 | getter | `ScatterPlotSpec.aliases` |
| 69 | getter | `ScatterPlotSpec.doc` |
| 92 | method | `ScatterPlotSpec.parseProps` |
| 112 | method | `ScatterPlotSpec.buildWidget` |

## workout-logger/lib/genui/src/components/stat_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | method | `A2UiTrend.parse` |
| 41 | constructor | `StatCardProps` |
| 56 | constructor | `StatCardSpec` |
| 58 | getter | `StatCardSpec.name` |
| 61 | getter | `StatCardSpec.aliases` |
| 64 | getter | `StatCardSpec.doc` |
| 81 | method | `StatCardSpec.parseProps` |
| 111 | method | `StatCardSpec.buildWidget` |

## workout-logger/lib/genui/src/default_registry.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/main.dart

| Line | Kind | Declaration |
|---|---|---|
| 49 | function | `_resolveStorageBackend` |
| 92 | function | `main` |
| 183 | constructor | `WorkoutLoggerApp` |
| 185 | method | `WorkoutLoggerApp.build` |
| 264 | constructor | `AppInitializer` |
| 266 | method | `AppInitializer.createState` |
| 279 | method | `_AppInitializerState.initState` |
| 285 | method | `_AppInitializerState._initializeApp` |
| 359 | method | `_AppInitializerState._finishUpgrade` |
| 378 | method | `_AppInitializerState.build` |

## workout-logger/lib/models/app_release.dart

| Line | Kind | Declaration |
|---|---|---|
| 1 | function | `normalizeInstalledVersion` |
| 6 | function | `compareAppVersions` |
| 8 | function | `parse` |
| 27 | constructor | `AppRelease` |
| 37 | getter | `AppRelease.changeCount` |
| 42 | constructor | `ReleaseChangeGroup` |

## workout-logger/lib/models/models.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `MuscleGroup` |
| 28 | method | `MuscleGroup.toJson` |
| 35 | constructor | `MuscleGroup.fromJson` |
| 49 | constructor | `MuscleActivation` |
| 54 | method | `MuscleActivation.toJson` |
| 59 | constructor | `MuscleActivation.fromJson` |
| 77 | function | `isAssistedBodyweightExercise` |
| 80 | function | `isBodyweightExercise` |
| 90 | getter | `ExerciseType.displayName` |
| 110 | constructor | `Exercise` |
| 120 | method | `Exercise.copyWith` |
| 138 | getter | `Exercise.primaryMuscle` |
| 146 | method | `Exercise.toJson` |
| 156 | constructor | `Exercise.fromJson` |
| 185 | function | `formatHoldDuration` |
| 210 | constructor | `WorkoutSet` |
| 240 | getter | `WorkoutSet.effectiveWeight` |
| 252 | getter | `WorkoutSet.loadConvention` |
| 256 | method | `WorkoutSet.hasComparableLoad` |
| 259 | method | `WorkoutSet.effectiveLoad` |
| 268 | method | `WorkoutSet.toEffectiveLoad` |
| 287 | method | `WorkoutSet.calculateVolume` |
| 289 | function | `load` |
| 312 | getter | `WorkoutSet.volume` |
| 314 | getter | `WorkoutSet.isTimeBased` |
| 317 | getter | `WorkoutSet.formattedDuration` |
| 320 | method | `WorkoutSet.toJson` |
| 335 | constructor | `WorkoutSet.fromJson` |
| 354 | method | `WorkoutSet.copyWith` |
| 394 | constructor | `DropsetEntry` |
| 397 | method | `DropsetEntry.toJson` |
| 399 | constructor | `DropsetEntry.fromJson` |
| 414 | constructor | `ExerciseLog` |
| 421 | method | `ExerciseLog.calculateTotalVolume` |
| 432 | getter | `ExerciseLog.totalVolume` |
| 434 | getter | `ExerciseLog.totalHoldDuration` |
| 438 | getter | `ExerciseLog.isTimeBased` |
| 441 | method | `ExerciseLog.toJson` |
| 448 | constructor | `ExerciseLog.fromJson` |
| 455 | method | `ExerciseLog.copyWith` |
| 488 | constructor | `WorkoutSession` |
| 499 | getter | `WorkoutSession.totalVolume` |
| 502 | method | `WorkoutSession.toJson` |
| 513 | constructor | `WorkoutSession.fromJson` |
| 528 | method | `WorkoutSession.copyWith` |
| 566 | constructor | `Routine` |
| 574 | method | `Routine.toJson` |
| 582 | constructor | `Routine.fromJson` |
| 590 | method | `Routine.copyWith` |
| 619 | constructor | `Target` |
| 630 | getter | `Target.progressPercentage` |
| 633 | method | `Target.toJson` |
| 644 | constructor | `Target.fromJson` |
| 668 | constructor | `SetRecommendation` |
| 698 | constructor | `EffortEstimate` |
| 733 | constructor | `GrowthModel` |
| 744 | method | `GrowthModel.predict` |
| 753 | getter | `GrowthModel.currentEstimate` |
| 756 | getter | `GrowthModel.weeklyGrowthPercent` |
| 777 | constructor | `PersonalRecord` |
| 793 | getter | `PersonalRecord.storageKey` |
| 796 | method | `PersonalRecord.toJson` |
| 806 | constructor | `PersonalRecord.fromJson` |
| 816 | method | `PersonalRecord.copyWith` |
| 833 | method | `PersonalRecord.aggregate` |
| 874 | constructor | `ProgramExerciseSlot` |
| 886 | method | `ProgramExerciseSlot.toJson` |
| 898 | constructor | `ProgramExerciseSlot.fromJson` |
| 911 | method | `ProgramExerciseSlot.copyWith` |
| 950 | constructor | `ProgramDay` |
| 958 | method | `ProgramDay.toJson` |
| 966 | constructor | `ProgramDay.fromJson` |
| 976 | method | `ProgramDay.copyWith` |
| 1007 | constructor | `ProgramWeek` |
| 1017 | method | `ProgramWeek.toJson` |
| 1027 | constructor | `ProgramWeek.fromJson` |
| 1040 | method | `ProgramWeek.copyWith` |
| 1072 | constructor | `TrainingPhase` |
| 1081 | method | `TrainingPhase.toJson` |
| 1090 | constructor | `TrainingPhase.fromJson` |
| 1099 | method | `TrainingPhase.copyWith` |
| 1131 | constructor | `TrainingProgram` |
| 1143 | method | `TrainingProgram.phaseForWeek` |
| 1153 | getter | `TrainingProgram.totalDays` |
| 1156 | method | `TrainingProgram.toJson` |
| 1168 | constructor | `TrainingProgram.fromJson` |
| 1187 | method | `TrainingProgram.copyWith` |
| 1226 | constructor | `ChatMessage` |
| 1237 | method | `ChatMessage.toJson` |
| 1247 | constructor | `ChatMessage.fromJson` |
| 1257 | method | `ChatMessage.copyWith` |
| 1290 | constructor | `Conversation` |
| 1302 | method | `Conversation.toJson` |
| 1311 | constructor | `Conversation.fromJson` |
| 1324 | method | `Conversation.copyWith` |
| 1351 | constructor | `QuestionSpec` |
| 1358 | constructor | `QuestionSpec.fromJson` |
| 1372 | constructor | `AnswerSpec` |
| 1378 | method | `AnswerSpec.toJson` |
| 1390 | constructor | `PendingQuestions` |
| 1392 | constructor | `PendingQuestions.fromJson` |
| 1410 | constructor | `HealthSample` |
| 1421 | constructor | `SleepStageInterval` |
| 1454 | constructor | `SleepPeriod` |
| 1464 | getter | `SleepPeriod.hasStages` |
| 1467 | getter | `SleepPeriod.minutes` |
| 1485 | constructor | `ReadinessBaseline` |
| 1495 | method | `ReadinessBaseline.toJson` |
| 1505 | constructor | `ReadinessBaseline.fromJson` |
| 1537 | constructor | `ReadinessSnapshot` |
| 1553 | method | `ReadinessSnapshot.toJson` |
| 1569 | constructor | `ReadinessSnapshot.fromJson` |

## workout-logger/lib/models/sleep_hr_models.dart

| Line | Kind | Declaration |
|---|---|---|
| 23 | constructor | `SleepHrSegment` |
| 43 | constructor | `SleepStageStats` |
| 72 | constructor | `SleepHrSnapshot` |
| 81 | method | `SleepHrSnapshot.statsFor` |
| 96 | getter | `HealthGranularityX.label` |
| 112 | constructor | `HrBucket` |
| 119 | method | `HrBucket.toJson` |
| 126 | constructor | `HrBucket.fromJson` |
| 148 | constructor | `HrDaySnapshot` |
| 157 | method | `HrDaySnapshot.toJson` |
| 166 | constructor | `HrDaySnapshot.fromJson` |
| 187 | constructor | `SleepDayBar` |
| 206 | constructor | `HrRangeBar` |

## workout-logger/lib/models/workout_hr_models.dart

| Line | Kind | Declaration |
|---|---|---|
| 10 | constructor | `HrCurvePoint` |
| 32 | constructor | `RestRecovery` |
| 51 | constructor | `ExerciseHrSpan` |
| 82 | constructor | `WorkoutHrAnalysis` |
| 94 | getter | `WorkoutHrAnalysis.restsRecovered` |
| 95 | getter | `WorkoutHrAnalysis.restCount` |
| 97 | getter | `WorkoutHrAnalysis.avgRecoveryBpm` |
| 104 | getter | `WorkoutHrAnalysis.restsTooShort` |

## workout-logger/lib/screens/add_custom_exercise_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `AddCustomExerciseScreen` |
| 18 | method | `AddCustomExerciseScreen.createState` |
| 34 | getter | `_AddCustomExerciseScreenState._isEditing` |
| 36 | method | `_AddCustomExerciseScreenState.initState` |
| 49 | method | `_AddCustomExerciseScreenState.dispose` |
| 56 | method | `_AddCustomExerciseScreenState._addHandle` |
| 69 | method | `_AddCustomExerciseScreenState._save` |
| 138 | method | `_AddCustomExerciseScreenState.build` |
| 471 | method | `_AddCustomExerciseScreenState._label` |
| 486 | constructor | `_CategoryTile` |
| 500 | method | `_CategoryTile.build` |
| 554 | constructor | `_MuscleGrid` |
| 558 | method | `_MuscleGrid.build` |

## workout-logger/lib/screens/ai_coach_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 30 | constructor | `AiCoachScreen` |
| 35 | method | `AiCoachScreen.build` |
| 50 | constructor | `_AiCoachView` |
| 53 | method | `_AiCoachView.createState` |
| 62 | method | `_AiCoachViewState.initState` |
| 77 | method | `_AiCoachViewState.didChangeDependencies` |
| 88 | method | `_AiCoachViewState._onVmChanged` |
| 90 | method | `_AiCoachViewState.dispose` |
| 98 | method | `_AiCoachViewState._send` |
| 107 | method | `_AiCoachViewState._scrollToBottom` |
| 119 | method | `_AiCoachViewState.build` |
| 159 | method | `_AiCoachViewState._buildHeader` |
| 182 | method | `_AiCoachViewState._openHistory` |
| 195 | method | `_AiCoachViewState._buildChatArea` |
| 223 | method | `_AiCoachViewState._buildWelcome` |
| 288 | method | `_AiCoachViewState._buildNoKeyState` |
| 317 | method | `_AiCoachViewState._buildInputBar` |
| 464 | constructor | `_SendButton` |
| 474 | method | `_SendButton.build` |
| 537 | constructor | `_ConversationsSheet` |
| 540 | method | `_ConversationsSheet.build` |
| 643 | constructor | `_ConversationTile` |
| 655 | method | `_ConversationTile.build` |
| 717 | constructor | `_MessageBubble` |
| 720 | method | `_MessageBubble.build` |
| 778 | constructor | `_StreamingBubble` |
| 782 | method | `_StreamingBubble.build` |
| 802 | constructor | `_Turn` |
| 816 | method | `_Turn.build` |
| 912 | constructor | `_ToolCallChips` |
| 919 | getter | `_ToolCallChips._unique` |
| 921 | method | `_ToolCallChips._label` |
| 926 | method | `_ToolCallChips.build` |
| 975 | constructor | `CoachMessageContent` |
| 988 | method | `CoachMessageContent.nodeFor` |
| 996 | method | `CoachMessageContent.rendersAsDashboard` |
| 999 | method | `CoachMessageContent.looksLikeUi` |
| 1008 | method | `CoachMessageContent.createState` |
| 1013 | method | `_CoachMessageContentState.build` |
| 1047 | constructor | `_CoachMarkdown` |
| 1050 | method | `_CoachMarkdown.build` |
| 1065 | constructor | `_AiAvatar` |
| 1067 | method | `_AiAvatar.build` |

## workout-logger/lib/screens/ai_program_generator_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | constructor | `AiProgramGeneratorScreen` |
| 17 | method | `AiProgramGeneratorScreen.createState` |
| 37 | method | `_AiProgramGeneratorScreenState.dispose` |
| 43 | method | `_AiProgramGeneratorScreenState._generate` |
| 90 | method | `_AiProgramGeneratorScreenState._saveProgram` |
| 106 | method | `_AiProgramGeneratorScreenState.build` |
| 141 | method | `_AiProgramGeneratorScreenState._buildHeader` |
| 220 | method | `_AiProgramGeneratorScreenState._buildPromptCard` |
| 322 | method | `_AiProgramGeneratorScreenState._buildGeneratingState` |
| 359 | method | `_AiProgramGeneratorScreenState._buildError` |
| 380 | method | `_AiProgramGeneratorScreenState._buildPreview` |

## workout-logger/lib/screens/analytics_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 18 | constructor | `AnalyticsScreen` |
| 20 | method | `AnalyticsScreen.createState` |
| 29 | method | `_AnalyticsScreenState.build` |
| 48 | method | `_AnalyticsScreenState._buildHeader` |
| 87 | method | `_AnalyticsScreenState._buildPillTabBar` |
| 138 | method | `_AnalyticsScreenState._buildTabView` |
| 161 | constructor | `_RecordsTab` |
| 163 | method | `_RecordsTab.createState` |
| 171 | method | `_RecordsTabState.build` |
| 426 | constructor | `_NewestPRHero` |
| 430 | method | `_NewestPRHero.build` |
| 532 | constructor | `_ExercisePRGroup` |
| 536 | method | `_ExercisePRGroup.build` |
| 570 | constructor | `_FilterChip` |
| 579 | method | `_FilterChip.build` |
| 612 | constructor | `_PRCard` |
| 617 | method | `_PRCard.build` |
| 714 | constructor | `_PRStat` |
| 724 | method | `_PRStat.build` |

## workout-logger/lib/screens/edit_workout_session_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `EditWorkoutSessionScreen` |
| 19 | method | `EditWorkoutSessionScreen.createState` |
| 33 | method | `_EditWorkoutSessionScreenState.initState` |
| 62 | method | `_EditWorkoutSessionScreenState.dispose` |
| 69 | method | `_EditWorkoutSessionScreenState._markChanged` |
| 73 | method | `_EditWorkoutSessionScreenState._selectDate` |
| 101 | method | `_EditWorkoutSessionScreenState._selectTime` |
| 130 | method | `_EditWorkoutSessionScreenState._addSet` |
| 144 | method | `_EditWorkoutSessionScreenState._deleteSet` |
| 149 | method | `_EditWorkoutSessionScreenState._deleteExercise` |
| 154 | method | `_EditWorkoutSessionScreenState._save` |
| 208 | method | `_EditWorkoutSessionScreenState._onWillPop` |
| 220 | method | `_EditWorkoutSessionScreenState._snack` |
| 227 | method | `_EditWorkoutSessionScreenState.build` |
| 390 | method | `_EditWorkoutSessionScreenState._sectionLabel` |
| 410 | constructor | `_SectionCard` |
| 413 | method | `_SectionCard.build` |
| 429 | constructor | `_TapField` |
| 438 | method | `_TapField.build` |
| 478 | constructor | `_StyledField` |
| 494 | method | `_StyledField.build` |

## workout-logger/lib/screens/exercise_guide_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `ExerciseGuideScreen` |
| 13 | method | `ExerciseGuideScreen.build` |

## workout-logger/lib/screens/exercise_library_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `ExerciseLibraryScreen` |
| 18 | method | `ExerciseLibraryScreen.createState` |
| 26 | method | `_ExerciseLibraryScreenState.build` |
| 108 | method | `_ExerciseLibraryScreenState._openDetails` |
| 130 | constructor | `_Header` |
| 133 | method | `_Header.build` |
| 181 | constructor | `_SearchBar` |
| 185 | method | `_SearchBar.build` |
| 234 | constructor | `_MuscleFilterChips` |
| 238 | method | `_MuscleFilterChips.build` |
| 272 | constructor | `_Chip` |
| 283 | method | `_Chip.build` |
| 313 | constructor | `_MuscleGroup` |
| 322 | method | `_MuscleGroup.build` |
| 377 | constructor | `ExerciseSelectorScreen` |
| 386 | method | `ExerciseSelectorScreen.createState` |
| 395 | method | `_ExerciseSelectorScreenState.build` |

## workout-logger/lib/screens/heart_rate_detail_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | constructor | `HeartRateDetailScreen` |
| 23 | method | `HeartRateDetailScreen.createState` |
| 34 | method | `_HeartRateDetailScreenState.initState` |
| 43 | method | `_HeartRateDetailScreenState.didChangeDependencies` |
| 50 | method | `_HeartRateDetailScreenState._load` |
| 54 | getter | `_HeartRateDetailScreenState._canGoNext` |
| 60 | method | `_HeartRateDetailScreenState._step` |
| 65 | method | `_HeartRateDetailScreenState._setG` |
| 70 | getter | `_HeartRateDetailScreenState._dateLabel` |
| 84 | method | `_HeartRateDetailScreenState.build` |
| 116 | constructor | `_DayBody` |
| 119 | method | `_DayBody.build` |
| 168 | method | `_DayBody._legend` |
| 177 | method | `_DayBody._legendDash` |
| 188 | constructor | `_AggBody` |
| 194 | method | `_AggBody.build` |
| 243 | method | `_AggBody._legend` |
| 254 | constructor | `_Pill` |
| 259 | method | `_Pill.build` |
| 289 | constructor | `_Empty` |
| 291 | method | `_Empty.build` |

## workout-logger/lib/screens/history_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 20 | constructor | `HistoryScreen` |
| 22 | method | `HistoryScreen.createState` |
| 35 | method | `_HistoryScreenState.dispose` |
| 41 | method | `_HistoryScreenState._filtered` |
| 54 | method | `_HistoryScreenState._group` |
| 63 | method | `_HistoryScreenState._buildCalendarData` |
| 79 | method | `_HistoryScreenState.build` |
| 177 | method | `_HistoryScreenState._buildHeader` |
| 265 | method | `_HistoryScreenState._buildSummaryCard` |
| 292 | method | `_HistoryScreenState._buildCalendarCard` |
| 377 | constructor | `_SummaryCell` |
| 382 | method | `_SummaryCell.build` |
| 416 | constructor | `_VertDivider` |
| 418 | method | `_VertDivider.build` |
| 427 | constructor | `_SearchBar` |
| 431 | method | `_SearchBar.build` |
| 460 | constructor | `_MonthGroup` |
| 473 | method | `_MonthGroup.build` |
| 516 | constructor | `_HistoryCard` |
| 528 | method | `_HistoryCard._openDetails` |
| 560 | method | `_HistoryCard._confirmDelete` |
| 602 | method | `_HistoryCard._handleMenu` |
| 615 | method | `_HistoryCard.build` |
| 723 | method | `_HistoryCard._menuItem` |
| 739 | function | `_snackBar` |

## workout-logger/lib/screens/home_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 33 | constructor | `HomeScreen` |
| 35 | method | `HomeScreen.createState` |
| 49 | method | `_HomeScreenState.switchTab` |
| 51 | method | `_HomeScreenState.build` |
| 83 | method | `_HomeScreenState._resolveConflict` |
| 94 | method | `_HomeScreenState._resumeWorkout` |
| 98 | method | `_HomeScreenState._startQuickWorkout` |
| 117 | method | `_HomeScreenState.startRoutineWorkout` |
| 136 | method | `_HomeScreenState._showRoutineSelector` |
| 162 | constructor | `_DashboardTab` |
| 164 | method | `_DashboardTab._greeting` |
| 172 | method | `_DashboardTab._buildHeatmapData` |
| 190 | method | `_DashboardTab.build` |
| 249 | method | `_DashboardTab._buildHeader` |
| 348 | method | `_DashboardTab._buildStreakHero` |
| 587 | method | `_DashboardTab._buildStatsGrid` |
| 689 | method | `_DashboardTab._buildHeatmapCard` |
| 724 | method | `_DashboardTab._buildMuscleVolumeCard` |
| 865 | method | `_DashboardTab._buildRecentWorkouts` |
| 999 | method | `_DashboardTab._formatSessionDate` |
| 1008 | method | `_DashboardTab._capitalize` |
| 1015 | constructor | `_StatItem` |
| 1030 | constructor | `_StatCard` |
| 1033 | method | `_StatCard.build` |
| 1093 | constructor | `_RoutineSelectorSheet` |
| 1103 | method | `_RoutineSelectorSheet.build` |
| 1200 | function | `_slide` |
| 1205 | constructor | `_WeeklyInsightsCard` |
| 1207 | method | `_WeeklyInsightsCard.createState` |
| 1214 | method | `_WeeklyInsightsCardState._refresh` |
| 1256 | method | `_WeeklyInsightsCardState.build` |

## workout-logger/lib/screens/onboarding_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `WelcomePage` |
| 25 | method | `WelcomePage.createState` |
| 34 | method | `_WelcomePageState.dispose` |
| 40 | method | `_WelcomePageState._submit` |
| 63 | method | `_WelcomePageState.build` |
| 207 | constructor | `GenderSetupPage` |
| 210 | method | `GenderSetupPage.createState` |
| 217 | method | `_GenderSetupPageState._select` |
| 233 | method | `_GenderSetupPageState.build` |
| 259 | function | `showVersionUpdateSheet` |
| 278 | constructor | `_VersionUpdateSheet` |
| 288 | method | `_VersionUpdateSheet.build` |

## workout-logger/lib/screens/profile_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 29 | constructor | `ProfileScreen` |
| 33 | method | `ProfileScreen.createState` |
| 43 | method | `_ProfileScreenState._downloadAllGuides` |
| 78 | method | `_ProfileScreenState.initState` |
| 90 | method | `_ProfileScreenState.dispose` |
| 96 | method | `_ProfileScreenState.didChangeAppLifecycleState` |
| 103 | method | `_ProfileScreenState._reconcileHealthConnectState` |
| 134 | method | `_ProfileScreenState._requestHealthConnectPermission` |
| 178 | method | `_ProfileScreenState._requestReadinessPermission` |
| 238 | method | `_ProfileScreenState._syncHealthDataNow` |
| 257 | method | `_ProfileScreenState._exportToFile` |
| 284 | method | `_ProfileScreenState._importFromFile` |
| 371 | function | `count` |
| 390 | method | `_ProfileScreenState._showSnack` |
| 406 | method | `_ProfileScreenState.build` |
| 489 | method | `_ProfileScreenState._buildHero` |

## workout-logger/lib/screens/programs/import_program_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 25 | constructor | `ImportProgramScreen` |
| 27 | method | `ImportProgramScreen.createState` |
| 39 | method | `_ImportProgramScreenState.dispose` |
| 48 | method | `_ImportProgramScreenState.build` |
| 81 | method | `_ImportProgramScreenState._buildInstructions` |
| 101 | method | `_ImportProgramScreenState._buildTextField` |
| 158 | getter | `_ImportProgramScreenState._borderColor` |
| 171 | method | `_ImportProgramScreenState._buildStatusBar` |
| 227 | method | `_ImportProgramScreenState._buildActionBar` |
| 267 | method | `_ImportProgramScreenState._pickFile` |
| 296 | method | `_ImportProgramScreenState._clearField` |
| 305 | method | `_ImportProgramScreenState._validate` |
| 348 | method | `_ImportProgramScreenState._requireField` |
| 363 | method | `_ImportProgramScreenState._import` |
| 386 | method | `_ImportProgramScreenState._shortError` |

## workout-logger/lib/screens/programs/program_designer_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | constructor | `ProgramDesignerScreen` |
| 21 | method | `ProgramDesignerScreen.createState` |
| 42 | method | `_ProgramDesignerScreenState.initState` |
| 58 | method | `_ProgramDesignerScreenState.dispose` |
| 68 | method | `_ProgramDesignerScreenState.build` |
| 95 | method | `_ProgramDesignerScreenState._buildNavBar` |
| 127 | method | `_ProgramDesignerScreenState._buildStep1` |
| 174 | method | `_ProgramDesignerScreenState._buildPhaseChip` |
| 190 | method | `_ProgramDesignerScreenState._addPhase` |
| 191 | method | `_ProgramDesignerScreenState._editPhase` |
| 193 | method | `_ProgramDesignerScreenState._showPhaseDialog` |
| 279 | method | `_ProgramDesignerScreenState._buildStep2` |
| 293 | method | `_ProgramDesignerScreenState._buildWeekEditor` |
| 387 | method | `_ProgramDesignerScreenState._buildDayChip` |
| 408 | method | `_ProgramDesignerScreenState._addDay` |
| 477 | method | `_ProgramDesignerScreenState._buildStep3` |
| 506 | method | `_ProgramDesignerScreenState._buildDayExerciseEditor` |
| 556 | method | `_ProgramDesignerScreenState._buildSlotEditor` |
| 600 | method | `_ProgramDesignerScreenState._addExerciseSlot` |
| 604 | method | `_ProgramDesignerScreenState._editSlot` |
| 614 | method | `_ProgramDesignerScreenState._showSlotDialog` |
| 777 | method | `_ProgramDesignerScreenState._updateDayExercises` |
| 789 | method | `_ProgramDesignerScreenState._nextStep` |
| 802 | method | `_ProgramDesignerScreenState._rebuildWeeks` |
| 830 | method | `_ProgramDesignerScreenState._save` |
| 899 | method | `_ProgramDesignerScreenState._validatePhases` |
| 923 | method | `_ProgramDesignerScreenState._field` |
| 942 | constructor | `_SectionHeader` |
| 944 | method | `_SectionHeader.build` |
| 967 | constructor | `_NumberStepper` |
| 976 | method | `_NumberStepper.build` |

## workout-logger/lib/screens/programs/program_detail_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | constructor | `ProgramDetailScreen` |
| 18 | method | `ProgramDetailScreen.createState` |
| 25 | method | `_ProgramDetailScreenState.initState` |
| 31 | method | `_ProgramDetailScreenState.build` |
| 111 | method | `_ProgramDetailScreenState._startProgramDayWorkout` |
| 149 | method | `_ProgramDetailScreenState._buildHeader` |
| 217 | method | `_ProgramDetailScreenState._statChip` |
| 248 | method | `_ProgramDetailScreenState._buildPhaseTimeline` |
| 335 | method | `_ProgramDetailScreenState._handleMenuAction` |
| 346 | method | `_ProgramDetailScreenState._exportProgram` |
| 409 | method | `_ProgramDetailScreenState._confirmDelete` |

## workout-logger/lib/screens/programs/programs_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `ProgramsScreen` |
| 18 | method | `ProgramsScreen.build` |
| 81 | method | `ProgramsScreen._buildEmptyState` |
| 115 | method | `ProgramsScreen._buildList` |
| 129 | method | `ProgramsScreen._openDesigner` |
| 138 | method | `ProgramsScreen._openAiGenerator` |
| 160 | method | `ProgramsScreen._openImport` |
| 185 | constructor | `_ProgramCard` |
| 196 | method | `_ProgramCard.build` |
| 299 | method | `_ProgramCard._buildMiniTimeline` |
| 324 | method | `_ProgramCard._badge` |

## workout-logger/lib/screens/routine_optimizer_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 25 | constructor | `RoutineOptimizerScreen` |
| 29 | method | `RoutineOptimizerScreen.testBody` |
| 34 | method | `RoutineOptimizerScreen.build` |
| 58 | constructor | `_OptimizerView` |
| 61 | method | `_OptimizerView.createState` |
| 69 | method | `_OptimizerViewState.didChangeDependencies` |
| 79 | method | `_OptimizerViewState._onVmChanged` |
| 81 | method | `_OptimizerViewState._scrollToBottom` |
| 93 | method | `_OptimizerViewState.dispose` |
| 100 | method | `_OptimizerViewState.build` |
| 122 | method | `_OptimizerViewState._buildHeader` |
| 211 | method | `_OptimizerViewState._openHistory` |
| 227 | method | `_OptimizerViewState._buildChatArea` |
| 260 | method | `_OptimizerViewState._buildEmpty` |
| 321 | constructor | `_HeaderIconButton` |
| 325 | method | `_HeaderIconButton.build` |
| 345 | constructor | `_MessageBubble` |
| 348 | method | `_MessageBubble.build` |
| 415 | constructor | `_StreamingBubble` |
| 418 | method | `_StreamingBubble.build` |
| 456 | constructor | `_OptimizerMarkdown` |
| 459 | method | `_OptimizerMarkdown.build` |
| 473 | method | `_OptimizerAvatar.build` |
| 501 | constructor | `_ConversationsSheet` |
| 504 | method | `_ConversationsSheet.build` |
| 572 | constructor | `_ConversationTile` |
| 584 | method | `_ConversationTile.build` |

## workout-logger/lib/screens/routines_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `RoutinesScreen` |
| 18 | method | `RoutinesScreen.build` |
| 57 | method | `RoutinesScreen._buildHeader` |
| 120 | method | `RoutinesScreen._buildQuickStartCard` |
| 255 | method | `RoutinesScreen._buildAllRoutinesHeader` |
| 288 | method | `RoutinesScreen._buildEmptyState` |
| 324 | method | `RoutinesScreen._buildProgramsSection` |
| 393 | method | `RoutinesScreen._buildNewRoutineButton` |
| 427 | method | `RoutinesScreen._openCreate` |
| 438 | constructor | `_RoutineCard` |
| 443 | method | `_RoutineCard.build` |

## workout-logger/lib/screens/sleep_detail_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `SleepDetailScreen` |
| 25 | method | `SleepDetailScreen.createState` |
| 36 | method | `_SleepDetailScreenState.initState` |
| 45 | method | `_SleepDetailScreenState.didChangeDependencies` |
| 52 | method | `_SleepDetailScreenState._load` |
| 56 | getter | `_SleepDetailScreenState._canGoNext` |
| 62 | method | `_SleepDetailScreenState._step` |
| 69 | method | `_SleepDetailScreenState._setG` |
| 76 | getter | `_SleepDetailScreenState._dateLabel` |
| 91 | method | `_SleepDetailScreenState.build` |
| 123 | constructor | `_DayBody` |
| 126 | method | `_DayBody._ist` |
| 127 | method | `_DayBody._fmt` |
| 133 | method | `_DayBody.build` |
| 153 | constructor | `_AggBody` |
| 163 | method | `_AggBody.build` |
| 213 | method | `_AggBody._legend` |
| 226 | method | `_AggBody._legendDash` |
| 237 | constructor | `_Loading` |
| 238 | method | `_Loading.build` |
| 246 | constructor | `_Empty` |
| 248 | method | `_Empty.build` |

## workout-logger/lib/screens/widgets/activity_heatmap.dart

| Line | Kind | Declaration |
|---|---|---|
| 8 | constructor | `ActivityHeatmap` |
| 15 | method | `ActivityHeatmap.build` |
| 81 | constructor | `_HeatCell` |
| 84 | method | `_HeatCell.build` |

## workout-logger/lib/screens/widgets/analytics_overview.dart

| Line | Kind | Declaration |
|---|---|---|
| 24 | constructor | `AnalyticsOverviewTab` |
| 26 | method | `AnalyticsOverviewTab.build` |
| 63 | getter | `(extension).label` |
| 68 | getter | `(extension).weeks` |
| 76 | constructor | `_VolumeTrendCard` |
| 78 | method | `_VolumeTrendCard.createState` |
| 87 | method | `_VolumeTrendCardState.build` |
| 113 | function | `weeklyVolume` |
| 144 | function | `weekStartFor` |
| 361 | constructor | `_RangeToggle` |
| 365 | method | `_RangeToggle.build` |
| 407 | constructor | `_MuscleFocusCard` |
| 423 | method | `_MuscleFocusCard.build` |
| 479 | method | `_MuscleFocusCard._openDrillDown` |
| 493 | constructor | `_MuscleFocusRow` |
| 511 | getter | `_MuscleFocusRow._trend` |
| 531 | getter | `_MuscleFocusRow._recoveryColor` |
| 539 | method | `_MuscleFocusRow.build` |
| 614 | constructor | `_FrequencyGrid` |
| 617 | method | `_FrequencyGrid.build` |
| 694 | constructor | `_ChartCard` |
| 704 | method | `_ChartCard.build` |
| 735 | constructor | `_EmptyChart` |
| 737 | method | `_EmptyChart.build` |
| 754 | function | `_fmtK` |

## workout-logger/lib/screens/widgets/body_heatmap.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `BodyHeatmapWidget` |
| 42 | method | `BodyHeatmapWidget.build` |
| 78 | constructor | `MuscleBodyMap` |
| 92 | method | `MuscleBodyMap.build` |
| 209 | function | `_ids` |
| 217 | function | `_heatColor` |
| 222 | constructor | `_Geometry` |
| 238 | function | `_geometry` |
| 245 | method | `_PathReceiver.parse` |
| 246 | method | `_PathReceiver.moveTo` |
| 248 | method | `_PathReceiver.lineTo` |
| 250 | method | `_PathReceiver.cubicTo` |
| 259 | method | `_PathReceiver.close` |
| 264 | constructor | `_BodyPainter` |
| 279 | method | `_BodyPainter._scale` |
| 283 | method | `_BodyPainter._origin` |
| 287 | method | `_BodyPainter._volume` |
| 292 | method | `_BodyPainter._target` |
| 299 | method | `_BodyPainter._rect` |
| 311 | method | `_BodyPainter.muscleAt` |
| 322 | method | `_BodyPainter.paint` |
| 354 | getter | `_BodyPainter.semanticsBuilder` |
| 374 | method | `_BodyPainter.shouldRepaint` |
| 380 | method | `_BodyPainter.shouldRebuildSemantics` |

## workout-logger/lib/screens/widgets/calendar_grid.dart

| Line | Kind | Declaration |
|---|---|---|
| 5 | constructor | `CalendarDayData` |
| 12 | constructor | `CalendarMonthGrid` |
| 27 | method | `CalendarMonthGrid.build` |
| 148 | constructor | `_DayCell` |
| 164 | method | `_DayCell.build` |

## workout-logger/lib/screens/widgets/dashboard_widgets.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | constructor | `WeekActivityStrip` |
| 18 | method | `WeekActivityStrip.build` |
| 92 | constructor | `StatGrid` |
| 96 | method | `StatGrid._formatVolume` |
| 101 | method | `StatGrid.build` |
| 161 | constructor | `QuickActionTile` |
| 174 | method | `QuickActionTile.build` |
| 219 | constructor | `RecentWorkoutsSection` |
| 232 | method | `RecentWorkoutsSection.build` |

## workout-logger/lib/screens/widgets/editable_exercise_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 23 | constructor | `EditableExerciseLog` |
| 38 | constructor | `EditableSet` |
| 50 | constructor | `EditableExerciseCard` |
| 67 | method | `EditableExerciseCard.build` |
| 195 | method | `EditableExerciseCard._confirmDelete` |
| 235 | constructor | `EditableSetRow` |
| 260 | method | `EditableSetRow.createState` |
| 270 | method | `_EditableSetRowState.initState` |
| 277 | method | `_EditableSetRowState.didUpdateWidget` |
| 292 | method | `_EditableSetRowState.dispose` |
| 301 | method | `_EditableSetRowState.build` |
| 456 | constructor | `EditableDropRow` |
| 473 | method | `EditableDropRow.createState` |
| 483 | method | `_EditableDropRowState.initState` |
| 490 | method | `_EditableDropRowState.didUpdateWidget` |
| 505 | method | `_EditableDropRowState.dispose` |
| 514 | method | `_EditableDropRowState.build` |
| 573 | constructor | `_NumField` |
| 591 | method | `_NumField.build` |

## workout-logger/lib/screens/widgets/exercise_animation_player.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | constructor | `ExerciseAnimationPlayer` |
| 18 | method | `ExerciseAnimationPlayer.createState` |
| 29 | getter | `_ExerciseAnimationPlayerState._animation` |
| 32 | method | `_ExerciseAnimationPlayerState.initState` |
| 42 | method | `_ExerciseAnimationPlayerState.didChangeDependencies` |
| 52 | method | `_ExerciseAnimationPlayerState.didUpdateWidget` |
| 63 | method | `_ExerciseAnimationPlayerState.didChangeAppLifecycleState` |
| 70 | method | `_ExerciseAnimationPlayerState._checkVisibility` |
| 90 | method | `_ExerciseAnimationPlayerState._pause` |
| 95 | method | `_ExerciseAnimationPlayerState._toggle` |
| 106 | method | `_ExerciseAnimationPlayerState._changeSpeed` |
| 115 | method | `_ExerciseAnimationPlayerState.dispose` |
| 122 | method | `_ExerciseAnimationPlayerState.build` |
| 299 | function | `squatMovementPreview` |

## workout-logger/lib/screens/widgets/exercise_demonstration_section.dart

| Line | Kind | Declaration |
|---|---|---|
| 13 | constructor | `ExerciseDemonstrationSection` |
| 21 | method | `ExerciseDemonstrationSection.createState` |
| 30 | getter | `_ExerciseDemonstrationSectionState._cache` |
| 32 | method | `_ExerciseDemonstrationSectionState.initState` |
| 38 | method | `_ExerciseDemonstrationSectionState.didUpdateWidget` |
| 48 | method | `_ExerciseDemonstrationSectionState._download` |
| 73 | method | `_ExerciseDemonstrationSectionState.build` |

## workout-logger/lib/screens/widgets/exercise_details_sheet.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | constructor | `ExerciseDetailsSheet` |
| 26 | method | `ExerciseDetailsSheet.build` |
| 352 | method | `ExerciseDetailsSheet._confirmDelete` |

## workout-logger/lib/screens/widgets/exercise_input_section.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | constructor | `ExerciseInputSection` |
| 87 | method | `ExerciseInputSection.build` |
| 267 | constructor | `_HandleSelector` |
| 279 | method | `_HandleSelector.build` |
| 314 | constructor | `_RecommendationCard` |
| 324 | method | `_RecommendationCard.build` |
| 455 | constructor | `_InputRow` |
| 475 | method | `_InputRow.build` |
| 527 | constructor | `_NumberInputCard` |
| 551 | method | `_NumberInputCard.valueSlotWidth` |
| 555 | method | `_NumberInputCard.valueFits` |
| 560 | method | `_NumberInputCard.valueStyle` |
| 567 | method | `_NumberInputCard.measureValue` |
| 582 | method | `_NumberInputCard.createState` |
| 590 | method | `_NumberInputCardState.initState` |
| 596 | method | `_NumberInputCardState.didUpdateWidget` |
| 606 | method | `_NumberInputCardState.dispose` |
| 613 | method | `_NumberInputCardState._format` |
| 617 | method | `_NumberInputCardState._fitFontSize` |
| 633 | method | `_NumberInputCardState.build` |
| 720 | constructor | `_StepBtn` |
| 724 | method | `_StepBtn.sizeOf` |
| 728 | method | `_StepBtn.build` |
| 752 | constructor | `_DropsetSection` |
| 784 | method | `_DropsetSection.build` |
| 873 | constructor | `_DropRow` |
| 891 | method | `_DropRow.build` |
| 972 | constructor | `_PreviousSetsSection` |
| 977 | method | `_PreviousSetsSection.build` |
| 1081 | constructor | `_LastSessionSection` |
| 1089 | method | `_LastSessionSection.build` |
| 1153 | constructor | `_ProgramMetaBanner` |
| 1158 | method | `_ProgramMetaBanner.build` |
| 1245 | method | `_ProgramMetaBanner._metaChip` |

## workout-logger/lib/screens/widgets/exercise_movement_painter.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | constructor | `ExercisePose` |
| 28 | getter | `ExercisePose.head` |
| 33 | method | `ExercisePose.joint` |
| 50 | method | `ExercisePose.at` |
| 194 | method | `ExercisePose._core` |
| 239 | method | `ExercisePose._upright` |
| 370 | constructor | `ExerciseMovementPainter` |
| 379 | method | `ExerciseMovementPainter.paint` |
| 410 | method | `ExerciseMovementPainter._line` |
| 419 | method | `ExerciseMovementPainter._support` |
| 422 | method | `ExerciseMovementPainter._equipmentBehind` |
| 524 | method | `ExerciseMovementPainter._body` |
| 667 | method | `ExerciseMovementPainter._limb` |
| 706 | method | `ExerciseMovementPainter._segment` |
| 757 | method | `ExerciseMovementPainter._shoe` |
| 776 | method | `ExerciseMovementPainter._weight` |
| 795 | method | `ExerciseMovementPainter._equipmentInFront` |
| 912 | method | `ExerciseMovementPainter.shouldRepaint` |

## workout-logger/lib/screens/widgets/exercise_muscle_map.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `ExerciseMuscleMap` |
| 18 | method | `ExerciseMuscleMap.createState` |
| 25 | method | `_ExerciseMuscleMapState.build` |

## workout-logger/lib/screens/widgets/exercise_progress_view.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `ExerciseProgressView` |
| 23 | method | `ExerciseProgressView.createState` |
| 31 | method | `_ExerciseProgressViewState.build` |
| 100 | constructor | `_ExerciseDropdown` |
| 112 | method | `_ExerciseDropdown._openSheet` |
| 135 | method | `_ExerciseDropdown.build` |
| 210 | constructor | `_ExercisePickerSheet` |
| 221 | method | `_ExercisePickerSheet.createState` |
| 229 | method | `_ExercisePickerSheetState.initState` |
| 236 | method | `_ExercisePickerSheetState._onSearch` |
| 249 | method | `_ExercisePickerSheetState.dispose` |
| 255 | method | `_ExercisePickerSheetState.build` |
| 447 | constructor | `_ExerciseStats` |
| 459 | method | `_ExerciseStats.build` |
| 534 | constructor | `_BestHoldCard` |
| 537 | method | `_BestHoldCard.build` |
| 612 | constructor | `_OneRMCard` |
| 616 | method | `_OneRMCard.build` |
| 691 | constructor | `_GrowthCard` |
| 694 | method | `_GrowthCard.build` |
| 768 | constructor | `_ChartSection` |
| 786 | method | `_ChartSection.build` |
| 834 | constructor | `_ChartModeToggle` |
| 843 | method | `_ChartModeToggle.build` |
| 890 | constructor | `_VolumeChart` |
| 899 | method | `_VolumeChart.build` |
| 906 | function | `dayAt` |
| 1167 | constructor | `_SetProgressionChart` |
| 1178 | method | `_SetProgressionChart.createState` |
| 1193 | method | `_SetProgressionChartState._weekStart` |
| 1198 | method | `_SetProgressionChartState._maxFit` |
| 1208 | method | `_SetProgressionChartState._buildSessions` |
| 1259 | method | `_SetProgressionChartState._buildGroups` |
| 1319 | method | `_SetProgressionChartState._tooltip` |
| 1403 | method | `_SetProgressionChartState.build` |
| 1596 | constructor | `_ToggleLegend` |
| 1607 | method | `_ToggleLegend.build` |
| 1646 | constructor | `_SetModeToggle` |
| 1650 | method | `_SetModeToggle.build` |
| 1692 | constructor | `_SessionHistory` |
| 1702 | method | `_SessionHistory.build` |
| 1761 | constructor | `_AskCoachButton` |
| 1769 | method | `_AskCoachButton.build` |

## workout-logger/lib/screens/widgets/floating_nav_bar.dart

| Line | Kind | Declaration |
|---|---|---|
| 47 | constructor | `FloatingNavItem` |
| 66 | method | `FloatingNavItem.iconFor` |
| 81 | constructor | `FloatingNavBarTheme` |
| 245 | constructor | `FloatingNavBar` |
| 265 | method | `FloatingNavBar.build` |
| 355 | constructor | `_ShadowWrapper` |
| 373 | method | `_ShadowWrapper.build` |
| 403 | constructor | `_NavCell` |
| 421 | method | `_NavCell.createState` |
| 431 | method | `_NavCellState.initState` |
| 438 | method | `_NavCellState.didUpdateWidget` |
| 467 | method | `_NavCellState.dispose` |
| 473 | method | `_NavCellState.build` |
| 477 | function | `handleTap` |
| 661 | constructor | `FloatingNavBarScaffold` |
| 692 | method | `FloatingNavBarScaffold.createState` |
| 701 | method | `_FloatingNavBarScaffoldState._handleTabChange` |
| 712 | method | `_FloatingNavBarScaffoldState._handleScrollNotification` |
| 758 | method | `_FloatingNavBarScaffoldState.build` |

## workout-logger/lib/screens/widgets/gender_picker.dart

| Line | Kind | Declaration |
|---|---|---|
| 5 | constructor | `GenderPicker` |
| 9 | method | `GenderPicker.build` |

## workout-logger/lib/screens/widgets/health_bar_chart.dart

| Line | Kind | Declaration |
|---|---|---|
| 26 | constructor | `_Segment` |
| 37 | constructor | `_AggBar` |
| 47 | function | `_hm` |
| 56 | constructor | `SleepBarsChart` |
| 69 | method | `SleepBarsChart.build` |
| 109 | method | `SleepBarsChart._labelFor` |
| 113 | method | `SleepBarsChart._isMonthBar` |
| 121 | constructor | `HrRangeChart` |
| 132 | method | `HrRangeChart.build` |
| 176 | function | `_key` |
| 183 | constructor | `HrDayChart` |
| 188 | method | `HrDayChart.createState` |
| 196 | method | `_HrDayChartState._indexAt` |
| 204 | method | `_HrDayChartState.build` |
| 229 | constructor | `_HrDayPainter` |
| 237 | method | `_HrDayPainter.paint` |
| 247 | function | `yFor` |
| 341 | method | `_HrDayPainter.shouldRepaint` |
| 348 | constructor | `_AggBarChart` |
| 368 | method | `_AggBarChart.createState` |
| 377 | method | `_AggBarChartState._indexAt` |
| 385 | method | `_AggBarChartState.build` |
| 430 | constructor | `_AggPainter` |
| 454 | method | `_AggPainter.paint` |
| 463 | function | `yFor` |
| 574 | method | `_AggPainter._paintTooltip` |
| 614 | method | `_AggPainter.shouldRepaint` |

## workout-logger/lib/screens/widgets/health_detail_shell.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `HealthDetailShell` |
| 37 | method | `HealthDetailShell.build` |
| 72 | method | `HealthDetailShell._header` |
| 129 | constructor | `_NavArrow` |
| 133 | method | `_NavArrow.build` |
| 157 | constructor | `_GranularityToggle` |
| 162 | method | `_GranularityToggle.build` |

## workout-logger/lib/screens/widgets/heart_rate_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 18 | constructor | `HeartRateCard` |
| 20 | method | `HeartRateCard.build` |
| 105 | constructor | `_MiniStat` |
| 112 | method | `_MiniStat.build` |
| 147 | constructor | `_HrSparkline` |
| 151 | method | `_HrSparkline.paint` |
| 158 | function | `yFor` |
| 190 | method | `_HrSparkline.shouldRepaint` |

## workout-logger/lib/screens/widgets/muscle_detail_sheet.dart

| Line | Kind | Declaration |
|---|---|---|
| 24 | constructor | `MuscleDetailSheet` |
| 33 | method | `MuscleDetailSheet.build` |
| 256 | constructor | `_MuscleVolumeTrendChart` |
| 264 | method | `_MuscleVolumeTrendChart.build` |
| 278 | constructor | `_VolumeTrendChartView` |
| 290 | method | `_VolumeTrendChartView.build` |
| 373 | constructor | `_RecentMuscleSessionsSection` |
| 381 | method | `_RecentMuscleSessionsSection.build` |
| 394 | constructor | `_RecentSessionsView` |
| 404 | method | `_RecentSessionsView._relativeDate` |
| 413 | method | `_RecentSessionsView.build` |
| 495 | function | `_previewScaffold` |
| 507 | function | `_stubSeries` |
| 519 | function | `_stubSessions` |
| 530 | function | `previewVolumeTrend` |
| 540 | function | `previewVolumeTrendEmpty` |
| 553 | function | `previewRecentSessions` |
| 562 | function | `previewRecentSessionsEmpty` |
| 574 | constructor | `_AiInsightSection` |
| 584 | method | `_AiInsightSection.createState` |
| 592 | method | `_AiInsightSectionState._fetchInsight` |
| 626 | method | `_AiInsightSectionState._openCoach` |
| 638 | method | `_AiInsightSectionState.build` |

## workout-logger/lib/screens/widgets/profile_sections.dart

| Line | Kind | Declaration |
|---|---|---|
| 22 | constructor | `_ProfileSection` |
| 38 | method | `_ProfileSection.build` |
| 101 | constructor | `PreferencesSection` |
| 110 | method | `PreferencesSection.build` |
| 259 | constructor | `HealthConnectSection` |
| 280 | method | `HealthConnectSection.build` |
| 410 | constructor | `DataManagementSection` |
| 423 | method | `DataManagementSection.build` |
| 457 | constructor | `AboutSection` |
| 460 | method | `AboutSection.createState` |
| 467 | method | `_AboutSectionState._onVersionTap` |
| 475 | method | `_AboutSectionState._showDebugLogs` |
| 487 | method | `_AboutSectionState.build` |
| 539 | constructor | `_SectionLabel` |
| 542 | method | `_SectionLabel.build` |
| 558 | constructor | `_UnitToggleButton` |
| 568 | method | `_UnitToggleButton.build` |
| 613 | constructor | `_ActionTile` |
| 629 | method | `_ActionTile.build` |
| 700 | constructor | `_InfoTile` |
| 710 | method | `_InfoTile.build` |
| 743 | constructor | `_SectionDivider` |
| 745 | method | `_SectionDivider.build` |
| 753 | constructor | `AiSettingsSection` |
| 755 | method | `AiSettingsSection.createState` |
| 771 | method | `_AiSettingsSectionState.initState` |
| 784 | method | `_AiSettingsSectionState.dispose` |
| 790 | method | `_AiSettingsSectionState._refreshModels` |
| 817 | method | `_AiSettingsSectionState._reportSaved` |
| 825 | method | `_AiSettingsSectionState._reportSaveFailed` |
| 833 | method | `_AiSettingsSectionState._save` |
| 851 | method | `_AiSettingsSectionState._selectModel` |
| 868 | method | `_AiSettingsSectionState._commitMaxToolRounds` |
| 890 | method | `_AiSettingsSectionState._commitThinkingLevel` |
| 912 | method | `_AiSettingsSectionState.build` |
| 1345 | constructor | `_UsageRow` |
| 1349 | method | `_UsageRow.build` |
| 1376 | function | `_formatInt` |
| 1389 | constructor | `_DebugLogSheet` |
| 1391 | method | `_DebugLogSheet.build` |

## workout-logger/lib/screens/widgets/program_week_editor.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | constructor | `ProgramNumberStepper` |
| 28 | method | `ProgramNumberStepper.build` |
| 78 | constructor | `ProgramSectionHeader` |
| 81 | method | `ProgramSectionHeader.build` |
| 100 | constructor | `ProgramWeekEditorStep` |
| 109 | method | `ProgramWeekEditorStep.createState` |
| 117 | method | `_ProgramWeekEditorStepState.initState` |
| 123 | method | `_ProgramWeekEditorStepState.didUpdateWidget` |
| 131 | method | `_ProgramWeekEditorStepState._update` |
| 136 | method | `_ProgramWeekEditorStepState.build` |
| 148 | method | `_ProgramWeekEditorStepState._buildWeekEditor` |
| 269 | method | `_ProgramWeekEditorStepState._buildDayChip` |
| 299 | method | `_ProgramWeekEditorStepState._addDay` |
| 379 | method | `_ProgramWeekEditorStepState._styledField` |

## workout-logger/lib/screens/widgets/program_week_tile.dart

| Line | Kind | Declaration |
|---|---|---|
| 18 | constructor | `ProgramWeekTile` |
| 33 | method | `ProgramWeekTile.createState` |
| 40 | method | `_ProgramWeekTileState.build` |
| 108 | method | `_ProgramWeekTileState._buildHeader` |
| 205 | method | `_ProgramWeekTileState._buildDaySection` |
| 300 | method | `_ProgramWeekTileState._buildSupersetGroup` |
| 337 | method | `_ProgramWeekTileState._buildExerciseRow` |
| 428 | method | `_ProgramWeekTileState._infoChip` |
| 440 | method | `_ProgramWeekTileState._dayName` |

## workout-logger/lib/screens/widgets/readiness_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | constructor | `ReadinessCard` |
| 23 | method | `ReadinessCard.build` |
| 43 | method | `ReadinessCard._buildMainCard` |
| 95 | method | `ReadinessCard._bandColor` |
| 101 | method | `ReadinessCard._headline` |
| 107 | method | `ReadinessCard._subtitle` |
| 131 | method | `ReadinessCard._fmtSleep` |
| 137 | method | `ReadinessCard._showDetails` |
| 150 | constructor | `_ScoreRing` |
| 155 | method | `_ScoreRing.build` |
| 189 | constructor | `_ReadinessDetailsSheet` |
| 193 | method | `_ReadinessDetailsSheet.build` |
| 270 | constructor | `_ComponentRow` |
| 280 | method | `_ComponentRow.build` |

## workout-logger/lib/screens/widgets/release_widgets.dart

| Line | Kind | Declaration |
|---|---|---|
| 8 | constructor | `ReleaseNotes` |
| 17 | method | `ReleaseNotes.createState` |
| 23 | method | `_ReleaseNotesState.initState` |
| 32 | method | `_ReleaseNotesState.build` |
| 70 | constructor | `ReleaseNotesView` |
| 73 | method | `ReleaseNotesView._countLabel` |
| 76 | method | `ReleaseNotesView.build` |
| 127 | constructor | `UpdateNotice` |
| 130 | method | `UpdateNotice.createState` |
| 136 | method | `_UpdateNoticeState.initState` |
| 142 | method | `_UpdateNoticeState._check` |
| 149 | method | `_UpdateNoticeState.build` |

## workout-logger/lib/screens/widgets/rest_timer_view.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `RestTimerView` |
| 24 | method | `RestTimerView.build` |
| 101 | constructor | `_AdjustButton` |
| 105 | method | `_AdjustButton.build` |

## workout-logger/lib/screens/widgets/rf_accordion.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `RFAccordion` |
| 19 | method | `RFAccordion.build` |

## workout-logger/lib/screens/widgets/rf_cards.dart

| Line | Kind | Declaration |
|---|---|---|
| 13 | constructor | `SessionCard` |
| 28 | method | `SessionCard.build` |
| 168 | constructor | `StatGridCard` |
| 183 | method | `StatGridCard.build` |
| 247 | constructor | `RecentSessionTile` |
| 258 | method | `RecentSessionTile.build` |
| 335 | constructor | `RoutineCard` |
| 350 | method | `RoutineCard.build` |
| 485 | constructor | `TargetCard` |
| 496 | method | `TargetCard.build` |
| 591 | constructor | `ExerciseCard` |
| 602 | method | `ExerciseCard.build` |

## workout-logger/lib/screens/widgets/rf_dialogs.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | method | `RFSnackBarContext.showRFSnackBar` |
| 79 | constructor | `RFAction` |
| 100 | function | `showRFActionSheet` |
| 185 | constructor | `_SheetChoice` |
| 190 | method | `_SheetChoice.build` |
| 251 | function | `showRFConfirmDialog` |

## workout-logger/lib/screens/widgets/rf_inputs.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `RFTextField` |
| 47 | method | `RFTextField.build` |
| 106 | constructor | `RFNumberField` |
| 127 | method | `RFNumberField.createState` |
| 137 | method | `_RFNumberFieldState.initState` |
| 147 | method | `_RFNumberFieldState.didUpdateWidget` |
| 155 | method | `_RFNumberFieldState.dispose` |
| 163 | method | `_RFNumberFieldState._format` |
| 166 | method | `_RFNumberFieldState._startIncrement` |
| 173 | method | `_RFNumberFieldState._stopIncrement` |
| 178 | method | `_RFNumberFieldState._step` |
| 184 | method | `_RFNumberFieldState._commitEdit` |
| 194 | method | `_RFNumberFieldState.build` |
| 324 | constructor | `RFToggle` |
| 337 | method | `RFToggle.build` |
| 388 | constructor | `RFDropdown` |
| 403 | method | `RFDropdown.build` |
| 440 | constructor | `NumberPickerSheet` |
| 459 | method | `NumberPickerSheet.show` |
| 487 | method | `NumberPickerSheet.createState` |
| 495 | method | `_NumberPickerSheetState.initState` |
| 501 | method | `_NumberPickerSheetState.dispose` |
| 507 | method | `_NumberPickerSheetState._step` |
| 514 | getter | `_NumberPickerSheetState._display` |
| 518 | method | `_NumberPickerSheetState.build` |
| 605 | constructor | `_StepButton` |
| 617 | method | `_StepButton.build` |

## workout-logger/lib/screens/widgets/rf_question_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | constructor | `RFQuestionCard` |
| 23 | method | `RFQuestionCard.createState` |
| 31 | method | `_RFQuestionCardState.initState` |
| 41 | method | `_RFQuestionCardState.dispose` |
| 49 | method | `_RFQuestionCardState._submit` |
| 64 | method | `_RFQuestionCardState.build` |
| 126 | constructor | `_QuestionBlock` |
| 138 | method | `_QuestionBlock.build` |
| 208 | constructor | `_OptionChip` |
| 218 | method | `_OptionChip.build` |

## workout-logger/lib/screens/widgets/rf_shell.dart

| Line | Kind | Declaration |
|---|---|---|
| 10 | constructor | `RFIconButton` |
| 43 | method | `RFIconButton.build` |
| 101 | constructor | `RFGradientBadge` |
| 118 | method | `RFGradientBadge.build` |
| 143 | constructor | `RFScreenHeader` |
| 172 | method | `RFScreenHeader.build` |
| 289 | constructor | `RFBottomBar` |
| 293 | method | `RFBottomBar.clearance` |
| 297 | method | `RFBottomBar.build` |
| 318 | constructor | `RFLabel` |
| 326 | method | `RFLabel.build` |
| 344 | constructor | `RFOptionChip` |
| 370 | method | `RFOptionChip.build` |

## workout-logger/lib/screens/widgets/rf_widgets.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | function | `slideRoute` |
| 29 | constructor | `GlassCard` |
| 54 | method | `GlassCard.build` |
| 116 | constructor | `_GradedRingPainter` |
| 120 | method | `_GradedRingPainter.paint` |
| 137 | method | `_GradedRingPainter.shouldRepaint` |
| 146 | constructor | `AmbientMotion` |
| 152 | method | `AmbientMotion.read` |
| 163 | constructor | `AmbientMotionScope` |
| 167 | method | `AmbientMotionScope.createState` |
| 174 | method | `_AmbientMotionScopeState.dispose` |
| 180 | method | `_AmbientMotionScopeState._onScroll` |
| 187 | method | `_AmbientMotionScopeState.build` |
| 208 | constructor | `AmbientGlow` |
| 214 | method | `AmbientGlow.createState` |
| 251 | method | `_AmbientGlowState.initState` |
| 259 | method | `_AmbientGlowState.didChangeDependencies` |
| 269 | getter | `_AmbientGlowState._animates` |
| 272 | method | `_AmbientGlowState.dispose` |
| 278 | method | `_AmbientGlowState._wave` |
| 281 | method | `_AmbientGlowState._sampleParallax` |
| 291 | method | `_AmbientGlowState._pool` |
| 320 | method | `_AmbientGlowState._rig` |
| 373 | method | `_AmbientGlowState.build` |
| 403 | constructor | `_WashFloor` |
| 405 | method | `_WashFloor.build` |
| 425 | constructor | `_Wash` |
| 430 | method | `_Wash.build` |
| 456 | constructor | `GlowButton` |
| 473 | method | `GlowButton.createState` |
| 482 | method | `_GlowButtonState.initState` |
| 496 | method | `_GlowButtonState.dispose` |
| 502 | method | `_GlowButtonState._onTapDown` |
| 506 | method | `_GlowButtonState._onTapUp` |
| 513 | method | `_GlowButtonState._onTapCancel` |
| 518 | method | `_GlowButtonState.build` |
| 598 | constructor | `OutlineGlowButton` |
| 615 | method | `OutlineGlowButton.build` |
| 652 | constructor | `RFChip` |
| 663 | method | `RFChip.build` |
| 691 | constructor | `RFSectionHeader` |
| 702 | method | `RFSectionHeader.build` |
| 716 | constructor | `RFStatBox` |
| 729 | method | `RFStatBox.build` |
| 777 | constructor | `AnimatedCounter` |
| 792 | method | `AnimatedCounter.build` |
| 821 | constructor | `MetricHero` |
| 834 | method | `MetricHero.build` |
| 868 | constructor | `RFDivider` |
| 871 | method | `RFDivider.build` |
| 884 | constructor | `RFEmptyState` |
| 897 | method | `RFEmptyState.build` |
| 949 | constructor | `RFLoadingDots` |
| 952 | method | `RFLoadingDots.createState` |
| 960 | method | `_RFLoadingDotsState.initState` |
| 969 | method | `_RFLoadingDotsState.dispose` |
| 975 | method | `_RFLoadingDotsState.build` |
| 1006 | constructor | `RFProgressBar` |
| 1019 | method | `RFProgressBar.build` |
| 1064 | constructor | `RestTimerRing` |
| 1075 | method | `RestTimerRing.build` |
| 1120 | constructor | `_RingPainter` |
| 1123 | method | `_RingPainter.paint` |
| 1156 | method | `_RingPainter.shouldRepaint` |
| 1162 | constructor | `SkeletonBox` |
| 1173 | method | `SkeletonBox.createState` |
| 1181 | method | `_SkeletonBoxState.initState` |
| 1190 | method | `_SkeletonBoxState.dispose` |
| 1196 | method | `_SkeletonBoxState.build` |
| 1217 | constructor | `RFTextField` |
| 1240 | method | `RFTextField.createState` |
| 1248 | method | `_RFTextFieldState.initState` |
| 1255 | method | `_RFTextFieldState._onFocusChange` |
| 1259 | method | `_RFTextFieldState.dispose` |
| 1266 | method | `_RFTextFieldState.build` |

## workout-logger/lib/screens/widgets/routine_creator.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | function | `startRoutineWorkoutFlow` |
| 47 | constructor | `CreateRoutineScreen` |
| 50 | method | `CreateRoutineScreen.createState` |
| 58 | method | `_CreateRoutineScreenState.initState` |
| 67 | method | `_CreateRoutineScreenState.dispose` |
| 73 | method | `_CreateRoutineScreenState.build` |
| 241 | method | `_CreateRoutineScreenState._showPicker` |
| 397 | method | `_CreateRoutineScreenState._save` |
| 443 | constructor | `RoutineDetailScreen` |
| 446 | method | `RoutineDetailScreen.build` |

## workout-logger/lib/screens/widgets/session_details_sheet.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | constructor | `SessionDetailsSheet` |
| 32 | method | `SessionDetailsSheet.build` |
| 199 | constructor | `_StatBannerBox` |
| 209 | method | `_StatBannerBox.build` |
| 249 | constructor | `_ActionChip` |
| 261 | method | `_ActionChip.build` |
| 294 | constructor | `_ExerciseDetailCard` |
| 299 | method | `_ExerciseDetailCard.build` |
| 400 | constructor | `_SetRow` |
| 404 | method | `_SetRow.build` |

## workout-logger/lib/screens/widgets/sleep_hr_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | constructor | `SleepHrCard` |
| 21 | method | `SleepHrCard.build` |
| 121 | method | `SleepHrCard._openSheet` |
| 129 | method | `SleepHrCard._toIst` |
| 132 | method | `SleepHrCard._fmtTime` |
| 141 | constructor | `_MiniStat` |
| 153 | method | `_MiniStat.build` |
| 197 | constructor | `_SparklinePainter` |
| 201 | method | `_SparklinePainter.paint` |
| 209 | function | `yFor` |
| 257 | method | `_SparklinePainter.shouldRepaint` |

## workout-logger/lib/screens/widgets/sleep_hr_charts.dart

| Line | Kind | Declaration |
|---|---|---|
| 31 | function | `_toIst` |
| 35 | constructor | `SleepHrDayView` |
| 39 | method | `SleepHrDayView.build` |
| 105 | constructor | `_StatPill` |
| 111 | method | `_StatPill.build` |
| 143 | constructor | `_InteractiveBarChart` |
| 146 | method | `_InteractiveBarChart.createState` |
| 156 | method | `_InteractiveBarChartState._indexAt` |
| 164 | method | `_InteractiveBarChartState.build` |
| 192 | constructor | `_BarChartPainter` |
| 201 | method | `_BarChartPainter.paint` |
| 216 | function | `yFor` |
| 374 | method | `_BarChartPainter.shouldRepaint` |
| 382 | constructor | `_StageTimelineStrip` |
| 385 | method | `_StageTimelineStrip.build` |
| 411 | method | `_Legend.build` |
| 449 | method | `_DashLinePainter.paint` |
| 461 | method | `_DashLinePainter.shouldRepaint` |
| 468 | constructor | `_StageDistributionChart` |
| 478 | method | `_StageDistributionChart.build` |
| 514 | constructor | `_DistRow` |
| 528 | method | `_DistRow.build` |
| 530 | function | `pct` |
| 612 | constructor | `_DistAxis` |
| 617 | method | `_DistAxis.build` |
| 628 | function | `pct` |
| 650 | method | `_DistLegend.build` |
| 692 | constructor | `_DistLi` |
| 696 | method | `_DistLi.build` |

## workout-logger/lib/screens/widgets/sparkline_painter.dart

| Line | Kind | Declaration |
|---|---|---|
| 4 | constructor | `SparklinePainter` |
| 16 | method | `SparklinePainter.paint` |
| 56 | method | `SparklinePainter.shouldRepaint` |
| 62 | constructor | `Sparkline` |
| 77 | method | `Sparkline.build` |

## workout-logger/lib/screens/widgets/targets_tab.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | constructor | `TargetsTab` |
| 21 | method | `TargetsTab.build` |
| 93 | method | `TargetsTab._showCreateSheet` |
| 109 | constructor | `_SummaryHeader` |
| 117 | method | `_SummaryHeader.build` |
| 158 | constructor | `_SummaryChip` |
| 162 | method | `_SummaryChip.build` |
| 186 | constructor | `_TargetCardWithAi` |
| 198 | method | `_TargetCardWithAi.createState` |
| 206 | getter | `_TargetCardWithAiState._isStalled` |
| 212 | getter | `_TargetCardWithAiState._statusWord` |
| 218 | getter | `_TargetCardWithAiState._statusColor` |
| 224 | method | `_TargetCardWithAiState._fetchNudge` |
| 245 | method | `_TargetCardWithAiState._openCoach` |
| 256 | method | `_TargetCardWithAiState.build` |
| 456 | constructor | `_CreateTargetSheet` |
| 458 | method | `_CreateTargetSheet.createState` |
| 476 | method | `_CreateTargetSheetState.dispose` |
| 482 | method | `_CreateTargetSheetState._fetchSuggestion` |
| 518 | method | `_CreateTargetSheetState.build` |
| 766 | method | `_CreateTargetSheetState._submit` |

## workout-logger/lib/screens/widgets/time_exercise_card.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | constructor | `TimeExerciseCard` |
| 36 | method | `TimeExerciseCard.createState` |
| 58 | method | `_TimeExerciseCardState.initState` |
| 78 | method | `_TimeExerciseCardState.didUpdateWidget` |
| 100 | method | `_TimeExerciseCardState.dispose` |
| 108 | method | `_TimeExerciseCardState._toggleStopwatch` |
| 138 | method | `_TimeExerciseCardState._resetStopwatch` |
| 150 | method | `_TimeExerciseCardState._toggleTimer` |
| 201 | method | `_TimeExerciseCardState._resetTimer` |
| 212 | method | `_TimeExerciseCardState._selectPreset` |
| 228 | method | `_TimeExerciseCardState._adjustSeconds` |
| 248 | method | `_TimeExerciseCardState._editDurationManually` |
| 318 | method | `_TimeExerciseCardState._formatTime` |
| 324 | method | `_TimeExerciseCardState.build` |
| 574 | constructor | `_ModeChip` |
| 586 | method | `_ModeChip.build` |

## workout-logger/lib/screens/widgets/volume_chart.dart

| Line | Kind | Declaration |
|---|---|---|
| 5 | constructor | `VolumeChart` |
| 18 | method | `VolumeChart.build` |
| 51 | constructor | `_VolumeCurvePainter` |
| 56 | method | `_VolumeCurvePainter.paint` |
| 144 | method | `_VolumeCurvePainter.shouldRepaint` |

## workout-logger/lib/screens/widgets/wheel_picker.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `WheelPickerField` |
| 30 | method | `WheelPickerField.build` |
| 71 | method | `WheelPickerField._buildDoubleRange` |
| 84 | constructor | `_SingleWheel` |
| 102 | method | `_SingleWheel.createState` |
| 112 | method | `_SingleWheelState.initState` |
| 120 | method | `_SingleWheelState.didUpdateWidget` |
| 134 | method | `_SingleWheelState.dispose` |
| 140 | method | `_SingleWheelState.build` |

## workout-logger/lib/screens/widgets/workout_conflict_dialog.dart

| Line | Kind | Declaration |
|---|---|---|
| 10 | constructor | `WorkoutConflictDialog` |
| 12 | method | `WorkoutConflictDialog._formatStartTime` |
| 24 | method | `WorkoutConflictDialog.build` |
| 54 | function | `showWorkoutConflictDialog` |

## workout-logger/lib/screens/widgets/workout_header.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `WorkoutHeader` |
| 39 | method | `WorkoutHeader.createState` |
| 47 | method | `_WorkoutHeaderState.initState` |
| 54 | method | `_WorkoutHeaderState._updateElapsed` |
| 62 | method | `_WorkoutHeaderState.dispose` |
| 68 | getter | `_WorkoutHeaderState._elapsedLabel` |
| 74 | method | `_WorkoutHeaderState.build` |
| 106 | constructor | `_ElapsedChip` |
| 110 | method | `_ElapsedChip.build` |
| 151 | constructor | `_OptionsMenu` |
| 163 | method | `_OptionsMenu.build` |

## workout-logger/lib/screens/widgets/workout_hr_section.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `WorkoutHrSection` |
| 26 | method | `WorkoutHrSection.createState` |
| 34 | method | `_WorkoutHrSectionState.didChangeDependencies` |
| 40 | method | `_WorkoutHrSectionState.build` |
| 144 | method | `_WorkoutHrSectionState._shortName` |
| 156 | constructor | `_Section` |
| 162 | constructor | `_RecoverySummary` |
| 165 | method | `_RecoverySummary.build` |
| 213 | constructor | `_RestRow` |
| 216 | method | `_RestRow.build` |
| 267 | constructor | `_Pill` |
| 272 | method | `_Pill.build` |
| 309 | constructor | `_CurvePainter` |
| 318 | method | `_CurvePainter.paint` |
| 331 | function | `x` |
| 333 | function | `y` |
| 433 | method | `_CurvePainter.shouldRepaint` |

## workout-logger/lib/screens/workout_flow_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 33 | constructor | `WorkoutFlowScreen` |
| 41 | method | `WorkoutFlowScreen.createState` |
| 71 | method | `_WorkoutFlowScreenState.initState` |
| 77 | method | `_WorkoutFlowScreenState.dispose` |
| 93 | method | `_WorkoutFlowScreenState._resolvedDay` |
| 96 | method | `_WorkoutFlowScreenState._resolvedWeek` |
| 99 | method | `_WorkoutFlowScreenState._slot` |
| 106 | method | `_WorkoutFlowScreenState._supersetGroupStart` |
| 114 | method | `_WorkoutFlowScreenState._supersetNeedsMoreSets` |
| 131 | method | `_WorkoutFlowScreenState._slotNeedsMoreSets` |
| 143 | method | `_WorkoutFlowScreenState._initializeWorkout` |
| 172 | method | `_WorkoutFlowScreenState._loadLastSessionData` |
| 220 | method | `_WorkoutFlowScreenState.build` |
| 247 | method | `_WorkoutFlowScreenState._buildExerciseSelector` |
| 286 | method | `_WorkoutFlowScreenState._startWithSelected` |
| 293 | method | `_WorkoutFlowScreenState._buildWorkoutView` |
| 469 | method | `_WorkoutFlowScreenState._buildRestView` |
| 486 | method | `_WorkoutFlowScreenState._buildBottomNav` |
| 531 | method | `_WorkoutFlowScreenState._toggleDropset` |
| 555 | method | `_WorkoutFlowScreenState._addDrop` |
| 570 | method | `_WorkoutFlowScreenState._removeDrop` |
| 584 | method | `_WorkoutFlowScreenState._completeSet` |
| 670 | method | `_WorkoutFlowScreenState._startRestTimer` |
| 684 | method | `_WorkoutFlowScreenState._skipRest` |
| 702 | method | `_WorkoutFlowScreenState._adjustRest` |
| 712 | method | `_WorkoutFlowScreenState._showCancelDialog` |
| 728 | method | `_WorkoutFlowScreenState._finishWorkout` |
| 750 | method | `_WorkoutFlowScreenState._handleBack` |

## workout-logger/lib/screens/workout_summary_screen.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | constructor | `WorkoutSummaryScreen` |
| 26 | method | `WorkoutSummaryScreen.build` |
| 120 | method | `WorkoutSummaryScreen._buildTrophyHeader` |
| 169 | method | `WorkoutSummaryScreen._buildStatGrid` |
| 225 | method | `WorkoutSummaryScreen._buildPRSection` |
| 289 | method | `WorkoutSummaryScreen._buildMusclesSection` |
| 307 | method | `WorkoutSummaryScreen._buildExerciseSummary` |
| 330 | constructor | `_ExerciseSummaryRow` |
| 340 | method | `_ExerciseSummaryRow.build` |
| 408 | constructor | `_EffortChipRow` |
| 412 | method | `_EffortChipRow.createState` |
| 425 | method | `_EffortChipRowState._select` |
| 440 | method | `_EffortChipRowState.build` |
| 459 | method | `_EffortChipRowState._buildChip` |

## workout-logger/lib/services/ai/ai_failure.dart

| Line | Kind | Declaration |
|---|---|---|
| 5 | constructor | `AiFailure` |
| 7 | method | `AiFailure.from` |
| 62 | method | `AiFailure.toString` |

## workout-logger/lib/services/ai/coach_tool_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 21 | constructor | `AmbiguousMatchException` |
| 31 | constructor | `CoachToolService` |
| 41 | getter | `CoachToolService.askUserQuestionsDeclaration` |
| 88 | method | `CoachToolService.buildTools` |
| 473 | getter | `CoachToolService._runSqlQueryDeclaration` |
| 521 | method | `CoachToolService.handleCall` |
| 569 | method | `CoachToolService._getSleepingHrAnalytics` |
| 697 | method | `CoachToolService._getHealthMetrics` |
| 735 | method | `CoachToolService._analyzeHealthWorkoutCorrelation` |
| 883 | method | `CoachToolService._muscleGroupVolume` |
| 961 | method | `CoachToolService._exercisePerformance` |
| 1069 | method | `CoachToolService._workoutsInRange` |
| 1119 | method | `CoachToolService._routinePerformance` |
| 1173 | method | `CoachToolService._personalRecords` |
| 1223 | method | `CoachToolService._goalProgress` |
| 1261 | method | `CoachToolService._muscleRecovery` |
| 1285 | method | `CoachToolService._getAllRoutines` |
| 1301 | method | `CoachToolService._createRoutine` |
| 1361 | method | `CoachToolService._updateRoutine` |
| 1458 | method | `CoachToolService._addCustomExercise` |
| 1544 | method | `CoachToolService._updateExercise` |
| 1649 | method | `CoachToolService._setHistory` |
| 1690 | method | `CoachToolService._parseExerciseHandles` |
| 1711 | method | `CoachToolService._resolveExercise` |
| 1727 | method | `CoachToolService._resolveRoutine` |
| 1742 | method | `CoachToolService._resolveMuscleGroup` |
| 1761 | method | `CoachToolService._exampleExerciseNames` |
| 1764 | method | `CoachToolService._d` |
| 1770 | method | `CoachToolService._round` |
| 1771 | method | `CoachToolService._roundOrNull` |
| 1773 | method | `CoachToolService._limitArg` |

## workout-logger/lib/services/ai/gemini_ai_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 43 | function | `supportedThinkingLevels` |
| 58 | function | `clampThinkingLevel` |
| 89 | function | `_isRetryableStatus` |
| 92 | function | `_retryBackoff` |
| 95 | function | `_extractRetryDelay` |
| 142 | function | `_isDailyQuotaExhausted` |
| 147 | function | `getFallbackModel` |
| 166 | function | `_errorMessage` |
| 179 | function | `buildGeminiChatContents` |
| 209 | constructor | `GeminiAiService` |
| 224 | getter | `GeminiAiService.isConfigured` |
| 227 | getter | `GeminiAiService.currentModel` |
| 230 | getter | `GeminiAiService.maxToolRounds` |
| 233 | getter | `GeminiAiService.thinkingLevel` |
| 237 | getter | `GeminiAiService.promptTokensUsed` |
| 240 | getter | `GeminiAiService.responseTokensUsed` |
| 243 | getter | `GeminiAiService.totalTokensUsed` |
| 246 | getter | `GeminiAiService.aiRequestCount` |
| 249 | method | `GeminiAiService.init` |
| 261 | method | `GeminiAiService.loadUsage` |
| 277 | method | `GeminiAiService.resetUsage` |
| 287 | method | `GeminiAiService.recordUsage` |
| 303 | method | `GeminiAiService._recordRawUsage` |
| 311 | method | `GeminiAiService._persistUsage` |
| 325 | method | `GeminiAiService.updateApiKey` |
| 330 | method | `GeminiAiService.updateModel` |
| 336 | method | `GeminiAiService.updateThinkingLevel` |
| 341 | method | `GeminiAiService.updateMaxToolRounds` |
| 348 | method | `GeminiAiService._makeBody` |
| 378 | getter | `GeminiAiService._thinkingConfig` |
| 383 | method | `GeminiAiService._textFromCandidate` |
| 397 | method | `GeminiAiService._streamSse` |
| 483 | method | `GeminiAiService._generate` |
| 524 | method | `GeminiAiService._textFromResponse` |
| 531 | method | `GeminiAiService.streamChatReply` |
| 550 | method | `GeminiAiService.streamCoachReply` |
| 674 | method | `GeminiAiService.generateStructuredJson` |
| 710 | method | `GeminiAiService.generateProgram` |
| 786 | method | `GeminiAiService.generateWeeklyInsights` |
| 813 | method | `GeminiAiService.generateInsight` |

## workout-logger/lib/services/ai/gemini_model_catalog.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `GeminiChatModelName` |
| 17 | method | `GeminiChatModelName.parse` |
| 31 | constructor | `GeminiModelCatalog` |
| 33 | method | `GeminiModelCatalog.close` |
| 34 | method | `GeminiModelCatalog.discover` |

## workout-logger/lib/services/ai/sql_query_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 9 | constructor | `SqlValidationException` |
| 12 | method | `SqlValidationException.toString` |
| 17 | constructor | `SqlQueryService` |
| 49 | method | `SqlQueryService._sanitize` |
| 77 | method | `SqlQueryService.runQuery` |

## workout-logger/lib/services/backup_codec.dart

| Line | Kind | Declaration |
|---|---|---|
| 4 | function | `decodeBackup` |
| 45 | function | `_validateRow` |

## workout-logger/lib/services/changelog.dart

| Line | Kind | Declaration |
|---|---|---|
| 4 | function | `parseChangelog` |
| 22 | function | `finish` |

## workout-logger/lib/services/debug_log_buffer.dart

| Line | Kind | Declaration |
|---|---|---|
| 6 | constructor | `DebugLogBuffer._` |
| 12 | getter | `DebugLogBuffer.lines` |
| 14 | method | `DebugLogBuffer.attach` |
| 22 | method | `DebugLogBuffer._append` |
| 31 | method | `DebugLogBuffer.clear` |

## workout-logger/lib/services/exercise_guide_cache.dart

| Line | Kind | Declaration |
|---|---|---|
| 10 | constructor | `ExerciseGuideCache` |
| 25 | method | `ExerciseGuideCache.close` |
| 30 | method | `ExerciseGuideCache.fileFor` |
| 39 | method | `ExerciseGuideCache.isDownloaded` |
| 48 | method | `ExerciseGuideCache.download` |
| 89 | method | `ExerciseGuideCache.downloadAll` |

## workout-logger/lib/services/gemini_context_builder.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `GeminiContextBuilder._` |
| 15 | method | `GeminiContextBuilder.buildCoachSystemPrompt` |
| 109 | method | `GeminiContextBuilder.buildOptimizerSystemPrompt` |
| 175 | method | `GeminiContextBuilder.buildWeeklyInsightsContext` |
| 213 | method | `GeminiContextBuilder._totalVol` |
| 216 | method | `GeminiContextBuilder._weekday` |

## workout-logger/lib/services/health_connect_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | method | `HealthConnectService._getConnector` |
| 27 | method | `HealthConnectService.isAvailable` |
| 39 | method | `HealthConnectService.requestPermissions` |
| 55 | method | `HealthConnectService.hasPermissions` |
| 79 | method | `HealthConnectService.requestReadPermissions` |
| 99 | method | `HealthConnectService.grantedReadTypes` |
| 117 | method | `HealthConnectService.readSleepSessions` |
| 185 | method | `HealthConnectService.readRestingHeartRate` |
| 210 | method | `HealthConnectService.readHrvRmssd` |
| 232 | method | `HealthConnectService.readHeartRateSamples` |
| 267 | method | `HealthConnectService.resetSegmentWeightSupport` |
| 270 | method | `HealthConnectService.writeWithWeightFallback` |
| 297 | method | `HealthConnectService.syncWorkoutSession` |
| 311 | function | `write` |

## workout-logger/lib/services/health_data_sync_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 13 | constructor | `_SampleStream` |
| 25 | constructor | `HealthDataSyncService` |
| 69 | method | `HealthDataSyncService.sync` |
| 84 | method | `HealthDataSyncService._sync` |
| 112 | method | `HealthDataSyncService._windowStart` |
| 119 | method | `HealthDataSyncService._syncSleep` |
| 130 | method | `HealthDataSyncService._syncSamples` |

## workout-logger/lib/services/interfaces/ai_service_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | getter | `IAiService.isConfigured` |
| 22 | getter | `IAiService.currentModel` |
| 25 | method | `IAiService.streamChatReply` |
| 47 | method | `IAiService.streamCoachReply` |
| 58 | method | `IAiService.generateStructuredJson` |
| 69 | method | `IAiService.generateProgram` |
| 76 | method | `IAiService.generateWeeklyInsights` |
| 79 | method | `IAiService.generateInsight` |

## workout-logger/lib/services/interfaces/health_connect_service_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | method | `IHealthConnectService.isAvailable` |
| 8 | method | `IHealthConnectService.requestPermissions` |
| 9 | method | `IHealthConnectService.hasPermissions` |
| 10 | method | `IHealthConnectService.syncWorkoutSession` |
| 20 | method | `IHealthConnectService.requestReadPermissions` |
| 25 | method | `IHealthConnectService.grantedReadTypes` |
| 28 | method | `IHealthConnectService.readSleepSessions` |
| 29 | method | `IHealthConnectService.readRestingHeartRate` |
| 30 | method | `IHealthConnectService.readHrvRmssd` |
| 32 | method | `IHealthConnectService.readHeartRateSamples` |

## workout-logger/lib/services/interfaces/health_sync_manager_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | method | `IHealthSyncManager.syncSession` |

## workout-logger/lib/services/interfaces/interfaces.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/services/interfaces/ml_service_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 8 | constructor | `DataPoint` |
| 10 | method | `DataPoint.==` |
| 19 | getter | `DataPoint.hashCode` |
| 35 | constructor | `MuscleRecoveryStatus` |
| 42 | getter | `MuscleRecoveryStatus.isRecovered` |
| 45 | getter | `MuscleRecoveryStatus.isUnderRecovered` |
| 48 | getter | `MuscleRecoveryStatus.recoveryPercent` |
| 53 | method | `IMLService.trainGrowthModel` |
| 56 | method | `IMLService.extractExerciseDataPoints` |
| 62 | method | `IMLService.extractMuscleDataPoints` |
| 70 | method | `IMLService.computeMuscleRecoveryScores` |
| 78 | method | `IMLService.lastTrainedPerMuscle` |
| 87 | method | `IMLService.recoveryScoresFrom` |
| 94 | method | `IMLService.recommendSets` |
| 122 | method | `IMLService.getDefaultRecommendations` |
| 125 | method | `IMLService.predictTargetCompletion` |

## workout-logger/lib/services/interfaces/readiness_manager_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 13 | getter | `IReadinessManager.status` |
| 15 | getter | `IReadinessManager.snapshot` |
| 18 | method | `IReadinessManager.refresh` |

## workout-logger/lib/services/interfaces/storage_service_interface.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | method | `IStorageService.init` |
| 19 | method | `IStorageService.saveWorkoutSession` |
| 20 | method | `IStorageService.getAllWorkoutSessions` |
| 21 | method | `IStorageService.getWorkoutSession` |
| 22 | method | `IStorageService.deleteWorkoutSession` |
| 23 | method | `IStorageService.getSessionsForExercise` |
| 24 | method | `IStorageService.getSessionsInDateRange` |
| 31 | method | `IStorageService.saveRoutine` |
| 32 | method | `IStorageService.getAllRoutines` |
| 33 | method | `IStorageService.getRoutine` |
| 34 | method | `IStorageService.deleteRoutine` |
| 38 | method | `IStorageService.saveTarget` |
| 39 | method | `IStorageService.getAllTargets` |
| 40 | method | `IStorageService.getTarget` |
| 41 | method | `IStorageService.deleteTarget` |
| 42 | method | `IStorageService.getTargetsForExercise` |
| 46 | method | `IStorageService.updateMuscleGroupGrowthRate` |
| 47 | method | `IStorageService.getAllMuscleGroups` |
| 48 | method | `IStorageService.getMuscleGroup` |
| 52 | method | `IStorageService.saveCustomExercise` |
| 53 | method | `IStorageService.getCustomExercises` |
| 54 | method | `IStorageService.deleteCustomExercise` |
| 55 | method | `IStorageService.getAllExercises` |
| 56 | method | `IStorageService.getExercise` |
| 60 | method | `IStorageService.saveSetting` |
| 61 | method | `IStorageService.getSetting` |
| 65 | method | `IStorageService.saveTrainingProgram` |
| 66 | method | `IStorageService.getAllTrainingPrograms` |
| 67 | method | `IStorageService.getTrainingProgram` |
| 68 | method | `IStorageService.deleteTrainingProgram` |
| 72 | method | `IStorageService.savePersonalRecord` |
| 73 | method | `IStorageService.getPersonalRecord` |
| 74 | method | `IStorageService.getAllPersonalRecords` |
| 78 | method | `IStorageService.saveConversation` |
| 79 | method | `IStorageService.getAllConversations` |
| 80 | method | `IStorageService.getConversation` |
| 81 | method | `IStorageService.deleteConversation` |
| 85 | method | `IStorageService.exportAllData` |
| 86 | method | `IStorageService.importData` |
| 90 | method | `IStorageService.getQuickStats` |

## workout-logger/lib/services/managers/active_workout_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 34 | constructor | `ActiveWorkoutManager` |
| 37 | getter | `ActiveWorkoutManager.hasActiveWorkout` |
| 38 | getter | `ActiveWorkoutManager.activeRoutine` |
| 39 | getter | `ActiveWorkoutManager.currentExerciseIndex` |
| 40 | getter | `ActiveWorkoutManager.currentExerciseLogs` |
| 42 | getter | `ActiveWorkoutManager.workoutStartTime` |
| 43 | getter | `ActiveWorkoutManager.totalExercises` |
| 44 | getter | `ActiveWorkoutManager.isLastExercise` |
| 46 | getter | `ActiveWorkoutManager.isFirstExercise` |
| 48 | getter | `ActiveWorkoutManager.currentExerciseLog` |
| 57 | getter | `ActiveWorkoutManager.currentExerciseId` |
| 60 | method | `ActiveWorkoutManager.startWorkout` |
| 95 | method | `ActiveWorkoutManager.addSet` |
| 112 | method | `ActiveWorkoutManager.removeLastSet` |
| 130 | method | `ActiveWorkoutManager.updateCurrentExerciseNotes` |
| 145 | method | `ActiveWorkoutManager.nextExercise` |
| 156 | method | `ActiveWorkoutManager.previousExercise` |
| 167 | method | `ActiveWorkoutManager.goToExercise` |
| 175 | method | `ActiveWorkoutManager.finishWorkout` |
| 222 | method | `ActiveWorkoutManager.cancelWorkout` |
| 228 | method | `ActiveWorkoutManager._resetState` |

## workout-logger/lib/services/managers/analytics_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 55 | constructor | `AnalyticsManager` |
| 58 | getter | `AnalyticsManager.growthModels` |
| 60 | method | `AnalyticsManager.buildSessionIndex` |
| 92 | method | `AnalyticsManager.getGrowthModel` |
| 95 | method | `AnalyticsManager.trainAllGrowthModels` |
| 117 | method | `AnalyticsManager.updateGrowthModel` |
| 137 | method | `AnalyticsManager.updateGrowthModelsForExercises` |
| 151 | method | `AnalyticsManager.getRecommendations` |
| 226 | method | `AnalyticsManager._fallbackLookupFrom` |
| 238 | method | `AnalyticsManager.getVolumeProgression` |
| 282 | method | `AnalyticsManager.getWeeklyVolumeByMuscle` |
| 320 | method | `AnalyticsManager.getQuickStats` |

## workout-logger/lib/services/managers/conversation_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 25 | constructor | `ConversationManager` |
| 27 | getter | `ConversationManager.conversations` |
| 30 | getter | `ConversationManager.active` |
| 34 | getter | `ConversationManager.activeMessages` |
| 37 | method | `ConversationManager.loadConversations` |
| 45 | method | `ConversationManager.startNewConversation` |
| 52 | method | `ConversationManager.selectConversation` |
| 60 | method | `ConversationManager.appendMessage` |
| 90 | method | `ConversationManager.renameConversation` |
| 104 | method | `ConversationManager.deleteConversation` |
| 114 | method | `ConversationManager._upsert` |
| 121 | method | `ConversationManager._deriveTitle` |

## workout-logger/lib/services/managers/exercise_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 34 | constructor | `ExerciseManager` |
| 37 | getter | `ExerciseManager.allExercises` |
| 38 | getter | `ExerciseManager.customExercises` |
| 40 | getter | `ExerciseManager.builtInExercises` |
| 43 | method | `ExerciseManager.loadExercises` |
| 50 | method | `ExerciseManager.getExercise` |
| 56 | method | `ExerciseManager.getExerciseName` |
| 61 | method | `ExerciseManager.getMuscleGroupName` |
| 66 | method | `ExerciseManager.addCustomExercise` |
| 124 | method | `ExerciseManager.updateExercise` |
| 188 | method | `ExerciseManager.deleteCustomExercise` |
| 215 | method | `ExerciseManager.getExercisesByMuscleGroup` |
| 225 | method | `ExerciseManager.getExercisesByCategory` |
| 235 | method | `ExerciseManager.searchExercises` |

## workout-logger/lib/services/managers/health_history_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 26 | constructor | `HealthHistoryManager` |
| 30 | method | `HealthHistoryManager.dateKey` |
| 35 | method | `HealthHistoryManager._midnight` |
| 37 | method | `HealthHistoryManager.rangeFor` |
| 59 | method | `HealthHistoryManager.stepBy` |
| 74 | method | `HealthHistoryManager._granted` |
| 76 | method | `HealthHistoryManager.workoutHr` |
| 85 | method | `HealthHistoryManager.sleepNight` |
| 91 | method | `HealthHistoryManager.hrDay` |
| 113 | method | `HealthHistoryManager._readCachedHrDay` |
| 125 | method | `HealthHistoryManager.sleepBars` |
| 195 | method | `HealthHistoryManager.hrBars` |
| 257 | method | `HealthHistoryManager._rangeBar` |
| 277 | method | `HealthHistoryManager._weekdayLabel` |
| 278 | method | `HealthHistoryManager._monthLabel` |
| 289 | method | `_StageTally.add` |

## workout-logger/lib/services/managers/health_sync_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 32 | constructor | `HealthSyncManager` |
| 35 | method | `HealthSyncManager.syncSession` |
| 60 | method | `HealthSyncManager._resolveExerciseNames` |

## workout-logger/lib/services/managers/history_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 31 | constructor | `HistoryManager` |
| 38 | getter | `HistoryManager.sessions` |
| 39 | getter | `HistoryManager.totalSessions` |
| 41 | method | `HistoryManager.loadSessions` |
| 49 | method | `HistoryManager.addSession` |
| 73 | method | `HistoryManager.syncSession` |
| 85 | method | `HistoryManager.syncAllUnsynced` |
| 103 | method | `HistoryManager._onHcSynced` |
| 114 | method | `HistoryManager.getSession` |
| 120 | method | `HistoryManager.getSessionsForExercise` |
| 129 | method | `HistoryManager.getSessionsInDateRange` |
| 145 | method | `HistoryManager.getRecentSessions` |
| 151 | method | `HistoryManager.deleteSession` |
| 172 | method | `HistoryManager.updateSession` |
| 209 | method | `HistoryManager.evictSession` |
| 217 | method | `HistoryManager.patchSession` |
| 226 | method | `HistoryManager.getLastSessionForExercise` |

## workout-logger/lib/services/managers/managers.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/services/managers/pr_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | constructor | `NewPRResult` |
| 26 | constructor | `PRManager` |
| 28 | method | `PRManager.load` |
| 36 | getter | `PRManager.allRecords` |
| 49 | method | `PRManager.backfillFromSessions` |
| 59 | method | `PRManager.getRecord` |
| 71 | method | `PRManager.checkAndUpdatePRs` |
| 114 | method | `PRManager._checkExercise` |

## workout-logger/lib/services/managers/program_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 19 | getter | `ProgramManager.programs` |
| 21 | constructor | `ProgramManager` |
| 25 | method | `ProgramManager.loadPrograms` |
| 32 | method | `ProgramManager.saveProgram` |
| 43 | method | `ProgramManager.createProgram` |
| 64 | method | `ProgramManager.deleteProgram` |
| 72 | method | `ProgramManager.importFromJson` |
| 91 | method | `ProgramManager.exportToJson` |
| 99 | method | `ProgramManager.getProgramById` |

## workout-logger/lib/services/managers/readiness_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 40 | getter | `ReadinessManager.sleepHrSnapshot` |
| 42 | getter | `ReadinessManager.hrDaySnapshot` |
| 49 | getter | `ReadinessManager.debugTrace` |
| 51 | constructor | `ReadinessManager` |
| 58 | getter | `ReadinessManager.status` |
| 61 | getter | `ReadinessManager.snapshot` |
| 64 | method | `ReadinessManager.refresh` |
| 206 | method | `ReadinessManager._buildSleepHrSnapshot` |
| 214 | method | `ReadinessManager._buildHrDaySnapshot` |
| 221 | method | `ReadinessManager._setNoData` |
| 227 | method | `ReadinessManager._loadSnapshot` |
| 239 | method | `ReadinessManager._baselineFor` |
| 307 | method | `ReadinessManager._nightlySleepMinutes` |
| 321 | method | `ReadinessManager._dailyAverages` |
| 333 | method | `ReadinessManager._lastNightSleepMinutes` |
| 354 | method | `ReadinessManager._todayRestingHr` |
| 384 | method | `ReadinessManager._todayHrv` |

## workout-logger/lib/services/managers/routine_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 25 | constructor | `RoutineManager` |
| 28 | getter | `RoutineManager.routines` |
| 29 | getter | `RoutineManager.totalRoutines` |
| 31 | method | `RoutineManager.loadRoutines` |
| 37 | method | `RoutineManager.getRoutine` |
| 43 | method | `RoutineManager.createRoutine` |
| 61 | method | `RoutineManager.updateRoutine` |
| 75 | method | `RoutineManager.deleteRoutine` |
| 82 | method | `RoutineManager.isExerciseUsedInRoutines` |
| 87 | method | `RoutineManager.getRoutinesWithExercise` |

## workout-logger/lib/services/managers/target_manager.dart

| Line | Kind | Declaration |
|---|---|---|
| 37 | constructor | `TargetManager` |
| 40 | getter | `TargetManager.targets` |
| 41 | getter | `TargetManager.totalTargets` |
| 42 | getter | `TargetManager.activeTargets` |
| 44 | getter | `TargetManager.completedTargets` |
| 47 | method | `TargetManager.loadTargets` |
| 53 | method | `TargetManager.getTargetsForExercise` |
| 58 | method | `TargetManager.updateGrowthModel` |
| 63 | method | `TargetManager.getGrowthModel` |
| 66 | method | `TargetManager.createTarget` |
| 118 | method | `TargetManager.recalculateTargets` |
| 161 | method | `TargetManager.deleteTarget` |
| 168 | method | `TargetManager.isExerciseUsedInTargets` |

## workout-logger/lib/services/ml_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 28 | constructor | `MLService` |
| 36 | method | `MLService.trainGrowthModel` |
| 42 | method | `MLService.extractExerciseDataPoints` |
| 63 | method | `MLService.extractMuscleDataPoints` |
| 104 | method | `MLService.computeMuscleRecoveryScores` |
| 115 | method | `MLService.lastTrainedPerMuscle` |
| 121 | method | `MLService.recoveryScoresFrom` |
| 144 | method | `MLService.recommendSets` |
| 195 | function | `compatible` |
| 207 | function | `normalize` |
| 243 | method | `MLService._recommendComparableSets` |
| 358 | method | `MLService.getDefaultRecommendations` |
| 385 | method | `MLService.predictTargetCompletion` |

## workout-logger/lib/services/platform_io.dart

| Line | Kind | Declaration |
|---|---|---|
| 3 | function | `getPlatformName` |

## workout-logger/lib/services/platform_stub.dart

| Line | Kind | Declaration |
|---|---|---|
| 1 | function | `getPlatformName` |

## workout-logger/lib/services/release_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 11 | constructor | `ReleaseService` |
| 21 | method | `ReleaseService.changelog` |
| 33 | method | `ReleaseService._fetchChangelog` |
| 51 | method | `ReleaseService.releases` |
| 60 | method | `ReleaseService._fetch` |
| 103 | method | `ReleaseService.changesSince` |
| 120 | method | `ReleaseService.updateFor` |

## workout-logger/lib/services/settings_provider.dart

| Line | Kind | Declaration |
|---|---|---|
| 40 | getter | `SettingsProvider.weightUnit` |
| 41 | getter | `SettingsProvider.weightIncrement` |
| 42 | getter | `SettingsProvider.unitLabel` |
| 43 | getter | `SettingsProvider.healthConnectEnabled` |
| 44 | getter | `SettingsProvider.readinessEnabled` |
| 45 | getter | `SettingsProvider.userName` |
| 46 | getter | `SettingsProvider.userGender` |
| 47 | getter | `SettingsProvider.needsGenderSelection` |
| 48 | getter | `SettingsProvider.bodyFigure` |
| 50 | getter | `SettingsProvider.lastSeenVersion` |
| 51 | getter | `SettingsProvider.geminiApiKey` |
| 52 | getter | `SettingsProvider.geminiModel` |
| 53 | getter | `SettingsProvider.geminiMaxToolRounds` |
| 54 | getter | `SettingsProvider.geminiThinkingLevel` |
| 55 | getter | `SettingsProvider.weeklyInsights` |
| 56 | getter | `SettingsProvider.weeklyInsightsDate` |
| 57 | getter | `SettingsProvider.showAdvancedMetrics` |
| 58 | getter | `SettingsProvider.userBodyWeight` |
| 60 | constructor | `SettingsProvider` |
| 62 | method | `SettingsProvider.init` |
| 116 | method | `SettingsProvider._isKnownGeminiModel` |
| 120 | method | `SettingsProvider._isValidBodyWeight` |
| 124 | method | `SettingsProvider.setUserBodyWeight` |
| 131 | method | `SettingsProvider.setUserGender` |
| 138 | method | `SettingsProvider.setUserName` |
| 144 | method | `SettingsProvider.markVersionSeen` |
| 150 | method | `SettingsProvider.getCurrentVersion` |
| 160 | getter | `SettingsProvider._defaultIncrement` |
| 162 | method | `SettingsProvider.setWeightUnit` |
| 173 | method | `SettingsProvider.setWeightIncrement` |
| 179 | method | `SettingsProvider.setHealthConnectEnabled` |
| 185 | method | `SettingsProvider.setReadinessEnabled` |
| 191 | method | `SettingsProvider.setGeminiModel` |
| 226 | method | `SettingsProvider.setGeminiMaxToolRounds` |
| 237 | method | `SettingsProvider.setGeminiThinkingLevel` |
| 247 | method | `SettingsProvider.setGeminiApiKey` |
| 253 | method | `SettingsProvider.setShowAdvancedMetrics` |
| 259 | method | `SettingsProvider.saveWeeklyInsights` |
| 270 | method | `SettingsProvider.toDisplay` |
| 276 | method | `SettingsProvider.toStorage` |
| 282 | method | `SettingsProvider.formatWeight` |
| 291 | getter | `SettingsProvider.availableIncrements` |

## workout-logger/lib/services/sqlite_storage_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | constructor | `SqliteStorageService` |
| 201 | getter | `SqliteStorageService.databasePath` |
| 205 | method | `SqliteStorageService.close` |
| 211 | method | `SqliteStorageService.init` |
| 356 | method | `SqliteStorageService._seedDefaultMuscleGroups` |
| 371 | method | `SqliteStorageService.saveWorkoutSession` |
| 439 | method | `SqliteStorageService._loadSessions` |
| 527 | method | `SqliteStorageService.getAllWorkoutSessions` |
| 530 | method | `SqliteStorageService.getWorkoutSession` |
| 536 | method | `SqliteStorageService.deleteWorkoutSession` |
| 561 | method | `SqliteStorageService.getSessionsForExercise` |
| 569 | method | `SqliteStorageService.getSessionsInDateRange` |
| 584 | method | `SqliteStorageService.saveRoutine` |
| 609 | method | `SqliteStorageService._loadRoutineRow` |
| 632 | method | `SqliteStorageService.getAllRoutines` |
| 642 | method | `SqliteStorageService.getRoutine` |
| 649 | method | `SqliteStorageService.deleteRoutine` |
| 663 | method | `SqliteStorageService.saveTarget` |
| 678 | method | `SqliteStorageService._targetFromRow` |
| 691 | method | `SqliteStorageService.getAllTargets` |
| 697 | method | `SqliteStorageService.getTarget` |
| 703 | method | `SqliteStorageService.deleteTarget` |
| 708 | method | `SqliteStorageService.getTargetsForExercise` |
| 720 | method | `SqliteStorageService.updateMuscleGroupGrowthRate` |
| 733 | method | `SqliteStorageService._muscleGroupFromRow` |
| 740 | method | `SqliteStorageService.getAllMuscleGroups` |
| 746 | method | `SqliteStorageService.getMuscleGroup` |
| 758 | method | `SqliteStorageService.saveCustomExercise` |
| 786 | method | `SqliteStorageService._loadCustomExerciseRow` |
| 827 | method | `SqliteStorageService.getCustomExercises` |
| 837 | method | `SqliteStorageService.getBuiltInExerciseOverrides` |
| 847 | method | `SqliteStorageService.deleteCustomExercise` |
| 859 | method | `SqliteStorageService.getAllExercises` |
| 876 | method | `SqliteStorageService.getExercise` |
| 887 | method | `SqliteStorageService.saveSetting` |
| 895 | method | `SqliteStorageService.getSetting` |
| 907 | method | `SqliteStorageService.saveTrainingProgram` |
| 922 | method | `SqliteStorageService._programFromRow` |
| 938 | method | `SqliteStorageService.getAllTrainingPrograms` |
| 947 | method | `SqliteStorageService.getTrainingProgram` |
| 957 | method | `SqliteStorageService.deleteTrainingProgram` |
| 964 | method | `SqliteStorageService._prValues` |
| 975 | method | `SqliteStorageService.savePersonalRecord` |
| 984 | method | `SqliteStorageService._prFromRow` |
| 995 | method | `SqliteStorageService.getPersonalRecord` |
| 1015 | method | `SqliteStorageService.getAllPersonalRecords` |
| 1023 | method | `SqliteStorageService.saveConversation` |
| 1037 | method | `SqliteStorageService._conversationFromRow` |
| 1048 | method | `SqliteStorageService.getAllConversations` |
| 1054 | method | `SqliteStorageService.getConversation` |
| 1064 | method | `SqliteStorageService.deleteConversation` |
| 1071 | method | `SqliteStorageService.getQuickStats` |
| 1100 | method | `SqliteStorageService.upsertHealthSamples` |
| 1122 | method | `SqliteStorageService.upsertSleepSessions` |
| 1157 | method | `SqliteStorageService._normalizeImportItem` |
| 1171 | method | `SqliteStorageService.exportAllData` |
| 1207 | method | `SqliteStorageService.importData` |

## workout-logger/lib/services/storage_backend_resolver.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | function | `resolveStorageBackend` |

## workout-logger/lib/services/storage_migration_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `StorageMigrationService` |
| 17 | method | `StorageMigrationService.migrate` |

## workout-logger/lib/services/storage_service.dart

| Line | Kind | Declaration |
|---|---|---|
| 48 | method | `StorageService.init` |
| 103 | method | `StorageService._initializeDefaultMuscleGroups` |
| 112 | method | `StorageService.saveWorkoutSession` |
| 117 | method | `StorageService.getAllWorkoutSessions` |
| 127 | method | `StorageService.getWorkoutSession` |
| 134 | method | `StorageService.deleteWorkoutSession` |
| 139 | method | `StorageService.getSessionsForExercise` |
| 149 | method | `StorageService.getSessionsInDateRange` |
| 168 | method | `StorageService.saveRoutine` |
| 173 | method | `StorageService.getAllRoutines` |
| 182 | method | `StorageService.getRoutine` |
| 189 | method | `StorageService.deleteRoutine` |
| 196 | method | `StorageService.saveTarget` |
| 201 | method | `StorageService.getAllTargets` |
| 210 | method | `StorageService.getTarget` |
| 217 | method | `StorageService.deleteTarget` |
| 222 | method | `StorageService.getTargetsForExercise` |
| 230 | method | `StorageService.updateMuscleGroupGrowthRate` |
| 247 | method | `StorageService.getAllMuscleGroups` |
| 256 | method | `StorageService.getMuscleGroup` |
| 265 | method | `StorageService.saveCustomExercise` |
| 273 | method | `StorageService.getCustomExercises` |
| 282 | method | `StorageService.deleteCustomExercise` |
| 287 | method | `StorageService.getAllExercises` |
| 295 | method | `StorageService.getExercise` |
| 313 | method | `StorageService.saveSetting` |
| 318 | method | `StorageService.getSetting` |
| 323 | method | `StorageService.getAllSettingsForMigration` |
| 337 | method | `StorageService._normalizeExportValue` |
| 348 | method | `StorageService._normalizeImportItem` |
| 369 | method | `StorageService.exportAllData` |
| 405 | method | `StorageService.importData` |
| 530 | method | `StorageService.saveTrainingProgram` |
| 538 | method | `StorageService.getAllTrainingPrograms` |
| 548 | method | `StorageService.getTrainingProgram` |
| 555 | method | `StorageService.deleteTrainingProgram` |
| 562 | method | `StorageService.savePersonalRecord` |
| 570 | method | `StorageService.getPersonalRecord` |
| 584 | method | `StorageService.getAllPersonalRecords` |
| 595 | method | `StorageService.saveConversation` |
| 603 | method | `StorageService.getAllConversations` |
| 614 | method | `StorageService.getConversation` |
| 621 | method | `StorageService.deleteConversation` |
| 628 | method | `StorageService.getQuickStats` |

## workout-logger/lib/services/strategies/growth_curve_fitter.dart

| Line | Kind | Declaration |
|---|---|---|
| 23 | method | `IGrowthCurveFitter.fit` |
| 28 | method | `IGrowthCurveFitter.predictTargetCompletion` |
| 62 | method | `GrowthCurveFitter.fit` |
| 112 | method | `GrowthCurveFitter._robustWeightedFit` |
| 149 | method | `GrowthCurveFitter._weightedLeastSquares` |
| 208 | method | `GrowthCurveFitter._median` |
| 216 | method | `GrowthCurveFitter.predictTargetCompletion` |
| 245 | method | `GrowthCurveFitter.predictTargetWithConfidence` |
| 290 | constructor | `_Fit` |

## workout-logger/lib/services/strategies/progression_rules.dart

| Line | Kind | Declaration |
|---|---|---|
| 40 | getter | `ProgressionContext.isTimeBased` |
| 43 | constructor | `ProgressionContext` |
| 63 | method | `ProgressionRule.apply` |
| 68 | constructor | `UnderRecoveredRule` |
| 70 | method | `UnderRecoveredRule.apply` |
| 96 | constructor | `PostDeloadRecoveryRule` |
| 98 | method | `PostDeloadRecoveryRule.apply` |
| 128 | constructor | `ReadinessRule` |
| 130 | method | `ReadinessRule.apply` |
| 158 | constructor | `SessionFatigueRule` |
| 160 | method | `SessionFatigueRule.apply` |
| 185 | constructor | `DeclineDeloadRule` |
| 187 | method | `DeclineDeloadRule.apply` |
| 216 | constructor | `PlateauRule` |
| 218 | method | `PlateauRule.apply` |
| 249 | constructor | `DoubleProgressionRule` |
| 251 | method | `DoubleProgressionRule.apply` |
| 354 | method | `ProgressionRuleFactory._defaults` |
| 364 | method | `ProgressionRuleFactory.reset` |
| 372 | getter | `ProgressionRuleFactory.rules` |
| 375 | method | `ProgressionRuleFactory.registerRuleAtHead` |
| 381 | method | `ProgressionRuleFactory.apply` |

## workout-logger/lib/services/strategies/target_calculator.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | method | `TargetCalculatorStrategy.calculate` |
| 19 | function | `_getExerciseLogsForExercise` |
| 37 | method | `RepsTargetCalculator.calculate` |
| 54 | method | `WeightTargetCalculator.calculate` |
| 70 | method | `VolumeTargetCalculator.calculate` |
| 95 | method | `TargetCalculatorFactory.reset` |
| 106 | method | `TargetCalculatorFactory.getCalculator` |
| 113 | method | `TargetCalculatorFactory.registerCalculator` |
| 124 | getter | `TargetCalculatorFactory.supportedTypes` |
| 127 | method | `TargetCalculatorFactory.calculateCurrentValue` |

## workout-logger/lib/services/utils/effort_calibration.dart

| Line | Kind | Declaration |
|---|---|---|
| 14 | constructor | `EffortCalibration` |
| 22 | method | `EffortCalibration.updateOffset` |

## workout-logger/lib/services/utils/effort_estimator.dart

| Line | Kind | Declaration |
|---|---|---|
| 41 | constructor | `HrEffortSignal` |
| 50 | constructor | `EffortEstimator` |
| 88 | method | `EffortEstimator.estimate` |
| 204 | method | `EffortEstimator._median` |

## workout-logger/lib/services/utils/exercise_history.dart

| Line | Kind | Declaration |
|---|---|---|
| 4 | function | `findMostRecentExerciseLog` |
| 32 | function | `recoveryRecommendationInputs` |
| 69 | function | `comparableExerciseLogs` |
| 91 | function | `latestLoadReferences` |

## workout-logger/lib/services/utils/hc_session_builder.dart

| Line | Kind | Declaration |
|---|---|---|
| 60 | function | `hcSegmentTypeFor` |
| 69 | function | `buildHcSegments` |
| 111 | function | `massOf` |
| 164 | function | `buildHcNotes` |
| 203 | function | `_formatKg` |

## workout-logger/lib/services/utils/readiness_calculator.dart

| Line | Kind | Declaration |
|---|---|---|
| 12 | constructor | `ReadinessCalculator` |
| 30 | method | `ReadinessCalculator.lastNightSleepMinutes` |
| 49 | method | `ReadinessCalculator.lastNightSleep` |
| 57 | method | `ReadinessCalculator.compute` |
| 117 | method | `ReadinessCalculator._sleepScore` |
| 128 | method | `ReadinessCalculator._rhrScore` |
| 135 | method | `ReadinessCalculator._hrvScore` |
| 141 | method | `ReadinessCalculator._adverse` |
| 143 | method | `ReadinessCalculator.dateKey` |

## workout-logger/lib/services/utils/recovery_calculator.dart

| Line | Kind | Declaration |
|---|---|---|
| 16 | constructor | `RecoveryCalculator` |
| 39 | method | `RecoveryCalculator.computeMuscleRecoveryScores` |
| 56 | method | `RecoveryCalculator.lastTrainedPerMuscle` |
| 80 | method | `RecoveryCalculator.recoveryScoresFrom` |
| 110 | method | `RecoveryCalculator.muscleVolumes` |

## workout-logger/lib/services/utils/session_fatigue.dart

| Line | Kind | Declaration |
|---|---|---|
| 42 | constructor | `SessionFatigueAccumulator` |
| 60 | method | `SessionFatigueAccumulator.factorFor` |

## workout-logger/lib/services/utils/sleep_hr_builder.dart

| Line | Kind | Declaration |
|---|---|---|
| 15 | function | `buildSleepHrSnapshot` |
| 61 | function | `stageAt` |
| 138 | function | `buildHrDaySnapshot` |

## workout-logger/lib/services/utils/workout_hr_builder.dart

| Line | Kind | Declaration |
|---|---|---|
| 17 | function | `buildWorkoutHrAnalysis` |
| 64 | function | `_timestampsValid` |
| 78 | function | `_buildExerciseSpans` |
| 97 | function | `_buildCurve` |
| 116 | function | `_buildRests` |
| 125 | function | `maxIn` |
| 132 | function | `minIn` |

## workout-logger/lib/services/workout_provider.dart

| Line | Kind | Declaration |
|---|---|---|
| 36 | constructor | `WorkoutInProgressError` |
| 71 | method | `WorkoutProvider._invalidateHistoryCache` |
| 74 | method | `WorkoutProvider._historyDerived` |
| 101 | getter | `WorkoutProvider.sessions` |
| 102 | getter | `WorkoutProvider.routines` |
| 103 | getter | `WorkoutProvider.targets` |
| 104 | getter | `WorkoutProvider.muscleGroups` |
| 105 | getter | `WorkoutProvider.allExercises` |
| 107 | getter | `WorkoutProvider.hasActiveWorkout` |
| 109 | getter | `WorkoutProvider.activeRoutine` |
| 110 | getter | `WorkoutProvider.activeProgramDay` |
| 111 | getter | `WorkoutProvider.activeProgramWeek` |
| 112 | getter | `WorkoutProvider.currentExerciseIndex` |
| 113 | getter | `WorkoutProvider.currentExerciseLogs` |
| 114 | getter | `WorkoutProvider.workoutStartTime` |
| 116 | getter | `WorkoutProvider.effortCalibrationOffset` |
| 121 | constructor | `WorkoutProvider` |
| 138 | method | `WorkoutProvider.init` |
| 145 | method | `WorkoutProvider.loadAllData` |
| 159 | method | `WorkoutProvider._trainAllGrowthModels` |
| 175 | method | `WorkoutProvider._updateGrowthModel` |
| 188 | method | `WorkoutProvider._persistDraft` |
| 219 | method | `WorkoutProvider._enqueueDraftWrite` |
| 226 | method | `WorkoutProvider._clearDraft` |
| 236 | method | `WorkoutProvider._restoreDraftIfAny` |
| 327 | method | `WorkoutProvider.getExercise` |
| 335 | method | `WorkoutProvider.getExerciseName` |
| 339 | method | `WorkoutProvider.getMuscleGroupName` |
| 348 | method | `WorkoutProvider.addCustomExercise` |
| 409 | method | `WorkoutProvider.updateExercise` |
| 471 | method | `WorkoutProvider.deleteCustomExercise` |
| 486 | function | `addReference` |
| 538 | method | `WorkoutProvider.startWorkout` |
| 569 | method | `WorkoutProvider.startWorkoutSafely` |
| 601 | getter | `WorkoutProvider.currentExercise` |
| 611 | getter | `WorkoutProvider.currentExerciseLog` |
| 620 | method | `WorkoutProvider.setExerciseHandle` |
| 640 | method | `WorkoutProvider.addSet` |
| 658 | method | `WorkoutProvider.removeLastSet` |
| 676 | method | `WorkoutProvider.nextExercise` |
| 687 | method | `WorkoutProvider.previousExercise` |
| 698 | method | `WorkoutProvider.goToExercise` |
| 709 | method | `WorkoutProvider.finishWorkout` |
| 764 | method | `WorkoutProvider.cancelWorkout` |
| 779 | method | `WorkoutProvider.getRecommendations` |
| 851 | method | `WorkoutProvider.getRecentSessionsForExercise` |
| 867 | function | `collect` |
| 891 | method | `WorkoutProvider.getLastSessionForExercise` |
| 900 | function | `find` |
| 921 | method | `WorkoutProvider.deleteWorkoutSession` |
| 960 | method | `WorkoutProvider.updateWorkoutSession` |
| 1013 | method | `WorkoutProvider.recordSessionEffort` |
| 1044 | method | `WorkoutProvider._recordSessionEffort` |
| 1082 | method | `WorkoutProvider._recomputeEffortCalibrationOffset` |
| 1095 | method | `WorkoutProvider._restoreSessionEffort` |
| 1113 | method | `WorkoutProvider.createRoutine` |
| 1130 | method | `WorkoutProvider.updateRoutine` |
| 1139 | method | `WorkoutProvider.deleteRoutine` |
| 1147 | method | `WorkoutProvider.createTarget` |
| 1181 | method | `WorkoutProvider._recalculateTargets` |
| 1222 | method | `WorkoutProvider._calculateCurrentTargetValue` |
| 1263 | method | `WorkoutProvider._updateTargetsFromSession` |
| 1271 | method | `WorkoutProvider.deleteTarget` |
| 1279 | method | `WorkoutProvider.getVolumeProgression` |
| 1288 | method | `WorkoutProvider.hasMixedLoadConventions` |
| 1298 | method | `WorkoutProvider.getWeeklyVolumeByMuscle` |
| 1334 | method | `WorkoutProvider.getMuscleRecoveryScores` |
| 1340 | method | `WorkoutProvider.getMuscleGrowthModels` |
| 1361 | method | `WorkoutProvider.getGrowthModel` |
| 1364 | method | `WorkoutProvider.estimateOneRM` |
| 1371 | method | `WorkoutProvider.getBestOneRM` |
| 1384 | method | `WorkoutProvider.getBestHold` |
| 1402 | method | `WorkoutProvider.getMuscleExerciseBreakdown` |
| 1450 | method | `WorkoutProvider.getSetProgression` |
| 1489 | method | `WorkoutProvider.getRecentMuscleSessionSummaries` |
| 1518 | method | `WorkoutProvider.getMuscleWeeklyVolumeSeries` |
| 1559 | method | `WorkoutProvider.getQuickStats` |
| 1565 | method | `WorkoutProvider.exportAllData` |
| 1569 | method | `WorkoutProvider.importData` |
| 1574 | method | `WorkoutProvider.refreshAfterImport` |

## workout-logger/lib/theme/a2ui_app_theme.dart

| Line | Kind | Declaration |
|---|---|---|


## workout-logger/lib/theme/app_theme.dart

| Line | Kind | Declaration |
|---|---|---|
| 7 | constructor | `AppColors._` |
| 67 | method | `AppColors.primaryGlow` |
| 69 | method | `AppColors.secondaryGlow` |
| 71 | method | `AppColors.accentGlow` |
| 73 | method | `AppColors.successGlow` |
| 75 | method | `AppColors.warningGlow` |
| 79 | method | `AppColors.muscle` |
| 105 | constructor | `AppTheme._` |
| 122 | method | `AppTheme.getMuscleColor` |
| 124 | getter | `AppTheme.darkTheme` |
| 237 | method | `AppTheme._buildTextTheme` |
| 308 | constructor | `AppSpacing._` |
| 318 | constructor | `AppRadius._` |
| 331 | constructor | `AppDurations._` |
| 349 | constructor | `AppBreakpoints._` |
| 355 | method | `AppBreakpoints.hPadding` |
| 361 | method | `AppBreakpoints.gridColumns` |
| 363 | method | `AppBreakpoints.chartHeight` |
| 365 | method | `AppBreakpoints.timerRingSize` |

## workout-logger/lib/viewmodels/ai_coach_view_model.dart

| Line | Kind | Declaration |
|---|---|---|
| 33 | getter | `AiCoachViewModel.canRetry` |
| 36 | method | `AiCoachViewModel.retry` |
| 41 | method | `AiCoachViewModel._clearFailure` |
| 55 | constructor | `AiCoachViewModel` |
| 68 | method | `AiCoachViewModel.dispose` |
| 76 | getter | `AiCoachViewModel.isConfigured` |
| 77 | getter | `AiCoachViewModel.isLoading` |
| 78 | getter | `AiCoachViewModel.streamingText` |
| 80 | getter | `AiCoachViewModel.streamingToolCalls` |
| 81 | getter | `AiCoachViewModel.messages` |
| 82 | getter | `AiCoachViewModel.conversations` |
| 83 | getter | `AiCoachViewModel.activeConversationId` |
| 84 | getter | `AiCoachViewModel.pendingImageBytes` |
| 85 | getter | `AiCoachViewModel.hasPendingImage` |
| 89 | method | `AiCoachViewModel.loadConversations` |
| 92 | method | `AiCoachViewModel.newConversation` |
| 99 | method | `AiCoachViewModel.selectConversation` |
| 106 | method | `AiCoachViewModel.deleteConversation` |
| 120 | method | `AiCoachViewModel.pickImage` |
| 178 | method | `AiCoachViewModel.clearPendingImage` |
| 185 | method | `AiCoachViewModel.setPendingImageForTesting` |
| 192 | method | `AiCoachViewModel.sendMessage` |
| 196 | method | `AiCoachViewModel._sendMessage` |
| 299 | method | `AiCoachViewModel._recordAndDispatch` |
| 309 | method | `AiCoachViewModel._buildSystemPrompt` |
| 314 | method | `AiCoachViewModel._buildHistory` |

## workout-logger/lib/viewmodels/routine_optimizer_view_model.dart

| Line | Kind | Declaration |
|---|---|---|
| 33 | constructor | `RoutineOptimizerViewModel` |
| 45 | method | `RoutineOptimizerViewModel.dispose` |
| 55 | method | `RoutineOptimizerViewModel._notify` |
| 61 | getter | `RoutineOptimizerViewModel.isConfigured` |
| 62 | getter | `RoutineOptimizerViewModel.isLoading` |
| 63 | getter | `RoutineOptimizerViewModel.streamingText` |
| 64 | getter | `RoutineOptimizerViewModel.pendingQuestions` |
| 65 | getter | `RoutineOptimizerViewModel.messages` |
| 66 | getter | `RoutineOptimizerViewModel.conversations` |
| 67 | getter | `RoutineOptimizerViewModel.activeConversationId` |
| 71 | method | `RoutineOptimizerViewModel.loadConversations` |
| 73 | method | `RoutineOptimizerViewModel.selectConversation` |
| 78 | method | `RoutineOptimizerViewModel.deleteConversation` |
| 81 | method | `RoutineOptimizerViewModel.startForRoutine` |
| 89 | method | `RoutineOptimizerViewModel.submitAnswers` |
| 112 | method | `RoutineOptimizerViewModel.sendMessage` |
| 173 | method | `RoutineOptimizerViewModel._routeToolCall` |
| 180 | method | `RoutineOptimizerViewModel._handleAskUserQuestions` |
| 207 | method | `RoutineOptimizerViewModel._buildHistory` |
