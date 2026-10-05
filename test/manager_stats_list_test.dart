import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/database/application/database_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/manager_stat.dart';
import 'package:guven_mobile/src/features/database/domain/manager_stats_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/manager_stat_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/manager_stats_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_picker.dart'
    show kAzMonths;
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Menecer statistikası` as the user meets it: the design's card, row for
/// row; a tap opens nothing; the funnel's four columns, `Dövr` a start and
/// an end set on a calendar of months; on every phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where a card's rows land depends on what its words *measure*, so the
  // measuring has to be done in the real faces.
  setUpAll(() async {
    Future<void> family(String name, List<String> files) async {
      final FontLoader loader = FontLoader(name);
      for (final String file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }

    await family('Poppins', <String>[
      'Poppins-Regular.ttf',
      'Poppins-Italic.ttf',
      'Poppins-Medium.ttf',
      'Poppins-SemiBold.ttf',
      'Poppins-Bold.ttf',
    ]);
    await family('CalSans', <String>['CalSans-Regular.ttf']);
    await family('ChakraPetch', <String>['ChakraPetch-Regular.ttf']);
  });

  group('the list', () {
    testWidgets('a month is the design\'s card, row for row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      // The menu's name for the page, under `Baza`.
      expect(find.text('Menecer Statistikası'), findsOneWidget);

      final Finder first = find.byType(ManagerStatCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, on the design's 402pt frame;
      // 163pt tall with a one-line name.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(163, epsilon: 0.25));
      expect(
        tester.getRect(find.byType(ManagerStatCard).at(1)).top - card.bottom,
        moreOrLessEquals(11.5, epsilon: 0.01),
      );

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      void onBaseline(String text, double design) {
        expect(inCard(text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      // The design's baselines, measured at 3.35px a point.
      onBaseline('Mühasib-istehsal', 42.08);
      // The month once: the website's `07.2026 2026` says the year twice.
      onBaseline('Dövr:  07.2026', 71.93);
      onBaseline('Sifariş: 236 sifariş', 103.05);
      onBaseline('Cəmi məbləğ: 218,675.61 ₼', 134.09);

      // The name at the design's 22pt; the month in the tab's figures at
      // 15, the words around it Poppins at 14.
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('Mühasib-istehsal')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(22));
      final TextStyle? month = _styleOf(
        tester,
        inCard('Dövr:  07.2026'),
        '07.2026',
      );
      expect(month!.fontFamily, kDatabaseFigureFont);
      expect(month.fontSize, moreOrLessEquals(15));

      for (final String text in <String>[
        'Mühasib-istehsal',
        'Dövr:  07.2026',
        'Cəmi məbləğ: 218,675.61 ₼',
      ]) {
        expect(
          tester.getRect(inCard(text)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: text,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a figure 1C does not give says so', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      final Finder second = find.byType(ManagerStatCard).at(1);
      for (final String text in <String>[
        'Dövr:  08.2026',
        'Sifariş: —',
        'Cəmi məbləğ: —',
      ]) {
        expect(
          find.descendant(
            of: second,
            matching: find.text(text, findRichText: true),
          ),
          findsOneWidget,
          reason: text,
        );
      }
      // The same card, every row still there.
      expect(
        tester.getSize(second).height,
        moreOrLessEquals(163, epsilon: 0.25),
      );
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(ManagerStatCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens the card\'s four fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final ManagerStatsColumn column in ManagerStatsColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dövr is a start and an end, set on a calendar of months', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);
      await tester.tap(_inPanel('Dövr'));
      await tester.pumpAndSettle();

      // Both ends open; the year of the latest month with figures; twelve
      // months, those with figures in ink.
      expect(_inPanel('Başlanğıc'), findsOneWidget);
      expect(_inPanel('Son'), findsOneWidget);
      expect(_inPanel('2026'), findsOneWidget);
      for (final String month in kAzMonths) {
        expect(_inPanel(month), findsOneWidget, reason: month);
      }
      expect(_inkOf(tester, 'Avqust'), kGlassInk);
      expect(_inkOf(tester, 'Mart'), kGlassInkMuted);
      // The year turns back whether or not a year has figures — the user's
      // rule — and on no further than this year.
      expect(_enabled(tester, 'Əvvəlki il'), isTrue);
      expect(_enabled(tester, 'Növbəti il'), DateTime.now().year > 2026);

      // December 2025 is the start …
      await tester.tap(find.bySemanticsLabel('Əvvəlki il'));
      await tester.pumpAndSettle();
      expect(_inPanel('2025'), findsOneWidget);
      expect(_enabled(tester, 'Əvvəlki il'), isTrue);
      expect(_enabled(tester, 'Növbəti il'), isTrue);

      // A year with no figures at all is reached too: every month pale.
      await tester.tap(find.bySemanticsLabel('Əvvəlki il'));
      await tester.pumpAndSettle();
      expect(_inPanel('2024'), findsOneWidget);
      for (final String month in kAzMonths) {
        expect(_inkOf(tester, month), kGlassInkMuted, reason: month);
      }
      await tester.tap(find.bySemanticsLabel('Növbəti il'));
      await tester.pumpAndSettle();
      expect(_inPanel('2025'), findsOneWidget);
      await tester.tap(_inPanel('Dekabr'));
      await tester.pumpAndSettle();
      expect(_inPanel('Dekabr 2025'), findsOneWidget);
      expect(database.managerStats.filtered, isNotNull);

      // … and the next month tapped is the end.
      await tester.tap(find.bySemanticsLabel('Növbəti il'));
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('Yanvar'));
      await tester.pumpAndSettle();
      expect(_inPanel('Yanvar 2026'), findsOneWidget);
      expect(
        database.managerStats.periodOf(ManagerStatsColumn.period),
        const FilterPeriod(
          from: FilterMonth(2025, 12),
          to: FilterMonth(2026, 1),
        ),
      );

      // An end earlier than the start becomes the start.
      await tester.tap(find.bySemanticsLabel('Əvvəlki il'));
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('Noyabr'));
      await tester.pumpAndSettle();
      expect(
        database.managerStats.periodOf(ManagerStatsColumn.period),
        const FilterPeriod(
          from: FilterMonth(2025, 11),
          to: FilterMonth(2026, 1),
        ),
      );

      // Closed, the list holds those months only, and the funnel says one
      // column is narrowing it.
      await tester.tapAt(const Offset(390, 800));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <String?>{
          for (final ManagerStat stat in database.managerStats.filtered!.rows)
            stat.periodLabel,
        },
        <String>{'01.2026', '12.2025'},
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // Opened again, the start is let go with its cross, and `Hamısı`
      // lets go of the rest.
      await _openFilter(tester);
      await tester.tap(_inPanel('Dövr'));
      await tester.pumpAndSettle();
      expect(_inPanel('Noyabr 2025'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Başlanğıc təmizlə'));
      await tester.pumpAndSettle();
      expect(
        database.managerStats.periodOf(ManagerStatsColumn.period),
        const FilterPeriod(to: FilterMonth(2026, 1)),
      );
      await tester.tap(_inPanel('Hamısı'));
      await tester.pumpAndSettle();
      expect(database.managerStats.isFiltered, isFalse);
      expect(_inPanel('Başlanğıc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Every phone ─────────────────────────────────────────────────────────

  const List<_Device> devices = <_Device>[
    _Device(
      'iPhone 16 Pro',
      Size(402, 874),
      EdgeInsets.only(top: 62, bottom: 34),
    ),
    _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    ),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    ),
    _Device(
      'S23 3-button',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 48),
    ),
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  for (final _Device device in devices) {
    for (final double fontScale in <double>[1.0, 1.2]) {
      testWidgets(
        '${device.name} @ ${fontScale}x — cards fit, and so do the four '
        'columns and the calendar',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          final int built = find.byType(ManagerStatCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(ManagerStatCard).at(i);
            final Rect box = tester.getRect(card);
            final Rect content = Rect.fromLTRB(
              box.left + 23 * s - 0.5,
              box.top,
              box.right - 23 * s + 0.5,
              box.bottom,
            );
            for (final Element text
                in find
                    .descendant(of: card, matching: find.byType(RichText))
                    .evaluate()) {
              final RenderParagraph paragraph =
                  text.renderObject! as RenderParagraph;
              final Rect drawn = _drawn(paragraph);
              expect(
                content.contains(drawn.topLeft) &&
                    content.contains(
                      drawn.bottomRight - const Offset(0.01, 0.01),
                    ),
                isTrue,
                reason:
                    '"${paragraph.text.toPlainText()}" at $drawn spills out '
                    'of $content',
              );
              expect(paragraph.didExceedMaxLines, isFalse);
            }
          }
          expect(tester.takeException(), isNull);

          await _openFilter(tester);
          final double margin = DatabaseFilterMetrics.kMargin * s;
          final Rect band = Rect.fromLTRB(
            margin - 0.01,
            device.insets.top + margin - 0.01,
            device.size.width - margin + 0.01,
            device.size.height - device.insets.bottom - margin + 0.01,
          );
          Rect glass() => tester.getRect(
            find.descendant(
              of: find.byType(DatabaseFilterPanel),
              matching: find.byType(AppGlassSurface),
            ),
          );
          void inside(Rect outer, Rect inner, String what) {
            expect(
              outer.contains(inner.topLeft) &&
                  outer.contains(inner.bottomRight - const Offset(0.01, 0.01)),
              isTrue,
              reason: '$what $inner is not inside $outer',
            );
          }

          inside(band, glass(), 'the columns');
          for (final ManagerStatsColumn column in ManagerStatsColumn.values) {
            inside(
              glass(),
              tester.getRect(_inPanel(column.label)),
              column.label,
            );
          }

          // The calendar: both ends, the year and all twelve months on the
          // glass at once, with nothing to scroll to.
          await tester.tap(_inPanel('Dövr'));
          await tester.pumpAndSettle();
          inside(band, glass(), 'the calendar');
          for (final String text in <String>[
            'Başlanğıc',
            'Son',
            'Hamısı',
            '2026',
            ...kAzMonths,
          ]) {
            inside(glass(), _drawn(tester.renderObject(_inPanel(text))), text);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The style [word] is drawn in, inside the rich [text].
TextStyle? _styleOf(WidgetTester tester, Finder text, String word) {
  TextStyle? found;
  tester.widget<RichText>(text).text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == word) {
      found = span.style;
      return false;
    }
    return true;
  });
  return found;
}

/// The colour a month of the calendar is written in.
Color? _inkOf(WidgetTester tester, String month) =>
    tester.widget<Text>(_inPanel(month)).style?.color;

/// Whether the year arrow called [label] can be pressed.
bool _enabled(WidgetTester tester, String label) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .getSemanticsData()
        .flagsCollection
        .isEnabled ==
    Tristate.isTrue;

/// Where [text]'s first line sits on the screen, as it is laid out.
double _baseline(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject(text);
  final double baseline = paragraph.getDryBaseline(
    paragraph.constraints,
    TextBaseline.alphabetic,
  )!;
  return MatrixUtils.transformPoint(
    paragraph.getTransformTo(null),
    Offset(0, baseline),
  ).dy;
}

/// [text] on the filter's glass, not on a card behind it.
Finder _inPanel(String text) => find.descendant(
  of: find.byType(DatabaseFilterPanel),
  matching: find.text(text),
);

Future<void> _openFilter(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Filtr')));
  await tester.pumpAndSettle();
  expect(find.byType(DatabaseFilterPanel), findsOneWidget);
}

class _Device {
  const _Device(this.name, this.size, this.insets);

  final String name;
  final Size size;
  final EdgeInsets insets;
}

Future<DatabaseController> _pump(
  WidgetTester tester,
  _Bridge bridge, {
  _Device device = const _Device(
    'iPhone 16 Pro',
    Size(402, 874),
    EdgeInsets.only(top: 62, bottom: 34),
  ),
  double fontScale = 1.0,
}) async {
  const double ratio = 3;
  tester.view.physicalSize = device.size * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.view.padding = FakeViewPadding(
    top: device.insets.top * ratio,
    bottom: device.insets.bottom * ratio,
  );
  tester.platformDispatcher.textScaleFactorTestValue = fontScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final SessionController session = SessionController();
  addTearDown(session.dispose);
  final DatabaseController controller = DatabaseController(
    session,
    api: DatabaseApi(
      ApiClient(tokens: TokenStore(), httpClient: MockClient(bridge.answer)),
    ),
  )..select(DatabaseSection.managerStats);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        type: MaterialType.transparency,
        child: DatabaseScreen(
          bottomReserve: 110,
          active: true,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ManagerStatsList), findsOneWidget);
  return controller;
}

/// The bridge's monthly figures, thirty deep, in its order. The first is
/// the design's card; the second has no figures at all. After them the
/// months run 08.2026, 01.2026 and 12.2025 in blocks of ten, so the table
/// reaches back over a year's end.
class _Bridge {
  static const int total = 30;

  Map<String, Object?> row(int i) {
    final (int year, int month) = switch (i) {
      0 => (2026, 7),
      _ when i < 10 => (2026, 8),
      _ when i < 20 => (2026, 1),
      _ => (2025, 12),
    };
    return <String, Object?>{
      'id': i + 1,
      'manager_id': 'guid-$i',
      'manager': i == 0 ? 'Mühasib-istehsal' : 'Menecer $i',
      'year': year,
      'month': month,
      'month_label': '${month.toString().padLeft(2, '0')}.$year',
      'orders_count': i == 1 ? null : 236 - i,
      'total_amount': switch (i) {
        0 => 218675.61,
        1 => null,
        _ => 100000.0 - i * 1000,
      },
      'baza_id': 18,
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/onec-data/manager-stats/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < total; i++)
        if (search == null ||
            '${row(i)['manager']}'.toLowerCase().contains(search.toLowerCase()))
          row(i),
    ];
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
      'total': found.length,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
