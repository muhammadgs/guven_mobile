import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/shell/data/nav_layout_store.dart';
import 'package:guven_mobile/src/features/shell/domain/shell_destination.dart';
import 'package:guven_mobile/src/features/shell/presentation/main_shell.dart';
import 'package:guven_mobile/src/features/shell/presentation/more_menu_metrics.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/guven_glass_bottom_bar.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/more_menu.dart';

void main() {
  // The marker is sized from its label, so the labels have to be measured in
  // the font they are drawn in — the test font draws every glyph a full em
  // wide.
  setUpAll(() async {
    final Uint8List bytes = await File(
      'assets/fonts/Poppins-Medium.ttf',
    ).readAsBytes();
    final FontLoader loader = FontLoader('Poppins')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  testWidgets('the bar glyphs are drawn at the larger size', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);
    final double scale = 393 / 390;
    final Finder glyphs = find.descendant(
      of: find.byType(GuvenGlassBottomBar),
      matching: find.byType(SvgPicture),
    );
    for (final SvgPicture glyph in tester.widgetList<SvgPicture>(glyphs)) {
      expect(glyph.height, closeTo(28 * scale, 0.01));
    }
  });

  testWidgets('Daha çox fans its pages out one by one, in order, and back', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);
    expect(find.byType(MoreMenuDisc), findsNothing);
    final MoreMenuMetrics m = _metrics(tester);

    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    // The first button is on its way; the last has not left yet.
    final double first = (_disc(tester, ShellDestination.partners) - m.origin)
        .distance;
    final double last = (_disc(tester, ShellDestination.database) - m.origin)
        .distance;
    expect(first, greaterThan(20));
    expect(last, lessThan(2));

    await tester.pumpAndSettle();
    final List<ShellDestination> fan = ShellNavLayout.defaults.more;
    for (int i = 0; i < fan.length; i++) {
      final Offset at = _disc(tester, fan[i]);
      expect(at.dx, closeTo(m.center(i).dx, 0.5), reason: fan[i].title);
      expect(at.dy, closeTo(m.center(i).dy, 0.5), reason: fan[i].title);
    }
    // Five on the outer arc, every one of them above the inner three.
    for (int outer = 0; outer < 5; outer++) {
      for (int inner = 5; inner < 8; inner++) {
        expect(_disc(tester, fan[outer]).dy,
            lessThan(_disc(tester, fan[inner]).dy + 48));
        expect(tester.getRect(find.text(fan[outer].title)).bottom,
            lessThan(tester.getRect(find.text(fan[inner].title)).top));
      }
    }

    // The marker has gone to Daha çox, and its glyph is down to outlines.
    expect(tester.getCenter(_pill).dx,
        closeTo(tester.getCenter(_barText('Daha çox')).dx, 1));
    expect(_menuOutlineOpacity(tester), 1);

    // A tap on the dimmed screen puts everything back.
    await tester.tapAt(const Offset(196, 120));
    await tester.pumpAndSettle();
    expect(find.byType(MoreMenuDisc), findsNothing);
    expect(_menuOutlineOpacity(tester), 0);
    _expectPillOn(tester, 'Əsas səhifə');
  });

  testWidgets('a second tap on Daha çox, or back, shuts the fan', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MoreMenuDisc), findsNothing);

    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MoreMenuDisc), findsNothing);
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('a fan button opens its page, marked by Daha çox', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sənədlər'));
    await tester.pumpAndSettle();

    expect(find.text('page:documents'), findsOneWidget);
    expect(find.text('page:home'), findsNothing);
    expect(find.byType(MoreMenuDisc), findsNothing);
    expect(tester.getCenter(_pill).dx,
        closeTo(tester.getCenter(_barText('Daha çox')).dx, 1));

    await tester.tap(_barText('Tapşırıqlar'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('page:tasks'), findsOneWidget);
    _expectPillOn(tester, 'Tapşırıqlar');
  });

  testWidgets('a fan button dragged onto the bar trades places with a cell', (
    WidgetTester tester,
  ) async {
    final MemoryNavLayoutStore store = await _pumpShell(tester);
    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final MoreMenuMetrics m = _metrics(tester);

    final TestGesture drag = await tester.startGesture(m.center(5)); // Board
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(tester.getCenter(_barText('Şirkətlər')));
    await tester.pump();

    // Mid-drag the trade is already shown: Şirkətlər waits in Board's slot.
    expect(
      find.descendant(of: find.byType(MoreMenu), matching: find.text('Şirkətlər')),
      findsOneWidget,
    );

    await drag.up();
    await tester.pumpAndSettle();

    expect(_barLabels(tester), <String>[
      'Board',
      'Əməkdaşlar',
      'Daha çox',
      'Əsas səhifə',
      'Tapşırıqlar',
    ]);
    final Offset companies = _disc(tester, ShellDestination.companies);
    expect(companies.dx, closeTo(m.center(5).dx, 0.5));
    expect(companies.dy, closeTo(m.center(5).dy, 0.5));
    expect(store.saved?.bar.first, ShellDestination.board);
    expect(store.saved?.more[5], ShellDestination.companies);

    // The fan stays open for the next arrangement.
    expect(find.byType(MoreMenuDisc), findsNWidgets(8));
  });

  testWidgets('bar cells can be rearranged, and the marker still fits its '
      'own label', (WidgetTester tester) async {
    final MemoryNavLayoutStore store = await _pumpShell(tester);
    final double homeWidth = tester.getSize(_pill).width;

    final TestGesture drag = await tester.startGesture(
      tester.getCenter(_barText('Tapşırıqlar')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(tester.getCenter(_barText('Şirkətlər')));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(_barLabels(tester), <String>[
      'Tapşırıqlar',
      'Şirkətlər',
      'Daha çox',
      'Əməkdaşlar',
      'Əsas səhifə',
    ]);
    expect(store.saved?.bar.first, ShellDestination.tasks);

    // The page on screen has not changed, and the marker followed its cell
    // at the width of that cell's own label.
    expect(find.text('page:home'), findsOneWidget);
    _expectPillOn(tester, 'Əsas səhifə');
    expect(tester.getSize(_pill).width, closeTo(homeWidth, 0.01));
  });

  testWidgets('let go away from any slot and the button goes home', (
    WidgetTester tester,
  ) async {
    final MemoryNavLayoutStore store = await _pumpShell(tester);
    await tester.tap(_barText('Daha çox'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final MoreMenuMetrics m = _metrics(tester);

    final TestGesture drag = await tester.startGesture(m.center(5));
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(const Offset(196, 100));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(store.saved, isNull);
    expect(_barLabels(tester).first, 'Şirkətlər');
    final Offset board = _disc(tester, ShellDestination.board);
    expect(board.dx, closeTo(m.center(5).dx, 0.5));
    expect(board.dy, closeTo(m.center(5).dy, 0.5));
  });

  // Every page can be put in the bar, so the marker has to fit its own name
  // and stay off its neighbours' for any row of five — not only the default.
  const Map<String, List<ShellDestination>> rows =
      <String, List<ShellDestination>>{
        'default': <ShellDestination>[
          ShellDestination.companies,
          ShellDestination.employees,
          ShellDestination.home,
          ShellDestination.tasks,
        ],
        // The row that was reported: a long name at the end, a longer one
        // beside it.
        'reported': <ShellDestination>[
          ShellDestination.employees,
          ShellDestination.protocols,
          ShellDestination.home,
          ShellDestination.database,
        ],
        // The three longest names, as close together as the bar allows.
        'longest': <ShellDestination>[
          ShellDestination.departments,
          ShellDestination.institutions,
          ShellDestination.protocols,
          ShellDestination.employees,
        ],
        'mixed': <ShellDestination>[
          ShellDestination.institutions,
          ShellDestination.partners,
          ShellDestination.settings,
          ShellDestination.departments,
        ],
      };
  const List<Size> screens = <Size>[
    Size(393, 852),
    Size(360, 780),
    Size(320, 568),
  ];

  for (final Size screen in screens) {
    for (final double fontScale in <double>[1.0, 1.2]) {
      for (final MapEntry<String, List<ShellDestination>> row in rows.entries) {
        testWidgets('${row.key} row, ${screen.width.toInt()}pt @ ${fontScale}x '
            '— every marker holds its name and clears its neighbours', (
          WidgetTester tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = fontScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final List<ShellDestination> more = <ShellDestination>[
            for (final ShellDestination d in ShellDestination.values)
              if (!row.value.contains(d)) d,
          ];
          await _pumpShell(
            tester,
            size: screen,
            saved: ShellNavLayout(bar: row.value, more: more),
          );

          final List<String> labels = _barLabels(tester);
          final Rect bar = tester.getRect(find.byType(GuvenGlassBottomBar));
          final double slot = bar.width / labels.length;
          for (int cell = 0; cell < labels.length; cell++) {
            await tester.tapAt(
              Offset(bar.left + slot * (cell + 0.5), bar.center.dy),
            );
            await tester.pumpAndSettle();

            final Rect pill = tester.getRect(_pill);
            final Rect own = tester.getRect(_barText(labels[cell]));
            final String at = '${labels[cell]} selected';
            expect(pill.left, greaterThanOrEqualTo(bar.left + 2.9), reason: at);
            expect(pill.right, lessThanOrEqualTo(bar.right - 2.9), reason: at);
            // Its own name sits well inside it, clear of the rounded ends.
            expect(own.left - pill.left, greaterThanOrEqualTo(9.9), reason: at);
            expect(pill.right - own.right, greaterThanOrEqualTo(9.9),
                reason: at);
            for (final int n in <int>[cell - 1, cell + 1]) {
              if (n < 0 || n >= labels.length) continue;
              final Rect other = tester.getRect(_barText(labels[n]));
              expect(pill.inflate(3.5).overlaps(other), isFalse,
                  reason: '$at: the marker reaches `${labels[n]}`');
            }
          }

          // The default row and the reported one need no name visibly shrunk
          // on the canvas phone — the reported one gives up under a point —
          // and only the longest names ever give way by more.
          if (screen.width == 393 &&
              fontScale == 1.0 &&
              (row.key == 'default' || row.key == 'reported')) {
            for (final String label in labels) {
              expect(tester.getRect(_barText(label)).width,
                  greaterThan(tester.getSize(_barText(label)).width * 0.98),
                  reason: '`$label` was scaled down');
            }
          }
        });
      }
    }
  }

  testWidgets('a saved arrangement is what the bar opens with', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      saved: ShellNavLayout.defaults.moved(
        const NavSlot(NavShelf.more, 6),
        const NavSlot(NavShelf.bar, 1),
      ),
    );
    expect(_barLabels(tester)[1], 'Tənzimləmə');
  });
}

Future<MemoryNavLayoutStore> _pumpShell(
  WidgetTester tester, {
  ShellNavLayout? saved,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final MemoryNavLayoutStore store = MemoryNavLayoutStore(saved);
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        store: store,
        pageBuilder: (ShellDestination page, double reserve) =>
            Center(child: Text('page:${page.name}')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

MoreMenuMetrics _metrics(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(MainShell));
  return MoreMenuMetrics.of(
    context,
    bar: MainShell.barRect(context),
    count: ShellNavLayout.defaults.more.length,
  );
}

final Finder _pill = find.byKey(const ValueKey<String>('nav-selection-pill'));

/// The marker sits under [label] and is wide enough for it. On an end cell it
/// is pulled in to stay inside the bar, so it is not always centred on it.
void _expectPillOn(WidgetTester tester, String label) {
  final Rect pill = tester.getRect(_pill);
  final Rect text = tester.getRect(_barText(label));
  expect(pill.left, lessThanOrEqualTo(text.left), reason: label);
  expect(pill.right, greaterThanOrEqualTo(text.right), reason: label);
}

Finder _barText(String label) => find.descendant(
  of: find.byType(GuvenGlassBottomBar),
  matching: find.text(label),
);

List<String> _barLabels(WidgetTester tester) {
  final List<Element> texts = find
      .descendant(
        of: find.byType(GuvenGlassBottomBar),
        matching: find.byType(Text),
      )
      .evaluate()
      .toList();
  texts.sort(
    (Element a, Element b) => tester
        .getCenter(find.byElementPredicate((Element e) => e == a))
        .dx
        .compareTo(
          tester.getCenter(find.byElementPredicate((Element e) => e == b)).dx,
        ),
  );
  return <String>[for (final Element e in texts) (e.widget as Text).data!];
}

Offset _disc(WidgetTester tester, ShellDestination page) => tester.getCenter(
  find.byWidgetPredicate((Widget w) => w is MoreMenuDisc && w.item == page),
);

double _menuOutlineOpacity(WidgetTester tester) {
  final Finder outline = find.byWidgetPredicate(
    (Widget w) =>
        w is SvgPicture &&
        w.bytesLoader is SvgAssetLoader &&
        (w.bytesLoader as SvgAssetLoader).assetName == kMenuOpenIcon,
  );
  final FadeTransition fade = tester.widget<FadeTransition>(
    find.ancestor(of: outline, matching: find.byType(FadeTransition)).first,
  );
  return fade.opacity.value;
}
