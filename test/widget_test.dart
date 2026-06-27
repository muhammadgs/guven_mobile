// Smoke test for the pre-login onboarding flow.

import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/app/guven_app.dart';

void main() {
  testWidgets('Onboarding shows the welcome headline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GuvenApp());
    // The headline is in the tree from the first frame (it merely starts at
    // zero opacity), so a short pump is enough to find it. We must not
    // pumpAndSettle — the aurora background animates forever.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Xoş gəlmişsiniz!'), findsOneWidget);

    // Drain the staggered entrance delays (Future.delayed) so no timer is left
    // pending when the widget tree is torn down.
    await tester.pump(const Duration(seconds: 2));
  });
}
