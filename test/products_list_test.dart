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
import 'package:guven_mobile/src/features/database/application/products_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/product.dart';
import 'package:guven_mobile/src/features/database/domain/products_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/product_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/products_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Məhsullar` as the user meets it: the design's card, shut and open, the
/// warehouses asked for once, the next page on its way before the reader
/// gets there, the funnel's nine columns — the price, the stock and the VAT
/// rate a minimum and a maximum rather than a list — on every phone.
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

      expect(find.text('Məhsullar'), findsOneWidget);
      final Finder first = find.byType(ProductCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card — every `Baza` list's — and 138pt
      // tall, the design's numbers on its own 402pt frame.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(138.0, epsilon: 0.25));

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      // Every row on the design's baseline, measured off its frame.
      void onBaseline(String text, double design) {
        expect(inCard(text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      onBaseline('NT000007303', 25.39);
      onBaseline('Biotech Zero Sauce 350 ml BARBECUE', 54.05);
      onBaseline('NM MENU / SOUSLAR', 83.8);
      onBaseline('15.60 ₼ / əd', 113.97);

      // Shut, it shows nothing only an open card has.
      expect(inCard('Məhsul adı:'), findsNothing);
      expect(inCard('Stokda:  26'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an open card is the design\'s, and its warehouses are '
        'asked for once', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder first = find.byType(ProductCard).first;

      await tester.tap(first);
      await tester.pumpAndSettle();
      final Rect card = tester.getRect(first);

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

      // The design's rows: a heading 18.9–20.1pt over its value, and every
      // pair 33.1pt from the next.
      onBaseline('NT000007303', 25.39);
      onBaseline('Məhsul adı:', 57.0);
      onBaseline('Biotech Zero Sauce 350 ml BARBECUE', 75.9);
      onBaseline('Kateqoriya:', 109.0);
      onBaseline('NM MENU / SOUSLAR', 129.1);
      onBaseline('Qiymət / Vahid:', 162.2);
      onBaseline('15.60 ₼ / əd', 182.3);
      onBaseline('Stokda:  26', 215.4);
      onBaseline('Növ:  xammal', 248.5);
      onBaseline('ƏDV:  18%', 281.6);
      onBaseline('Status:  aktiv', 314.7);

      // The table: its heading, and a row every 21.6pt — most first, and
      // each figure on its warehouse's line.
      onBaseline('Anbar', 350.0);
      onBaseline('Miqdar', 350.0);
      onBaseline('istehsalat', 377.6);
      onBaseline('20', 377.6);
      onBaseline('Badamdar Anbar', 399.2);
      onBaseline('6', 399.2);
      onBaseline('Cəmi', 420.8);
      onBaseline('26', 420.8);
      expect(card.height, moreOrLessEquals(446.1, epsilon: 0.25));

      // `Miqdar` at the content's edge, the figures centred under it.
      final Rect heading = tester.getRect(inCard('Miqdar'));
      expect(heading.right, moreOrLessEquals(card.right - 23 - 2, epsilon: 1));
      expect(
        tester.getRect(inCard('20')).center.dx,
        moreOrLessEquals(heading.center.dx, epsilon: 0.01),
      );

      // `aktiv` in the design's green.
      final RichText status = tester.widget<RichText>(inCard('Status:  aktiv'));
      TextSpan? value;
      status.text.visitChildren((InlineSpan span) {
        if (span is TextSpan && span.text == 'aktiv') value = span;
        return value == null;
      });
      expect(value, isNotNull);
      expect(value!.style!.color, kSaleDone);
      expect(bridge.details, <int>[1]);

      // Shut again, and opened again: nothing more is asked for.
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(138.0, epsilon: 0.25),
      );
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(bridge.details, <int>[1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name grows the card a line at a time; no VAT and a '
        'stock below nothing are said as such', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder second = find.byType(ProductCard).at(1);
      final Finder name = find.descendant(
        of: second,
        matching: find.text(
          'Beef Şuba Fhink Flank UKR / Donmuş (mal əti) Qabırğa üstü '
          'sümüksüz UKR (P)',
        ),
      );
      // The name with its doubled and trailing spaces made one.
      expect(name, findsOneWidget);
      const double line = 15 * 1.2;
      final int lines = (tester.getSize(name).height / line).round();
      expect(lines, greaterThan(1));
      expect(
        tester.getSize(second).height,
        moreOrLessEquals(138.0 + (lines - 1) * line, epsilon: 0.5),
      );

      await tester.tap(second);
      await tester.pumpAndSettle();
      Finder inCard(String text) => find.descendant(
        of: second,
        matching: find.text(text, findRichText: true),
      );
      expect(inCard('ƏDV:  yoxdur'), findsOneWidget);
      expect(inCard('Stokda:  -41'), findsOneWidget);
      expect(inCard('145.00 ₼ / kq'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an article number goes under the category, shut and open, '
        'and only on a product that has one', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder third = find.byType(ProductCard).at(2);

      Finder inCard(Finder card, String text) => find.descendant(
        of: card,
        matching: find.text(text, findRichText: true),
      );
      Rect card = tester.getRect(third);
      void onBaseline(String text, double design) {
        expect(inCard(third, text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(third, text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      // Shut: one more line, the price's distance under the category, and
      // the price that same distance further down.
      onBaseline('NM MENU / PARÇALANAN YERLİ (P)', 83.8);
      onBaseline('Artikul:  1265', 113.97);
      onBaseline('5.00 ₼ / əd', 144.14);
      expect(card.height, moreOrLessEquals(168.17, epsilon: 0.25));

      // In the category's own face.
      final RichText article = tester.widget<RichText>(
        inCard(third, 'Artikul:  1265'),
      );
      final RichText category = tester.widget<RichText>(
        inCard(third, 'NM MENU / PARÇALANAN YERLİ (P)'),
      );
      expect(article.text.style, category.text.style);

      // No article, or a blank one: no line, and the design's 138pt.
      for (final int i in <int>[0, 3]) {
        final Finder other = find.byType(ProductCard).at(i);
        expect(
          find.descendant(
            of: other,
            matching: find.textContaining('Artikul', findRichText: true),
          ),
          findsNothing,
        );
        expect(
          tester.getSize(other).height,
          moreOrLessEquals(138.0, epsilon: 0.25),
        );
      }

      // Open: a pair of its own, 33.1pt under the category's value, and
      // everything after it one pair further down.
      await tester.tap(third);
      await tester.pumpAndSettle();
      card = tester.getRect(third);
      onBaseline('NM MENU / PARÇALANAN YERLİ (P)', 129.1);
      onBaseline('Artikul:  1265', 162.2);
      onBaseline('Qiymət / Vahid:', 195.3);
      onBaseline('5.00 ₼ / əd', 215.4);
      onBaseline('Status:  aktiv', 347.8);
      expect(card.height, moreOrLessEquals(446.1 + 33.1, epsilon: 0.25));
      expect(tester.takeException(), isNull);
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

    testWidgets('a product whose own answer fails says so on the card, and '
        'asks again', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge()..failDetail = true;
      await _pump(tester, bridge);
      final Finder first = find.byType(ProductCard).first;

      await tester.tap(first);
      await tester.pumpAndSettle();
      Finder inCard(String text) =>
          find.descendant(of: first, matching: find.text(text));
      expect(inCard('Server xətası'), findsOneWidget);

      bridge.failDetail = false;
      await tester.tap(inCard('Yenidən cəhd et'));
      await tester.pumpAndSettle();
      expect(inCard('Server xətası'), findsNothing);
      expect(inCard('istehsalat'), findsOneWidget);
      // The retry did not shut the card.
      expect(inCard('Məhsul adı:'), findsOneWidget);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens every field but the warehouses', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final ProductsColumn column in ProductsColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(_inPanel('Anbar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Qiymət is a minimum and a maximum, not a list of prices', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Qiymət'));
      await tester.pumpAndSettle();
      expect(_inPanel('Min qiymət'), findsOneWidget);
      expect(_inPanel('Maks qiymət'), findsOneWidget);
      expect(_inPanel('Hamısı'), findsOneWidget);
      // Not one price listed, and nothing read to list them.
      expect(_inPanel('15.60 ₼'), findsNothing);
      expect(bridge.sizes, <int>[20]);

      await tester.enterText(_field(0), '10');
      await tester.enterText(_field(1), '50');
      // Typing is let pause before the list is narrowed.
      await tester.pump(const Duration(milliseconds: 100));
      expect(database.products.filter.isEmpty, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        database.products.filter.rangeOf(ProductsColumn.price),
        const FilterRange(min: 10, max: 50),
      );

      // Off the glass closes it; the list behind is every price in the span
      // — the whole catalogue's, not page one's.
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      await _readToEnd(tester, database);
      expect(
        <double?>[
          for (final Product product in database.products.filtered!.rows)
            product.price,
        ],
        <double>[
          15.6,
          10,
          12.5,
          17.5,
          20,
          25,
          27.5,
          32.5,
          35,
          40,
          42.5,
          47.5,
          50,
        ],
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // Opened again, the fields hold the span; `Hamısı` empties them and
      // lets the list go.
      await _openFilter(tester);
      await tester.tap(_inPanel('Qiymət'));
      await tester.pumpAndSettle();
      expect(_text(tester, 0), '10');
      expect(_text(tester, 1), '50');
      await tester.tap(_inPanel('Hamısı'));
      await tester.pumpAndSettle();
      expect(_text(tester, 0), isEmpty);
      expect(_text(tester, 1), isEmpty);
      expect(database.products.filtered, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('going back narrows the list at once, without waiting for '
        'the pause', (WidgetTester tester) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);
      await tester.tap(_inPanel('Qiymət'));
      await tester.pumpAndSettle();

      await tester.enterText(_field(1), '0');
      await tester.tap(find.bySemanticsLabel('Geri'));
      await tester.pump();
      expect(
        database.products.filter.rangeOf(ProductsColumn.price),
        const FilterRange(max: 0),
      );
      await tester.pumpAndSettle();
      expect(_inPanel('Kod'), findsOneWidget);
      expect(database.products.narrows(ProductsColumn.price), isTrue);
    });

    testWidgets('ƏDV takes a span or `ƏDV yoxdur`, never both', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);
      await tester.tap(_inPanel('ƏDV'));
      await tester.pumpAndSettle();
      expect(_inPanel('Min ƏDV'), findsOneWidget);
      expect(_inPanel('Maks ƏDV'), findsOneWidget);
      expect(_inPanel('ƏDV yoxdur'), findsOneWidget);

      await tester.enterText(_field(0), '10');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        database.products.filter.rangeOf(ProductsColumn.vat),
        const FilterRange(min: 10),
      );

      await tester.tap(_inPanel('ƏDV yoxdur'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_text(tester, 0), isEmpty);
      expect(
        database.products.filter.isChosen(ProductsColumn.vat, kNoVatValue),
        isTrue,
      );
      expect(
        database.products.filter.rangeOf(ProductsColumn.vat).isEmpty,
        isTrue,
      );

      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      await _readToEnd(tester, database);
      // Every fourth product carries 18%; the other 45 none.
      expect(database.products.filtered!.rows, hasLength(45));
      expect(
        database.products.filtered!.rows.every((Product p) => p.hasNoVat),
        isTrue,
      );
    });

    testWidgets('Stok takes a minus: what has run short', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);
      await tester.tap(_inPanel('Stok'));
      await tester.pumpAndSettle();

      await tester.enterText(_field(1), '-');
      await tester.pump();
      expect(_text(tester, 1), '-');
      await tester.enterText(_field(1), '-0,5');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        database.products.filter.rangeOf(ProductsColumn.stock),
        const FilterRange(max: -0.5),
      );
      // Not a figure: the field keeps what it had.
      await tester.enterText(_field(0), 'abc');
      await tester.pump();
      expect(_text(tester, 0), isEmpty);

      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      await _readToEnd(tester, database);
      expect(
        <double?>[
          for (final Product product in database.products.filtered!.rows)
            product.stock,
        ],
        <double>[-41],
      );
    });

    testWidgets('Kateqoriya reads the catalogue once, then lists every '
        'category alphabetically', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Kateqoriya'));
      await tester.pumpAndSettle();
      expect(database.products.hasEveryProduct, isTrue);
      // Page one, then the rest in pages as large as their places allow.
      expect(bridge.sizes, <int>[20, 20, 40]);

      double last = -1;
      for (final String label in <String>[
        'KOLBASA',
        'NM MENU / PARÇALANAN YERLİ (P)',
        'NM MENU / SOUSLAR',
        'QEYRİ QİDA',
      ]) {
        expect(_inPanel(label), findsOneWidget, reason: label);
        final double top = tester.getRect(_inPanel(label)).top;
        expect(top, greaterThan(last), reason: '$label is out of order');
        last = top;
      }

      await tester.tap(_inPanel('KOLBASA'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      await _readToEnd(tester, database);
      expect(database.products.filtered!.rows, hasLength(15));
      // Nothing more was read for it: the catalogue is on the phone.
      expect(bridge.sizes, <int>[20, 20, 40]);
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
        'the nine columns and a span\'s fields',
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

          // The design's product, the one with the longest name, and one
          // with an article number.
          fits(find.byType(ProductCard).at(0));
          fits(find.byType(ProductCard).at(1));
          fits(find.byType(ProductCard).at(2));

          // Opened, one and then the other — an open card fills a small
          // phone: every pair and the table's rows.
          await tester.tap(find.byType(ProductCard).at(0));
          await tester.pumpAndSettle();
          fits(find.byType(ProductCard).at(0));
          await tester.tap(find.byType(ProductCard).at(0));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(ProductCard).at(1));
          await tester.pumpAndSettle();
          fits(find.byType(ProductCard).at(1));
          expect(tester.takeException(), isNull);

          // The funnel's nine columns, every one on the glass.
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
          for (final ProductsColumn column in ProductsColumn.values) {
            inside(
              glass(),
              tester.getRect(_inPanel(column.label)),
              column.label,
            );
          }

          // `ƏDV`, the tallest span page: both fields, `Hamısı` and `ƏDV
          // yoxdur`, all on the glass and the glass inside the band.
          await tester.tap(_inPanel('ƏDV'));
          await tester.pumpAndSettle();
          inside(band, glass(), 'the span page');
          inside(glass(), tester.getRect(_field(0)), 'the minimum');
          inside(glass(), tester.getRect(_field(1)), 'the maximum');
          inside(glass(), tester.getRect(_inPanel('Hamısı')), 'Hamısı');
          inside(glass(), tester.getRect(_inPanel('ƏDV yoxdur')), 'ƏDV yoxdur');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// Reads the filtered list to its end, the way a reader scrolling it would
/// have it read.
Future<void> _readToEnd(
  WidgetTester tester,
  DatabaseController database,
) async {
  for (int i = 0; i < 20; i++) {
    final ProductsFilterView? view = database.products.filtered;
    if (view == null || !view.hasMore) return;
    await view.loadMore();
    await tester.pumpAndSettle();
  }
}

/// What a span page's field holds: 0 the minimum, 1 the maximum.
String _text(WidgetTester tester, int index) =>
    tester.widget<TextField>(_field(index)).controller!.text;

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// Where [text]'s first line sits on the screen, as it is laid out — its own
/// alignment included, which a painter laid out afresh would not know.
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

Finder _list() => find.descendant(
  of: find.byType(ProductsList),
  matching: find.byType(Scrollable),
);

/// [text] on the filter's glass, not on a card behind it.
Finder _inPanel(String text) => find.descendant(
  of: find.byType(DatabaseFilterPanel),
  matching: find.text(text),
);

/// A span page's field: 0 the minimum, 1 the maximum.
Finder _field(int index) => find
    .descendant(
      of: find.byType(DatabaseFilterPanel),
      matching: find.byType(TextField),
    )
    .at(index);

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
  )..select(DatabaseSection.products);
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

/// The 1C bridge's product catalogue, sixty deep, lowest id first. The
/// first product is the design's; the second the longest name in the live
/// data, with no VAT and a stock below nothing.
class _Bridge {
  bool failDetail = false;

  /// The page of every unfiltered list request of the list's own size.
  final List<int> pages = <int>[];

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  /// The id of every product asked for on its own.
  final List<int> details = <int>[];

  static const int total = 60;

  static const List<String> categories = <String>[
    'NM MENU / SOUSLAR',
    'QEYRİ QİDA',
    'NM MENU / PARÇALANAN YERLİ  (P)',
    'KOLBASA',
  ];

  Map<String, Object?> row(int i) => <String, Object?>{
    'id': i + 1,
    'code': switch (i) {
      0 => 'NT000007303',
      _ => 'NT${(1000 + i).toString().padLeft(9, '0')}',
    },
    'name': switch (i) {
      0 => 'Biotech Zero Sauce 350 ml BARBECUE',
      1 =>
        'Beef Şuba Fhink Flank UKR / Donmuş (mal əti) Qabırğa üstü sümüksüz  '
            'UKR  (P) ',
      _ => 'Məhsul $i',
    },
    'price': switch (i) {
      0 => 15.6,
      1 => 145,
      _ => i % 3 == 0 ? 0 : 2.5 * i,
    },
    'stock_qty': switch (i) {
      0 => 26,
      1 => -41.0,
      _ => (i * 7.25) % 90,
    },
    'unit': i.isEven ? 'əd' : 'kq',
    // Only some products have one; 1C leaves the rest empty or blank.
    'article': switch (i) {
      2 => '1265',
      3 => '  ',
      _ => null,
    },
    'category': null,
    'folder_path': categories[i % categories.length],
    'folder_name': null,
    'product_type': switch (i % 3) {
      0 => 'xammal',
      1 => 'Mal',
      _ => 'Məhsul',
    },
    'vat_rate': i % 4 == 0 ? 18.0 : 0.0,
    'is_active': true,
    'baza_id': 18,
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    final RegExpMatch? one = RegExp(r'/products/(\d+)$').firstMatch(path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      if (failDetail) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      return _json(<String, Object?>{
        ...row(id - 1),
        'status': 'active',
        'warehouses': <Object?>[
          <String, Object?>{
            'warehouse': 'Badamdar Anbar',
            'quantity': 6.0,
            'balance_date': '2026-09-23',
          },
          <String, Object?>{
            'warehouse': 'istehsalat',
            'quantity': 20.0,
            'balance_date': '2026-09-23',
          },
        ],
      });
    }
    if (!path.endsWith('/products/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    // `Əsas panel`'s one-row count is not the list's.
    if (size > 1) sizes.add(size);
    if (search == null && size == 20) pages.add(page);

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < total; i++)
        if (search == null ||
            '${row(i)['code']} ${row(i)['name']}'.toLowerCase().contains(
              search.toLowerCase(),
            ))
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
