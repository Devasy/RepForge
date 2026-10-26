import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/screens/widgets/rf_shell.dart';
import 'package:repforge/screens/widgets/rf_widgets.dart';
import 'package:repforge/theme/app_theme.dart';

void main() {
  testWidgets('section heading also works inside a parent action row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Row(
            children: [
              const RFSectionHeader('Exercises'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Add exercise')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Exercises'), findsOneWidget);
  });

  testWidgets('long section heading wraps while its action stays reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: RFSectionHeader(
              'Contributing this week',
              trailing: TextButton(
                onPressed: () => opened = true,
                child: const Text('View all'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View all'));
    expect(opened, isTrue);
  });

  testWidgets('screen heading and subtitle remain readable beside controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var wentBack = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: RFScreenHeader(
              title: 'Training history',
              subtitle: 'Your saved workouts and exercises',
              onBack: () => wentBack = true,
              actions: [
                RFIconButton(
                  icon: Icons.search,
                  tooltip: 'Search history',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    expect(wentBack, isTrue);
    expect(find.byTooltip('Search history'), findsOneWidget);
  });

  testWidgets('About identifies RepForge without the old name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: SingleChildScrollView(child: AboutSection(appVersion: '')),
        ),
      ),
    );
    expect(find.text('RepForge'), findsOneWidget);
    expect(find.text('RepForge Workout Logger'), findsNothing);
    expect(find.text('Debug logs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
