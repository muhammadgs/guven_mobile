import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/shared/settled_page_controller.dart';

/// A PageView that can be taken out of the tree, the way the onboarding is
/// when a route is pushed over it.
Widget _host(SettledPageController controller, {required bool mounted}) {
  return MaterialApp(
    home: mounted
        ? PageView(
            controller: controller,
            children: List<Widget>.generate(
              4,
              (int i) => Center(child: Text('page $i')),
            ),
          )
        : const SizedBox.expand(),
  );
}

void main() {
  testWidgets('answers with the initial page before it has ever been laid out',
      (WidgetTester tester) async {
    final SettledPageController controller = SettledPageController();
    addTearDown(controller.dispose);

    expect(controller.settledPage, 0);
  });

  testWidgets('holds the last measured page when the viewport goes away', (
    WidgetTester tester,
  ) async {
    final SettledPageController controller = SettledPageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller, mounted: true));
    controller.jumpToPage(3);
    await tester.pump();
    expect(controller.settledPage, 3);

    // The PageView leaves the tree — the controller keeps its offset but has
    // nothing to measure against any more.
    await tester.pumpWidget(_host(controller, mounted: false));
    expect(controller.hasClients, isFalse);
    expect(
      controller.settledPage,
      3,
      reason: 'falling back to page 0 here is what makes the brand lockup '
          'flash its page-0 size on the way in and out of the login screen',
    );

    // Note this covers the onboarding's case — the PageView keeps its state
    // and only loses its dimensions for a frame. A viewport that is genuinely
    // built afresh starts over from `initialPage`, which is Flutter's own
    // behaviour and not something this controller sets out to undo.
  });

  testWidgets('tracks fractional pages while a swipe is in flight', (
    WidgetTester tester,
  ) async {
    final SettledPageController controller = SettledPageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller, mounted: true));
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('page 0')));
    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();

    expect(controller.settledPage, greaterThan(0));
    expect(controller.settledPage, lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
