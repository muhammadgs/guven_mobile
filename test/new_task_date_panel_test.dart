import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/presentation/new_task_metrics.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_picker.dart';

/// The date wheels, and the one thing about them that is easy to get wrong.
///
/// The day column's length changes with the month, and correcting the wheel
/// when it shrinks has to happen *after* the frame: doing it from
/// `didUpdateWidget` moves the scroll position, which reports a new selection,
/// which is a `setState` on the panel — during build. That threw, replaced the
/// day column with an error widget, and shunted the other two wheels along one
/// place on the screen.
void main() {
  testWidgets('31 August survives a move to a 30-day month', (
    WidgetTester tester,
  ) async {
    DateTime? picked;
    await _pump(tester, initial: DateTime(2026, 8, 31), onPick: (DateTime d) {
      picked = d;
    });

    // August has 31 days and September has 30, so this is the shrink.
    await _spinToNextItem(tester, wheel: 1);

    expect(
      tester.takeException(),
      isNull,
      reason: 'the day wheel must be corrected after the frame, not in it',
    );
    expect(find.text('Sentyabr'), findsWidgets);

    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2026, 9, 30));
  });

  testWidgets('the wheels answer with what they are showing', (
    WidgetTester tester,
  ) async {
    DateTime? picked;
    await _pump(tester, initial: DateTime(2026, 8, 10), onPick: (DateTime d) {
      picked = d;
    });

    // One day on, one month on, one year on.
    await _spinToNextItem(tester, wheel: 0);
    await _spinToNextItem(tester, wheel: 1);
    await _spinToNextItem(tester, wheel: 2);

    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2027, 9, 11));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the months are Azerbaijani', (WidgetTester tester) async {
    await _pump(tester, initial: DateTime(2026, 8, 10), onPick: (_) {});

    // The framework's own wheel would say `August` here: this app declares no
    // locales, so `CupertinoLocalizations` resolves to English.
    expect(find.text('Avqust'), findsWidgets);
    expect(find.text('August'), findsNothing);
  });
}

/// Drags one wheel down by exactly one row.
Future<void> _spinToNextItem(
  WidgetTester tester, {
  required int wheel,
}) async {
  final Finder target = find.byType(ListWheelScrollView).at(wheel);
  final double extent = tester
      .widget<ListWheelScrollView>(target)
      .itemExtent;
  await tester.drag(target, Offset(0, -extent));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required DateTime initial,
  required ValueChanged<DateTime> onPick,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) {
          final NewTaskMetrics metrics = NewTaskMetrics.of(
            context,
            button: const Rect.fromLTWH(76, 200, 42, 42),
            menuRows: NewTaskKind.values.length,
          );
          return Stack(
            children: <Widget>[
              NewTaskDatePanel(
                metrics: metrics,
                // A field row halfway down the sheet.
                anchor: Rect.fromLTWH(
                  metrics.sheet.left + metrics.sheetPadH,
                  metrics.sheet.center.dy,
                  metrics.sheet.width - 2 * metrics.sheetPadH,
                  metrics.fieldHeight,
                ),
                flight: const AlwaysStoppedAnimation<double>(1),
                initial: initial,
                onPick: onPick,
              ),
            ],
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
