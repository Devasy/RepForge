import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui_component.dart';
import 'package:repforge/genui/a2ui_renderer.dart';
import 'package:repforge/theme/app_theme.dart';

void main() {
  testWidgets('renders stat card and data list payloads', (tester) async {
    final component = A2UiComponent.fromJson({
      'component': 'GridContainer',
      'props': {
        'columns': 1,
        'children': [
          {
            'component': 'StatCard',
            'props': {
              'title': 'Total Volume',
              'value': '12k kg',
              'subtitle': 'Last 30 days',
              'trend': 'up',
            },
          },
          {
            'component': 'DataListGroup',
            'props': {
              'title': 'Top Exercises',
              'items': [
                {
                  'primaryText': 'Bench Press',
                  'secondaryText': '8 working sets',
                  'trailingValue': '3200 kg',
                },
              ],
            },
          },
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: A2UiRenderer(component: component!),
          ),
        ),
      ),
    );

    expect(find.text('Total Volume'), findsOneWidget);
    expect(find.text('12k kg'), findsOneWidget);
    expect(find.text('Top Exercises'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
  });
}
