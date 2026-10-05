import 'dart:async';
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
import 'package:guven_mobile/src/features/database/application/customers_controller.dart';
import 'package:guven_mobile/src/features/database/application/database_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/customer.dart';
import 'package:guven_mobile/src/features/database/domain/customers_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/customer_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/customers_list.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Müştərilər` as the user meets it: the design's two cards — every name
/// one size — shut and open, the role and the legal status asked for on
/// every opening and the legal status shown only where there is one, the
/// next page on its way before the reader gets there, the funnel's four
/// columns, on every phone.
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
    testWidgets('a short name is the design\'s first card, row for row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Müştərilər'), findsOneWidget);
      final Finder first = find.byType(CustomerCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card — every `Baza` list's — on the
      // design's own 402pt frame; 106.85pt tall with the name at 20pt.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(106.85, epsilon: 0.25));
      // 9pt to the next — closer than the other lists' 11.5, as drawn.
      expect(
        tester.getRect(find.byType(CustomerCard).at(1)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      // Every row on its baseline: the name's off the user's picture, the
      // rest the design's distances under it.
      void onBaseline(String text, double design) {
        expect(inCard(text), findsOneWidget, reason: text);
        expect(
          _baseline(tester, inCard(text)) - card.top,
          moreOrLessEquals(design, epsilon: 0.25),
          reason: text,
        );
      }

      // The name with its doubled space made one, and 27.5pt over the code.
      onBaseline('(İŞÇİ) - FİDAN S.', 30.4);
      onBaseline('NT000007303', 57.85);
      onBaseline('Hüquqi', 81.85);
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('(İŞÇİ) - FİDAN S.')),
      );
      expect(name.style!.fontSize, moreOrLessEquals(20));

      // The code in the tab's figures, and both rows at the content's edge.
      final Text code = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('NT000007303')),
      );
      expect(code.style!.fontFamily, kDatabaseFigureFont);
      for (final String text in <String>['NT000007303', 'Hüquqi']) {
        expect(
          tester.getRect(inCard(text)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: text,
        );
      }

      // Shut, it shows nothing only an open card has — the labels take no
      // room ahead of their values (above), and the open rows are not there.
      expect(inCard('Rolu: Alıcı'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name open is the design\'s second card, and the '
        'role is asked for on every opening', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder second = find.byType(CustomerCard).at(1);

      // Shut, the long name takes a second 26pt line.
      expect(
        tester.getSize(second).height,
        moreOrLessEquals(106.85 + 26, epsilon: 0.25),
      );

      await tester.tap(second);
      await tester.pumpAndSettle();
      final Rect card = tester.getRect(second);

      Finder inCard(String text) => find.descendant(
        of: second,
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

      // The design's rows: the name's first line, the code 27.5pt under its
      // last, and then every pair 28.75pt from the next — the design's
      // average — to the last, 30pt above the bottom edge.
      const String long =
          'AHG PORT BAKU WALK GİARDİNO - ABŞERON HOSPİTALİTY GROUP';
      onBaseline(long, 30.4);
      onBaseline('Kod/ Vöen:', 83.85);
      onBaseline('NT0000101', 83.85);
      onBaseline('Növ:\u00A0', 112.7);
      onBaseline('Hüquqi', 112.7);
      onBaseline('Rolu: Alıcı', 141.45);
      onBaseline('Hüquqi Status: Hüq. şəxs', 170.2);
      onBaseline('Ödəniş müddəti: 30 gün', 198.95);
      expect(card.height, moreOrLessEquals(228.9, epsilon: 0.25));

      // The short name's size, on two 26pt lines.
      final Text name = tester.widget<Text>(
        find.descendant(of: second, matching: find.text(long)),
      );
      expect(name.style!.fontSize, moreOrLessEquals(20));
      expect(tester.getSize(inCard(long)).height, moreOrLessEquals(52));

      // The code the design's wide gap after its label; the kind a space
      // after its own.
      final Rect label = tester.getRect(inCard('Kod/ Vöen:'));
      expect(label.left - card.left, moreOrLessEquals(23, epsilon: 0.01));
      expect(
        tester.getRect(inCard('NT0000101')).left - label.right,
        moreOrLessEquals(16.8, epsilon: 0.01),
      );
      expect(
        tester.getRect(inCard('Hüquqi')).left - card.left,
        moreOrLessEquals(23 + 33.4, epsilon: 0.1),
      );
      expect(bridge.details, <int>[2]);

      // Shut again, and opened again: asked again, in case 1C has changed.
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(second).height,
        moreOrLessEquals(132.85, epsilon: 0.25),
      );
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(bridge.details, <int>[2, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every name is one size, short or long', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      for (final (int index, String text) in <(int, String)>[
        (0, '(İŞÇİ) - FİDAN S.'),
        (1, 'AHG PORT BAKU WALK GİARDİNO - ABŞERON HOSPİTALİTY GROUP'),
        (3, 'DSMF'),
        (4, 'THE RİTZ -CARLTON BAKU- YELKEN'),
      ]) {
        final Text name = tester.widget<Text>(
          find.descendant(
            of: find.byType(CustomerCard).at(index),
            matching: find.text(text),
          ),
        );
        expect(name.style!.fontSize, moreOrLessEquals(20), reason: text);
        expect(name.style!.fontFamily, 'CalSans', reason: text);
      }
      // A name that fits one line is one line, and its card the short
      // name's.
      expect(
        tester.getSize(find.byType(CustomerCard).at(4)).height,
        moreOrLessEquals(106.85, epsilon: 0.25),
      );
    });

    testWidgets('the legal status is a row only where 1C gives one', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge()..holdDetails = true;
      await _pump(tester, bridge);
      final Finder fourth = find.byType(CustomerCard).at(3);
      Finder inCard(String text) => find.descendant(
        of: fourth,
        matching: find.textContaining(text, findRichText: true),
      );

      // While the customer's own answer is on its way, nobody knows: the
      // row is not there, and the role waits.
      await tester.tap(fourth);
      await tester.pumpAndSettle();
      expect(inCard('Rolu: …'), findsOneWidget);
      expect(inCard('Hüquqi Status'), findsNothing);

      // It comes back without one: still no row — not `—` — and the card
      // one pair shorter than one with a status.
      bridge.release();
      await tester.pumpAndSettle();
      expect(inCard('Hüquqi Status'), findsNothing);
      expect(inCard('Ödəniş müddəti'), findsOneWidget);
      expect(
        tester.getSize(fourth).height,
        moreOrLessEquals(106.85 + 96.06 - 28.75, epsilon: 0.25),
      );

      // One that has a status grows the row in once its answer lands.
      final Finder first = find.byType(CustomerCard).first;
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: first,
          matching: find.textContaining('Hüquqi Status', findRichText: true),
        ),
        findsNothing,
      );
      bridge.release();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: first,
          matching: find.text('Hüquqi Status: Hüq. şəxs', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(106.85 + 96.06, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a legal status filled in 1C later shows the next time the '
        'card opens', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder fourth = find.byType(CustomerCard).at(3);
      Finder status() => find.descendant(
        of: fourth,
        matching: find.textContaining('Hüquqi Status', findRichText: true),
      );

      await tester.tap(fourth);
      await tester.pumpAndSettle();
      expect(status(), findsNothing);
      await tester.tap(fourth);
      await tester.pumpAndSettle();

      // Filled in since: opened again, the row is there with its value.
      bridge.filledLater = true;
      await tester.tap(fourth);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: fourth,
          matching: find.text('Hüquqi Status: Fiz. şəxs', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(bridge.details, <int>[4, 4]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a VÖEN before the code, a person, both roles, and no term', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      final Finder third = find.byType(CustomerCard).at(2);
      Finder inCard(Finder card, String text) => find.descendant(
        of: card,
        matching: find.text(text, findRichText: true),
      );
      expect(inCard(third, '1800158551'), findsOneWidget);
      expect(inCard(third, 'Fiziki'), findsOneWidget);

      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(inCard(third, 'Rolu: Alıcı, Təchizatçı'), findsOneWidget);

      // Neither a buyer nor a supplier, and a term of 0: `—`, as the
      // website says it.
      final Finder fourth = find.byType(CustomerCard).at(3);
      await tester.tap(fourth);
      await tester.pumpAndSettle();
      expect(inCard(fourth, 'Rolu: —'), findsOneWidget);
      expect(inCard(fourth, 'Ödəniş müddəti: —'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      await tester.drag(_list(), const Offset(0, -500));
      await tester.pump();
      expect(bridge.pages, <int>[1]);

      await tester.drag(_list(), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a customer whose own answer fails says so on the card, and '
        'asks again', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge()..failDetail = true;
      await _pump(tester, bridge);
      final Finder first = find.byType(CustomerCard).first;

      await tester.tap(first);
      await tester.pumpAndSettle();
      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );
      expect(inCard('Server xətası'), findsOneWidget);
      expect(inCard('Rolu: —'), findsOneWidget);

      bridge.failDetail = false;
      await tester.tap(inCard('Yenidən cəhd et'));
      await tester.pumpAndSettle();
      expect(inCard('Server xətası'), findsNothing);
      // The retry did not shut the card.
      expect(inCard('Rolu: Alıcı'), findsOneWidget);
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(106.85 + 96.06, epsilon: 0.25),
      );
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens the four columns the rows carry', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final CustomersColumn column in CustomersColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      // Only a customer's own answer carries these.
      expect(_inPanel('Rolu'), findsNothing);
      expect(_inPanel('Hüquqi status'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Növ narrows the list to people, found in the whole '
        'directory', (WidgetTester tester) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Növ'));
      await tester.pumpAndSettle();
      expect(_inPanel('Hüquqi'), findsOneWidget);
      await tester.tap(_inPanel('Fiziki'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);

      await _readToEnd(tester, database);
      expect(
        <int>[
          for (final Customer customer in database.customers.filtered!.rows)
            customer.id,
        ],
        <int>[3, 13, 23, 33],
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Ödəniş müddəti reads the directory once, then lists every '
        'term', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Ödəniş müddəti'));
      await tester.pumpAndSettle();
      expect(database.customers.hasEveryCustomer, isTrue);
      expect(bridge.sizes, <int>[20, 20]);
      expect(_inPanel('15 gün'), findsOneWidget);
      expect(_inPanel('30 gün'), findsOneWidget);

      await tester.tap(_inPanel('15 gün'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(database.customers.filtered!.rows, hasLength(1));
      // Nothing more was read for it: the directory is on the phone.
      expect(bridge.sizes, <int>[20, 20]);
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
        'the four columns',
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

          // The design's two customers and the others on screen — on a
          // small phone the list builds only the ones in view.
          final int built = find.byType(CustomerCard).evaluate().length;
          for (int i = 0; i < built && i < 5; i++) {
            fits(find.byType(CustomerCard).at(i));
          }

          // Opened, one and then the other.
          for (final int i in <int>[0, 1]) {
            await tester.tap(find.byType(CustomerCard).at(i));
            await tester.pumpAndSettle();
            fits(find.byType(CustomerCard).at(i));
            await tester.tap(find.byType(CustomerCard).at(i));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);

          // The funnel's four columns, every one on the glass.
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
          void inside(Rect outer, Rect inner, String what) {
            expect(
              outer.contains(inner.topLeft) &&
                  outer.contains(inner.bottomRight - const Offset(0.01, 0.01)),
              isTrue,
              reason: '$what $inner is not inside $outer',
            );
          }

          inside(band, glass, 'the columns');
          for (final CustomersColumn column in CustomersColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
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
    final CustomersFilterView? view = database.customers.filtered;
    if (view == null || !view.hasMore) return;
    await view.loadMore();
    await tester.pumpAndSettle();
  }
}

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
  of: find.byType(CustomersList),
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
  )..select(DatabaseSection.customers);
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

/// The 1C bridge's customer directory, forty deep, lowest id first. The
/// first two are the design's customers; the third has a VÖEN, is a person
/// and both buys and supplies; the fourth is the shortest name in the live
/// data, neither buyer nor supplier, on no term and with no legal status;
/// the fifth a name that just fits one line. Every tenth after the third is a person too, and the
/// sixth is on a 15-day term.
class _Bridge {
  bool failDetail = false;

  /// The fourth customer's legal status has been filled in 1C.
  bool filledLater = false;

  /// Customers' own answers are held back until [release].
  bool holdDetails = false;
  final List<Completer<void>> _held = <Completer<void>>[];

  /// Lets every held answer go.
  void release() {
    for (final Completer<void> held in _held) {
      held.complete();
    }
    _held.clear();
  }

  /// The page of every unfiltered list request of the list's own size.
  final List<int> pages = <int>[];

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  /// The id of every customer asked for on its own.
  final List<int> details = <int>[];

  static const int total = 40;

  Map<String, Object?> row(int i) => <String, Object?>{
    'id': i + 1,
    'code': i == 0 ? 'NT000007303' : 'NT0000${100 + i}',
    'inn': i == 2 ? '1800158551' : '',
    'name': switch (i) {
      0 => '(İŞÇİ) -  FİDAN S.',
      1 => 'AHG PORT BAKU WALK GİARDİNO - ABŞERON HOSPİTALİTY GROUP',
      2 => 'ABŞERON 2000',
      3 => 'DSMF',
      4 => 'THE RİTZ -CARLTON BAKU- YELKEN',
      _ => 'Müştəri $i',
    },
    'customer_type': i % 10 == 2 ? 'physical' : 'legal',
    'payment_deadline_days': switch (i) {
      3 => 0,
      5 => 15,
      _ => 30,
    },
    'credit_limit': 0,
    'is_active': true,
    'baza_id': 18,
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    final RegExpMatch? one = RegExp(r'/customers/(\d+)$').firstMatch(path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      if (holdDetails) {
        final Completer<void> held = Completer<void>();
        _held.add(held);
        await held.future;
      }
      if (failDetail) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      return _json(<String, Object?>{
        ...row(id - 1),
        // 1C gives some customers no legal status at all.
        if (id != 4)
          'legal_type': 'Hüq. şəxs'
        else if (filledLater)
          'legal_type': 'Fiz. şəxs',
        'is_buyer': id != 4,
        'is_supplier': id == 3,
      });
    }
    if (!path.endsWith('/customers/')) {
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
            '${row(i)['code']} ${row(i)['inn']} ${row(i)['name']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
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
