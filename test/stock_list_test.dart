import 'dart:convert';

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
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/stock_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/stock_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/stock_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Stok` as the user meets it: the design's cards, a name taking the lines
/// it needs and the card growing with it, the next page on its way before
/// the reader gets there, the funnel's five columns — on every phone.
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

  group('on the frame it was drawn on', () {
    testWidgets('a card is the design\'s, row for row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Stok'), findsOneWidget);
      final Finder first = find.byType(StockCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, 139pt tall — the design's numbers
      // on its own 402pt frame.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(139, epsilon: 0.25));

      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));

      // Every row on the design's baseline: 25.5, 54.25, 85 and 117pt down
      // the card, measured off its two one-line cards.
      void onBaseline(String text, double design) {
        expect(inCard(text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      onBaseline('NT000001000', 25.5);
      onBaseline('Çanta kraft 28*15 h30 (Natural Meat)', 54.25);
      onBaseline('istehsalat', 85);
      onBaseline('Miqdar: 4,469.891', 117);

      // The date on the number's line, ending on the content's right edge.
      final Rect date = tester.getRect(inCard('2026-09-18'));
      expect(date.right, moreOrLessEquals(card.right - 23, epsilon: 0.5));
      expect(
        _baseline(tester, inCard('2026-09-18')),
        moreOrLessEquals(
          _baseline(tester, inCard('NT000001000')),
          epsilon: 0.01,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name takes the lines it needs, and the card grows by '
        'exactly them', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      final Finder cards = find.byType(StockCard);
      final double one = tester.getSize(cards.at(0)).height;
      final Finder long = find.descendant(
        of: cards.at(1),
        // 1C's own spacing — doubled, and trailing — set as one space, the
        // way the design and the website show it.
        matching: find.text(
          'Beef Şuba Fhink Flank UKR / Donmuş (mal əti) Qabırğa üstü '
          'sümüksüz UKR (P)',
        ),
      );
      expect(long, findsOneWidget);
      final RenderParagraph name = tester.renderObject(long);
      expect(name.didExceedMaxLines, isFalse);

      // Two CalSans lines where the first card has one: 18pt more, and the
      // rows under the name move down by just that.
      expect(tester.getSize(long).height, moreOrLessEquals(36, epsilon: 0.01));
      expect(
        tester.getSize(cards.at(1)).height,
        moreOrLessEquals(one + 18, epsilon: 0.01),
      );
    });

    testWidgets('a name is one line at the least', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      final Finder cards = find.byType(StockCard);
      final Finder nameless = cards.at(2);
      expect(
        find.descendant(of: nameless, matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        tester.getSize(nameless).height,
        moreOrLessEquals(tester.getSize(cards.at(0)).height, epsilon: 0.01),
      );
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      await tester.drag(_list(), const Offset(0, -900));
      await tester.pump();
      expect(bridge.pages, <int>[1]);

      await tester.drag(_list(), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a card has nothing to open', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(StockCard).first;
      final double height = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, height);
    });

    testWidgets('the list never stretches at its ends', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      expect(
        find.descendant(
          of: find.byType(StockList),
          matching: find.byType(StretchingOverscrollIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('a bridge that answers nothing says so, and tries again', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge()..failList = true;
      await _pump(tester, bridge);

      expect(find.text('Server xətası'), findsOneWidget);
      bridge.failList = false;
      await tester.tap(find.text('Yenidən cəhd et'));
      await tester.pumpAndSettle();
      expect(find.byType(StockCard), findsWidgets);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens Stok\'s five columns', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final StockColumn column in StockColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      // `Satışlar`' columns are not these.
      expect(_inPanel('Müştəri'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a warehouse narrows the list behind, and the funnel counts '
        'it', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Anbar'));
      await tester.pumpAndSettle();
      // The catalogue, with its spacing tidied.
      expect(_inPanel('Nizami (6-cı Paralel) Anbarı'), findsOneWidget);
      expect(_inPanel('Hamısı'), findsOneWidget);

      await tester.tap(_inPanel('Ulduz Anbarı'));
      await tester.pumpAndSettle();
      expect(
        database.stock.filter.valueOf(StockColumn.warehouse),
        'Ulduz Anbarı',
      );
      expect(bridge.searches.last, 'Ulduz Anbarı');

      // Off the glass closes it.
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);

      final Iterable<StockCard> cards = tester.widgetList<StockCard>(
        find.byType(StockCard),
      );
      expect(cards, isNotEmpty);
      expect(
        cards.every((StockCard c) => c.item.warehouse == 'Ulduz Anbarı'),
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // `Hamısı` lets it go: the list is the list again.
      await _openFilter(tester);
      await tester.tap(_inPanel('Anbar'));
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('Hamısı'));
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(database.stock.filtered, isNull);
      expect(
        tester
            .widgetList<StockCard>(find.byType(StockCard))
            .map((StockCard c) => c.item.warehouse)
            .toSet(),
        hasLength(greaterThan(1)),
      );
    });

    testWidgets('Miqdar offers the website\'s two levels', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);
      await tester.tap(_inPanel('Miqdar'));
      await tester.pumpAndSettle();

      expect(_inPanel('10-dan çox'), findsOneWidget);
      expect(_inPanel('10 və daha az'), findsOneWidget);
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
        '${device.name} @ ${fontScale}x — every card fits, and so do the '
        'five columns',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          // The one-line card, the two-line one, and the nameless one.
          for (int i = 0; i < 3; i++) {
            final Finder card = find.byType(StockCard).at(i);
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

          // The funnel's five columns, every one on the glass.
          await _openFilter(tester);
          final double margin = DatabaseFilterMetrics.kMargin * s;
          final Rect band = Rect.fromLTRB(
            margin - 0.01,
            device.insets.top + margin - 0.01,
            device.size.width - margin + 0.01,
            device.size.height - device.insets.bottom - margin + 0.01,
          );
          final Rect glass = tester.getRect(
            find.descendant(
              of: find.byType(DatabaseFilterPanel),
              matching: find.byType(AppGlassSurface),
            ),
          );
          expect(
            band.contains(glass.topLeft) && band.contains(glass.bottomRight),
            isTrue,
            reason: 'the columns $glass are not inside $band',
          );
          for (final StockColumn column in StockColumn.values) {
            final Rect row = tester.getRect(_inPanel(column.label));
            expect(
              glass.contains(row.topLeft) && glass.contains(row.bottomRight),
              isTrue,
              reason: '${column.label} $row is not on the glass $glass',
            );
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

/// Where [text]'s first line sits on the screen, measured in its own face.
double _baseline(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject(text);
  final TextPainter painter = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  final double baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  painter.dispose();
  return paragraph.localToGlobal(Offset.zero).dy + baseline;
}

Finder _list() => find.descendant(
  of: find.byType(StockList),
  matching: find.byType(Scrollable),
);

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
  )..select(DatabaseSection.stock);
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
  return controller;
}

/// The 1C bridge's stock table, sixty balances deep, the most first. The
/// first three rows are the design's: a one-line name, the longest name in
/// the live data (1C's spacing and all), and a row with no name.
class _Bridge {
  bool failList = false;
  final List<int> pages = <int>[];
  final List<String> searches = <String>[];

  static const int _total = 60;

  static const List<String> _warehouses = <String>[
    'istehsalat',
    'Nərimanov Anbar ',
    'Nizami (6-cı Paralel)  Anbarı',
    'Ulduz Anbarı',
  ];

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': 900 - i,
    'product_code': 'NT${(1000 + i).toString().padLeft(9, '0')}',
    'product_name': switch (i) {
      0 => 'Çanta kraft 28*15 h30 (Natural Meat)',
      1 =>
        'Beef Şuba Fhink Flank UKR / Donmuş (mal əti) Qabırğa üstü '
            'sümüksüz  UKR  (P) ',
      2 => '',
      _ => 'Tabak Kiçik',
    },
    'warehouse': i == 0 ? 'istehsalat' : _warehouses[i % _warehouses.length],
    'quantity': i == 0 ? 4469.891 : 3000.0 - i * 40,
    'balance_date': '2026-09-18',
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    if (path.endsWith('/warehouses/')) {
      return _json(<String, Object?>{
        'data': <Object?>[
          for (final String name in <String>[
            'Nizami (6-cı Paralel)  Anbarı',
            'Nərimanov Anbar ',
            'Ulduz Anbarı',
            'istehsalat',
          ])
            <String, Object?>{'name': name},
        ],
        'total': 4,
      });
    }
    if (!path.endsWith('/onec-data/stock/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }
    if (failList) {
      return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    if (search == null) {
      pages.add(page);
    } else {
      searches.add(search);
    }

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < _total; i++)
        if (search == null ||
            <Object?>[
              _row(i)['product_code'],
              _row(i)['product_name'],
              _row(i)['warehouse'],
            ].any(
              (Object? field) =>
                  '$field'.toLowerCase().contains(search.toLowerCase()),
            ))
          _row(i),
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
