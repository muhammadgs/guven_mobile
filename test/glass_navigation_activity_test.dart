import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/home/domain/activity.dart';
import 'package:guven_mobile/src/features/home/presentation/widgets/activity_panel.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/guven_glass_bottom_bar.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

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
    for (final AppGlassSurface surface in tester.widgetList<AppGlassSurface>(
      glass,
    )) {
      expect(surface.fake, isFalse);
    }

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

  testWidgets('navbar lens follows drag and fits each label width', (
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
      reason: 'parked, the only glass in the bar is the bar',
    );

    final Finder pill = _pill;
    final Finder selectionGlass = _selectionGlass;
    final Size restSize = tester.getSize(pill);
    expect(restSize.height, lessThan(64 * 0.8));
    final double startX = tester.getCenter(pill).dx;

    final Rect barRect = tester.getRect(bar);
    final TestGesture drag = await tester.startGesture(tester.getCenter(pill));
    await drag.moveBy(const Offset(20, 0));
    await drag.moveTo(Offset(barRect.center.dx, barRect.center.dy));
    // The first frame after a ticker starts only fixes its time base, so the
    // springs need a second one before they have integrated anything.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(selected, 0, reason: 'selection commits only when the finger lifts');
    expect(
      selectionGlass,
      findsOneWidget,
      reason: 'holding the marker turns it into a lens',
    );
    expect(tester.getCenter(selectionGlass).dx, greaterThan(startX + 70));
    if (!kUseLegacyEasyGlass) {
      expect(
        tester.getSize(selectionGlass).height,
        greaterThan(restSize.height),
        reason: 'and swells past the flat marker it grew out of',
      );
      expect(
        tester
            .widget<AppGlassSurface>(selectionGlass)
            .style
            .settings
            .visibility,
        greaterThan(0.4),
      );
      expect(
        _stretch(tester).dx.abs(),
        greaterThan(1),
        reason: 'renderer stretch must deform while the lens is held',
      );
    }

    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(
      selectionGlass,
      findsNothing,
      reason: 'the lens goes away with the finger that asked for it',
    );
    expect(tester.getSize(pill).width, greaterThan(restSize.width + 10));
    if (!kUseLegacyEasyGlass) {
      expect(
        _stretch(tester),
        Offset.zero,
        reason: 'the spring must restore the capsule after release',
      );
    }

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
    expect(
      _stretch(tester).dx.abs(),
      greaterThan(1),
      reason: 'a tap deforms the capsule too, not only a drag',
    );

    await tester.pumpAndSettle();
    expect(tester.getCenter(_pill).dx, greaterThan(midX));
    expect(_stretch(tester), Offset.zero);
    expect(
      _selectionGlass,
      findsNothing,
      reason: 'a tap never leaves the lens behind',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the lens off its rail stands it up and lets it back', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await _pumpBar(tester, onSelected: (int next) => selected = next);

    final TestGesture drag = await tester.startGesture(
      tester.getCenter(_pill),
    );
    // The first move only clears the pan slop; the second is the one that
    // arrives as an update and feeds the pull.
    await drag.moveBy(const Offset(0, -40));
    await drag.moveBy(const Offset(0, -24));
    await tester.pump();

    expect(_stretch(tester).dy, lessThan(-5));
    expect(
      _stretch(tester).dx.abs(),
      lessThan(0.01),
      reason: 'a vertical pull must not drag the selection sideways',
    );

    await drag.up();
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(_stretch(tester), Offset.zero);
    expect(tester.takeException(), isNull);
  });
}

/// The flat marker. Always present — it is what the lens grows out of, and it
/// is only faded out, never removed.
final Finder _pill = find.byKey(const ValueKey<String>('nav-selection-pill'));

/// The lens itself, which exists only while a finger is on the bar.
final Finder _selectionGlass = find.byKey(
  const ValueKey<String>('nav-selection-glass'),
);

/// Both layers carry the same deformation, so either one reports it.
Offset _stretch(WidgetTester tester) => tester
    .widget<renderer.RawLiquidStretch>(
      find.byType(renderer.RawLiquidStretch).first,
    )
    .stretchPixels;

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
