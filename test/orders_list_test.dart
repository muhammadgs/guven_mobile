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
import 'package:guven_mobile/src/features/database/domain/orders_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/order_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/orders_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Sifarişlər` as the user meets it: the design's card, shut and open, the
/// order's own figures asked for once, the next page on its way before the
/// reader gets there, the funnel's five columns — on every phone.
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
    testWidgets('a shut card is the design\'s, row for row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Sifarişlər'), findsOneWidget);
      final Finder first = find.byType(OrderCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card — `Satışlar`' and `Stok`'s — and
      // 122.9pt tall, the design's numbers on its own 402pt frame.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(122.93, epsilon: 0.25));

      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));

      // Every row on the design's baseline, measured off its frame.
      void onBaseline(String text, double design) {
        expect(inCard(text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      onBaseline('NT000007303', 25.4);
      onBaseline('6,720.00 ₼', 67.75);
      onBaseline('Çatdırıldı', 101.97);
      onBaseline('Ödənilib', 101.97);

      // The date on the number's line, ending on the content's right edge;
      // the second flag 91pt after the first, as the design sets it.
      expect(
        tester.getRect(inCard('2026-09-18')).right,
        moreOrLessEquals(card.right - 23, epsilon: 0.5),
      );
      expect(
        tester.getRect(inCard('Ödənilib')).left -
            tester.getRect(inCard('Çatdırıldı')).left,
        moreOrLessEquals(91, epsilon: 0.01),
      );
      // Shut, it shows nothing only an open card has.
      expect(inCard('Cəmi məbləğ:'), findsNothing);
      expect(inCard('Endirim:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an open card is the design\'s, and says what the bridge '
        'does not', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder first = find.byType(OrderCard).first;

      await tester.tap(first);
      await tester.pumpAndSettle();
      final Rect card = tester.getRect(first);
      expect(card.height, moreOrLessEquals(283.9, epsilon: 0.25));

      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));

      void onBaseline(Finder text, double design, String reason) {
        expect(
          _baseline(tester, text) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: reason,
        );
      }

      onBaseline(inCard('NT000007303'), 25.4, 'number');
      onBaseline(inCard('Cəmi məbləğ:'), 54.03, 'Cəmi məbləğ');
      onBaseline(inCard('6,720.00 ₼'), 80.15, 'amount');
      onBaseline(inCard('Endirim:'), 116.72, 'Endirim');
      onBaseline(inCard('Vergi:'), 116.72, 'Vergi');
      onBaseline(inCard('Ödənilən:'), 182.88, 'Ödənilən');
      onBaseline(inCard('Qalıq borc:'), 182.88, 'Qalıq borc');
      final Finder figures = inCard('0.00 ₼');
      // Endirim, Vergi, Ödənilən: the order's own answer's zeros.
      expect(figures, findsNWidgets(3));
      onBaseline(figures.at(0), 144.54, 'Endirim figure');
      onBaseline(figures.at(1), 144.54, 'Vergi figure');
      onBaseline(figures.at(2), 210.55, 'Ödənilən figure');
      onBaseline(inCard('Çatdırıldı'), 259.87, 'flags');

      // `Qalıq borc` is sent by neither of the bridge's answers: unknown,
      // not zero.
      expect(inCard('—'), findsOneWidget);
      onBaseline(inCard('—'), 210.55, 'Qalıq borc figure');

      // The right-hand column where the design starts it.
      expect(
        tester.getRect(inCard('Vergi:')).left - card.left,
        moreOrLessEquals(208, epsilon: 0.01),
      );
      expect(bridge.details, <int>[7303]);

      // Shut again, and opened again: nothing more is asked for.
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(122.93, epsilon: 0.25),
      );
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(bridge.details, <int>[7303]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new, unpaid order wears the website\'s colours', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      final Finder second = find.byType(OrderCard).at(1);

      Color ink(String text) => tester
          .widget<Text>(find.descendant(of: second, matching: find.text(text)))
          .style!
          .color!;

      expect(ink('Yeni'), kOrderUnderway);
      expect(ink('Ödənilməyib'), kSalePending);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byType(OrderCard).first,
                matching: find.text('Çatdırıldı'),
              ),
            )
            .style!
            .color,
        kSaleDone,
      );
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      await tester.drag(_list(), const Offset(0, -700));
      await tester.pump();
      expect(bridge.pages, <int>[1]);

      await tester.drag(_list(), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list never stretches at its ends', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      expect(
        find.descendant(
          of: find.byType(OrdersList),
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
      expect(find.byType(OrderCard), findsWidgets);
    });

    testWidgets('an order whose own answer fails says so on the card, and '
        'asks again', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge()..failDetail = true;
      await _pump(tester, bridge);
      final Finder first = find.byType(OrderCard).first;

      await tester.tap(first);
      await tester.pumpAndSettle();
      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));
      expect(inCard('Server xətası'), findsOneWidget);
      // Four figures nobody knows.
      expect(inCard('—'), findsNWidgets(4));

      bridge.failDetail = false;
      await tester.tap(inCard('Yenidən cəhd et'));
      await tester.pumpAndSettle();
      expect(inCard('Server xətası'), findsNothing);
      expect(inCard('0.00 ₼'), findsNWidgets(3));
      // The retry did not shut the card.
      expect(inCard('Endirim:'), findsOneWidget);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens Sifarişlər\' five columns', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final OrdersColumn column in OrdersColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Status narrows the list behind, and the funnel counts it', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Status'));
      await tester.pumpAndSettle();
      // The statuses the bridge has orders for, in the website's order.
      expect(_inPanel('Yeni'), findsOneWidget);
      expect(_inPanel('Çatdırıldı'), findsOneWidget);
      expect(_inPanel('Ləğv edildi'), findsNothing);
      expect(_inPanel('Hamısı'), findsOneWidget);

      await tester.tap(_inPanel('Yeni'));
      await tester.pumpAndSettle();
      expect(database.orders.filter.valueOf(OrdersColumn.status), 'new');
      expect(bridge.statuses.last, 'new');

      // Off the glass closes it.
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);

      final Iterable<OrderCard> cards = tester.widgetList<OrderCard>(
        find.byType(OrderCard),
      );
      expect(cards, isNotEmpty);
      expect(cards.every((OrderCard c) => c.order.status == 'new'), isTrue);
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // `Hamısı` lets it go: the list is the list again.
      await _openFilter(tester);
      await tester.tap(_inPanel('Status'));
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('Hamısı'));
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(database.orders.filtered, isNull);
      expect(
        tester
            .widgetList<OrderCard>(find.byType(OrderCard))
            .map((OrderCard c) => c.order.status)
            .toSet(),
        hasLength(greaterThan(1)),
      );
    });

    testWidgets('Tarix reads the table, then lists every day, newest first', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Tarix'));
      await tester.pumpAndSettle();
      expect(database.orders.hasEveryOrder, isTrue);
      expect(_inPanel('2026-09-23'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(DatabaseFilterPanel),
          matching: find.byType(TextField),
        ),
        '18.09',
      );
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('2026-09-18'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();

      final Iterable<OrderCard> cards = tester.widgetList<OrderCard>(
        find.byType(OrderCard),
      );
      expect(cards, isNotEmpty);
      expect(cards.every((OrderCard c) => c.order.date == '2026-09-18'), isTrue);
      expect(find.text('Filterə uyğun sifariş tapılmadı.'), findsNothing);
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
        '${device.name} @ ${fontScale}x — cards fit shut and open, and so do '
        'the five columns',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          void fits(Finder card) {
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

          // The design's order, and the new one with the longest words and
          // the largest amount.
          fits(find.byType(OrderCard).at(0));
          fits(find.byType(OrderCard).at(1));

          // Opened, the second — its figures are the widest there are.
          await tester.tap(find.byType(OrderCard).at(1));
          await tester.pumpAndSettle();
          fits(find.byType(OrderCard).at(1));
          expect(tester.takeException(), isNull);

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
          for (final OrdersColumn column in OrdersColumn.values) {
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
  of: find.byType(OrdersList),
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
  )..select(DatabaseSection.orders);
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

/// The 1C bridge's orders table, sixty deep, highest id first. The first
/// order is the design's; the second a new, unpaid one with the largest
/// amount in the live data.
class _Bridge {
  bool failList = false;
  bool failDetail = false;

  /// The page of every unfiltered list request.
  final List<int> pages = <int>[];

  /// The `status` of every list request that had one.
  final List<String> statuses = <String>[];

  /// The id of every order asked for on its own.
  final List<int> details = <int>[];

  static const int _total = 60;

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': 7303 - i,
    'order_number': 'NT${(7303 - i).toString().padLeft(9, '0')}',
    'order_date': switch (i) {
      0 => '2026-09-18T00:00:00',
      _ => '2026-09-${(23 - i % 6).toString().padLeft(2, '0')}T00:00:00',
    },
    'total_amount': switch (i) {
      0 => 6720.0,
      1 => 36993.59,
      _ => 10.0 + i * 3.17,
    },
    'status': i % 10 == 1 ? 'new' : 'delivered',
    'payment_status': i % 10 == 1 ? 'unpaid' : 'paid',
    'baza_id': 18,
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    final RegExpMatch? one = RegExp(r'/orders/(\d+)$').firstMatch(path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      if (failDetail) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      return _json(<String, Object?>{
        ..._row(7303 - id),
        'customer_id': 127,
        'paid_amount': 0.0,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'company_id': null,
        'is_deleted': false,
      });
    }
    if (!path.endsWith('/orders/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }
    if (failList) {
      return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
    }

    final String? search = query['search'];
    final String? status = query['status'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    if (status != null) statuses.add(status);
    if (search == null && status == null && size == 20) pages.add(page);

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < _total; i++)
        if ((search == null ||
                '${_row(i)['order_number']}'.contains(search)) &&
            (status == null || _row(i)['status'] == status))
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
