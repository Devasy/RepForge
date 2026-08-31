import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_shell.dart';

void main() {
  // The header cannot measure its children before layout, so a centred title
  // is balanced by a counterweight computed from the leading/trailing widths.
  // Every widget that sits in the leading run has to be counted, or the title
  // drifts by half of whatever was missed.
  group('RFScreenHeader centred title', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      IconData? badgeIcon,
      VoidCallback? onBack,
      List<Widget> actions = const [],
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RFScreenHeader(
              title: 'Coach',
              badgeIcon: badgeIcon,
              onBack: onBack,
              actions: actions,
              centreTitle: true,
            ),
          ),
        ),
      );
    }

    void expectTitleCentred(WidgetTester tester) {
      final title = tester.getRect(find.text('Coach'));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(title.center.dx, moreOrLessEquals(screenWidth / 2, epsilon: 0.5));
    }

    testWidgets('lands on true centre with a badge and one action', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        badgeIcon: Icons.auto_awesome_rounded,
        actions: [
          RFIconButton(icon: Icons.more_vert_rounded, tooltip: 'More', onTap: () {}),
        ],
      );
      expectTitleCentred(tester);
    });

    testWidgets('lands on true centre with a back button, badge and action', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        badgeIcon: Icons.auto_awesome_rounded,
        onBack: () {},
        actions: [
          RFIconButton(icon: Icons.more_vert_rounded, tooltip: 'More', onTap: () {}),
        ],
      );
      expectTitleCentred(tester);
    });

    testWidgets('lands on true centre with no badge', (tester) async {
      await pumpHeader(
        tester,
        onBack: () {},
        actions: [
          RFIconButton(icon: Icons.more_vert_rounded, tooltip: 'More', onTap: () {}),
        ],
      );
      expectTitleCentred(tester);
    });
  });
}
