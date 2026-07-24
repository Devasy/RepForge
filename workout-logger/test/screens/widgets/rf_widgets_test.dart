import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_widgets.dart';
import 'package:repforge/theme/app_theme.dart';

void main() {
  testWidgets('slideRoute creates valid PageRouteBuilder', (tester) async {
    final route = slideRoute(const Text('Slide Page'));
    expect(route, isA<PageRouteBuilder>());
  });

  testWidgets('GlassCard renders child with options', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassCard(
            accentBorder: true,
            glowColor: Colors.purple,
            onTap: () => tapped = true,
            semanticsLabel: 'GlassCardButton',
            child: const Text('Glass Content'),
          ),
        ),
      ),
    );

    expect(find.text('Glass Content'), findsOneWidget);
    await tester.tap(find.text('Glass Content'));
    expect(tapped, isTrue);
  });

  testWidgets('AmbientGlow renders glow effect', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [AmbientGlow()],
          ),
        ),
      ),
    );

    expect(find.byType(AmbientGlow), findsOneWidget);
  });

  testWidgets('GlowButton handles tap and disabled state', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GlowButton(
                label: 'Active Button',
                icon: Icons.add,
                small: true,
                onPressed: () => tapped = true,
              ),
              const GlowButton(
                label: 'Disabled Button',
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Active Button'), findsOneWidget);
    expect(find.text('Disabled Button'), findsOneWidget);

    await tester.tap(find.text('Active Button'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('OutlineGlowButton renders correctly', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutlineGlowButton(
            label: 'Outline',
            icon: Icons.check,
            small: true,
            fullWidth: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Outline'), findsOneWidget);
    await tester.tap(find.text('Outline'));
    expect(tapped, isTrue);
  });

  testWidgets('RFChip, RFSectionHeader, RFStatBox render correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RFChip(label: 'Chest', small: true),
              RFSectionHeader('Workouts', trailing: Text('View all')),
              RFStatBox(value: '100', label: 'Volume', delta: 5.0),
              RFStatBox(value: '50', label: 'Reps', delta: -2.0),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('WORKOUTS'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('AnimatedCounter, MetricHero, RFDivider, RFEmptyState render correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const AnimatedCounter(value: 42.5, decimals: 1, suffix: 'kg'),
              const MetricHero(value: '100', unit: 'kg'),
              const RFDivider(indent: 16),
              RFEmptyState(
                icon: Icons.fitness_center,
                title: 'No Workouts',
                subtitle: 'Add a workout to get started',
                action: ElevatedButton(onPressed: () {}, child: const Text('Add')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(find.text('No Workouts'), findsOneWidget);
  });

  testWidgets('RFLoadingDots, RFProgressBar, RestTimerRing, SkeletonBox, RFTextField render correctly', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const RFLoadingDots(color: Colors.blue),
              const RFProgressBar(value: 0.75, height: 8),
              const RestTimerRing(remaining: 90, total: 120),
              const SkeletonBox(width: 100, height: 20),
              RFTextField(
                controller: controller,
                hint: 'Enter text',
                label: 'Field Label',
                prefixIcon: Icons.search,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(RFLoadingDots), findsOneWidget);
    expect(find.byType(RFProgressBar), findsOneWidget);
    expect(find.byType(RestTimerRing), findsOneWidget);
    expect(find.text('Field Label'), findsOneWidget);

    final containerBefore = tester.widget<Container>(
      find.descendant(of: find.byType(RFTextField), matching: find.byType(Container)).first,
    );
    final boxDecBefore = containerBefore.decoration as BoxDecoration;
    final borderBefore = boxDecBefore.border as Border;
    expect(borderBefore.top.color, AppColors.glassBorder);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final containerAfter = tester.widget<Container>(
      find.descendant(of: find.byType(RFTextField), matching: find.byType(Container)).first,
    );
    final boxDecAfter = containerAfter.decoration as BoxDecoration;
    final borderAfter = boxDecAfter.border as Border;
    expect(borderAfter.top.color, AppColors.primary);

    await tester.enterText(find.byType(TextField), 'Test input');
    expect(controller.text, 'Test input');
  });
}
