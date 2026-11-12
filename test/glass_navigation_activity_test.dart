import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/home/domain/activity.dart';
import 'package:guven_mobile/src/features/home/presentation/widgets/activity_panel.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/guven_glass_bottom_bar.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';

void main() {
  testWidgets('activity text and its real glass travel together', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<Activity> activities = List<Activity>.generate(
      12,
      (int index) => Activity(
        kind: ActivityKind.task,
        title: 'Activity $index',
        subtitle: 'Owner $index',
        happenedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 390,
            height: 500,
            child: ActivityPanel(
              activities: activities,
              loading: false,
              error: null,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder glass = find.byType(AppGlassSurface);
    expect(glass, findsAtLeastNWidgets(2));

    final Finder rowText = find.text('Activity 2');
    final Finder rowGlass = find.ancestor(
      of: rowText,
      matching: find.byType(AppGlassSurface),
    );
    expect(rowGlass, findsOneWidget);
    final double textTopBefore = tester.getTopLeft(rowText).dy;
    final double glassTopBefore = tester.getTopLeft(rowGlass).dy;

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, -56));
    await tester.pump();

    final double textDelta = tester.getTopLeft(rowText).dy - textTopBefore;
    final double glassDelta = tester.getTopLeft(rowGlass).dy - glassTopBefore;
    expect(textDelta, lessThan(-50));
    expect(glassDelta, closeTo(textDelta, 0.01));
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('navbar marker follows drag and fits each label width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 300,
                height: 64,
                child: GuvenGlassBottomBar(
                  labels: const <String>['A', 'Əməkdaşlar', 'C'],
                  icons: const <String>[
                    'assets/images/icons/nav_icons/home.svg',
                    'assets/images/icons/nav_icons/workers.svg',
                    'assets/images/icons/nav_icons/tasks.svg',
                  ],
                  selectedIndex: selected,
                  onSelected: (int next) {
                    setState(() => selected = next);
                  },
                  height: 64,
                  iconSize: 22,
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );

    final Finder bar = find.byType(GuvenGlassBottomBar);
    final Finder glass = find.descendant(
      of: bar,
      matching: find.byType(AppGlassSurface),
    );
    expect(
      glass,
      findsOneWidget,
      reason: 'the only glass in the bar is the bar',
    );

    final Finder pill = _pill;
    final Size restSize = tester.getSize(pill);
    expect(restSize.height, lessThan(64 * 0.8));
    final double startX = tester.getCenter(pill).dx;

    final Rect barRect = tester.getRect(bar);
    final TestGesture drag = await tester.startGesture(tester.getCenter(pill));
    await drag.moveBy(const Offset(20, 0));
    await drag.moveTo(Offset(barRect.center.dx, barRect.center.dy));
    // The first frame after a ticker starts only fixes its time base, so the
    // spring needs a second one before it has integrated anything.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(selected, 0, reason: 'selection commits only when the finger lifts');
    expect(tester.getCenter(pill).dx, greaterThan(startX + 70));
    expect(
      tester.getSize(pill).height,
      restSize.height,
      reason: 'a held marker stays the same flat marker',
    );
    expect(glass, findsOneWidget, reason: 'and no glass appears under it');

    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.getSize(pill).width, greaterThan(restSize.width + 10));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a tapped cell is travelled to, not teleported to', (
    WidgetTester tester,
  ) async {
    await _pumpBar(tester);

    final double startX = tester.getCenter(_pill).dx;

    // The far cell, so a teleport and a travel are far apart.
    await tester.tapAt(const Offset(295, 32));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final double midX = tester.getCenter(_pill).dx;
    expect(midX, greaterThan(startX + 20), reason: 'the marker set off');
    expect(midX, lessThan(295), reason: 'and is still on its way, not there');

    await tester.pumpAndSettle();
    expect(tester.getCenter(_pill).dx, greaterThan(midX));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vertical drag never moves the selection', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await _pumpBar(tester, onSelected: (int next) => selected = next);
    final Offset start = tester.getCenter(_pill);

    final TestGesture drag = await tester.startGesture(start);
    await drag.moveBy(const Offset(0, -40));
    await drag.moveBy(const Offset(0, -24));
    await tester.pump();
    expect(tester.getCenter(_pill).dx, closeTo(start.dx, 0.01));

    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(tester.getCenter(_pill), start);
    expect(tester.takeException(), isNull);
  });
}

/// The marker under the selected cell.
final Finder _pill = find.byKey(const ValueKey<String>('nav-selection-pill'));

/// A 300pt three-cell bar sitting at the top of a 390pt view, so cell centres
/// land on round numbers.
Future<void> _pumpBar(
  WidgetTester tester, {
  ValueChanged<int>? onSelected,
}) async {
  tester.view.physicalSize = const Size(390, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  int selected = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              height: 64,
              child: GuvenGlassBottomBar(
                labels: const <String>['A', 'B', 'C'],
                icons: const <String>[
                  'assets/images/icons/nav_icons/home.svg',
                  'assets/images/icons/nav_icons/workers.svg',
                  'assets/images/icons/nav_icons/tasks.svg',
                ],
                selectedIndex: selected,
                onSelected: (int next) {
                  onSelected?.call(next);
                  setState(() => selected = next);
                },
                height: 64,
                iconSize: 22,
                textStyle: const TextStyle(fontSize: 10),
              ),
            ),
          );
        },
      ),
    ),
  );
}
