import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/sale_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/sales_list.dart';

/// `Satışlar` as the user meets it: the design's cards, the next page on its
/// way before the reader gets there, a card opening into its document — and
/// every card fitting every phone, shut and open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where a card's rows land depends on what its words *measure*, so the
  // measuring has to be done in the real faces. The runner sets every family
  // in its own block font otherwise, far wider than any of these.
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

      expect(find.text('Satışlar'), findsOneWidget);
      final Finder first = find.byType(SaleCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, 157.5pt tall — the design's
      // numbers on its own 402pt frame.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(157.5, epsilon: 1));

      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));
      expect(inCard('NT000000001'), findsOneWidget);
      expect(inCard('2026-09-18'), findsOneWidget);
      expect(
        inCard('FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)'),
        findsOneWidget,
      );
      expect(inCard('Nizami (6-cı Paralel) Anbarı'), findsOneWidget);
      expect(inCard('Qaimə'), findsOneWidget);
      expect(inCard('58.20 AZN'), findsOneWidget);

      // The flags: green when done, red when not.
      expect(_colorOf(tester, inCard('Postlanıb')), kSaleDone);
      expect(_colorOf(tester, inCard('Satılmayıb')), kSalePending);

      // The second flag starts in its own column after a short first one…
      final double contentLeft = card.left + 23;
      expect(
        tester.getRect(inCard('Satılmayıb')).left - contentLeft,
        moreOrLessEquals(93.5, epsilon: 0.01),
      );

      // …and the amount ends on the content's right edge.
      expect(
        tester.getRect(inCard('58.20 AZN')).right,
        moreOrLessEquals(card.right - 23, epsilon: 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long first flag pushes the second on', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge(posted: false));

      final Finder first = find.byType(SaleCard).first;
      final Rect posted = tester.getRect(
        find.descendant(of: first, matching: find.text('Postlanmayıb')),
      );
      final Rect sold = tester.getRect(
        find.descendant(of: first, matching: find.textContaining('Satıl')),
      );
      expect(sold.left - posted.right, moreOrLessEquals(15, epsilon: 0.01));
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Most of the way down page one, two screens short of its end.
      await tester.drag(_list(), const Offset(0, -1200));
      await tester.pump();
      expect(bridge.pages, <int>[1]);

      await tester.drag(_list(), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(find.text('NT000000021'), findsNothing); // not on screen yet
      expect(tester.takeException(), isNull);
    });

    testWidgets('a card opens into its document, fetched once', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder first = find.byType(SaleCard).first;
      final double shut = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(bridge.documents, <int>[1]);

      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));
      for (final String heading in <String>[
        'Müştəri:',
        'Təşkilat:',
        'Menecer:',
        'Anbar:',
        'Məhsul',
        'Miqdar',
        'Qiymət',
        'Cəmi',
      ]) {
        expect(inCard(heading), findsOneWidget, reason: heading);
      }
      expect(inCard('NaTural-İD'), findsOneWidget);
      expect(inCard('S_Vurğun_S1'), findsOneWidget);
      expect(inCard('Beef Tenderloin / Dana Can Əti'), findsOneWidget);
      expect(inCard('1.094'), findsOneWidget);
      expect(inCard('30.00'), findsOneWidget);
      expect(inCard('32.82'), findsOneWidget);
      expect(inCard('27.90'), findsNWidgets(2));

      // The design's open card, less the room it leaves under its table.
      final double open = tester.getSize(first).height;
      expect(open, moreOrLessEquals(417, epsilon: 3));

      // The product wraps inside its own column; the figures stay on one
      // line, centred under their headings.
      final Rect product = tester.getRect(
        inCard('Beef Tenderloin / Dana Can Əti'),
      );
      expect(product.height, greaterThan(20));
      expect(
        tester.getRect(inCard('1.094')).center.dx,
        moreOrLessEquals(
          tester.getRect(inCard('Miqdar')).center.dx,
          epsilon: 0.5,
        ),
      );

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(shut, epsilon: 0.01),
      );
      expect(inCard('Müştəri:'), findsNothing);

      // Opened again: from memory, not from the bridge.
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(bridge.documents, <int>[1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list never stretches at its ends', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      // A blur inside Android's stretch has nothing behind it to sample.
      expect(
        find.descendant(
          of: find.byType(SalesList),
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
      expect(find.byType(SaleCard), findsWidgets);
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
        '${device.name} @ ${fontScale}x — a card fits, shut and open',
        (WidgetTester tester) async {
          // The widest a card gets: both flags red, a seven-figure amount, and
          // a product line whose figures are as long as they come.
          await _pump(
            tester,
            _Bridge(posted: false, amount: 1234567.89, bigLines: true),
            device: device,
            fontScale: fontScale,
          );
          final Finder first = find.byType(SaleCard).first;
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          void fitsInside() {
            final Rect card = tester.getRect(first);
            final Rect content = Rect.fromLTRB(
              card.left + 23 * s - 0.5,
              card.top,
              card.right - 23 * s + 0.5,
              card.bottom,
            );
            final Iterable<Element> texts = find
                .descendant(of: first, matching: find.byType(RichText))
                .evaluate();
            expect(texts, isNotEmpty);
            for (final Element text in texts) {
              final Rect drawn = _drawn(text.renderObject! as RenderBox);
              expect(
                drawn.left >= content.left && drawn.right <= content.right,
                isTrue,
                reason:
                    '"${(text.widget as RichText).text.toPlainText()}" at '
                    '$drawn spills out of $content',
              );
            }
            // The flags never run into the amount.
            final Rect sold = tester.getRect(
              find.descendant(of: first, matching: find.text('Satılmayıb')),
            );
            final Rect amount = _drawn(
              tester.renderObject<RenderBox>(
                find.descendant(
                  of: first,
                  matching: find.text('1,234,567.89 AZN'),
                ),
              ),
            );
            expect(sold.right, lessThanOrEqualTo(amount.left));
          }

          fitsInside();
          await tester.tap(first);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: first, matching: find.text('Təşkilat:')),
            findsOneWidget,
          );
          fitsInside();
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

Finder _list() => find.descendant(
  of: find.byType(SalesList),
  matching: find.byType(Scrollable),
);

Color? _colorOf(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

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
  )..select(DatabaseSection.sales);
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

/// The 1C bridge, sixty documents deep.
class _Bridge {
  _Bridge({this.posted = true, this.amount = 58.2, this.bigLines = false});

  final bool posted;
  final double amount;
  final bool bigLines;

  bool failList = false;
  final List<int> pages = <int>[];
  final List<int> documents = <int>[];

  static const int _total = 60;

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;

    if (!path.contains('/onec-data/sales/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final RegExpMatch? document = RegExp(
      r'/onec-data/sales/(\d+)$',
    ).firstMatch(path);
    if (document != null) {
      documents.add(int.parse(document.group(1)!));
      return _json(<String, Object?>{
        'organization': 'NaTural-İD',
        'lines': bigLines
            ? <Object?>[
                <String, Object?>{
                  'product_name': 'Beef Tenderloin / Dana Can Əti (Premium)',
                  'quantity': 12345.678,
                  'price': 98765.43,
                  'amount': 1219312.33,
                },
              ]
            : <Object?>[
                <String, Object?>{
                  'product_name': 'Beef Tenderloin / Dana Can Əti',
                  'quantity': 1.094,
                  'price': '30.00',
                  'amount': '32.82',
                },
                <String, Object?>{
                  'product_name': 'Tushonka',
                  'quantity': 1,
                  'price': 27.9,
                  'amount': 27.9,
                },
              ],
      });
    }

    if (failList) {
      return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
    }
    final int page = int.parse(request.url.queryParameters['page']!);
    final int size = int.parse(request.url.queryParameters['page_size']!);
    pages.add(page);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int i = start; i < start + size && i < _total; i++)
          <String, Object?>{
            'id': i + 1,
            'order_number': 'NT${(i + 1).toString().padLeft(9, '0')}',
            'order_date': '2026-09-18T00:00:00',
            'customer': 'FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)',
            'manager': 'S_Vurğun_S1',
            'warehouse': 'Nizami (6-cı Paralel) Anbarı',
            'doc_type': 'invoice',
            'total_amount': amount,
            'currency': 'AZN',
            'is_posted': posted,
            'is_sold': false,
          },
      ],
      'total': _total,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
