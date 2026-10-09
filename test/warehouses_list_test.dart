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
import 'package:guven_mobile/src/features/database/domain/warehouse.dart';
import 'package:guven_mobile/src/features/database/domain/warehouses_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/warehouse_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/warehouses_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Anbarlar` as the user meets it: `Kassalar`' card with a warehouse's four
/// fields, the code's line gone when 1C gives none; a tap opens nothing; the
/// funnel's columns, `Kod` among them only once there is a code; on every
/// phone.
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

  group('on the frame `Komanda` was drawn on', () {
    testWidgets('a warehouse with a code is `Kassalar`\' card, line for '
        'line', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      expect(find.text('Anbarlar'), findsOneWidget);

      final Finder second = find.byType(WarehouseCard).at(1);
      final Rect card = tester.getRect(second);

      // 19.5pt either side of a 363pt card, on the 402pt frame; 9pt from
      // the one above, as on `Kassalar`.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_withCode, epsilon: 0.25));
      expect(
        card.top - tester.getRect(find.byType(WarehouseCard).first).bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

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

      // `Kassalar`' baselines: every gap the eye sees the same.
      onBaseline('ANB001', 27.5);
      onBaseline('Badamdar Anbar', 62.13);
      onBaseline('Növü: Standart', 91.13);
      onBaseline('Status:  aktiv', 120.13);

      // The code in the tab's figures, the name in `Komanda`'s face.
      expect(
        tester
            .widget<Text>(
              find.descendant(of: second, matching: find.text('ANB001')),
            )
            .style!
            .fontFamily,
        kDatabaseFigureFont,
      );
      final Text name = tester.widget<Text>(
        find.descendant(of: second, matching: find.text('Badamdar Anbar')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(TeamCard.kName));

      // Every line at the content's edge.
      for (final String text in <String>[
        'ANB001',
        'Badamdar Anbar',
        'Növü: Standart',
        'Status:  aktiv',
      ]) {
        expect(
          tester.getRect(inCard(text)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: text,
        );
      }
      expect(_colourOf(tester, inCard('Status:  aktiv'), 'aktiv'), kSaleDone);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a warehouse with no code has no line for it, and its name '
        'stands where the code would', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      final Finder first = find.byType(WarehouseCard).first;
      final Rect card = tester.getRect(first);
      expect(card.height, moreOrLessEquals(_noCode, epsilon: 0.25));

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      // Three lines, nothing standing in for the code — not a dash.
      expect(
        find.descendant(of: first, matching: find.byType(RichText)).evaluate(),
        hasLength(3),
      );
      expect(inCard('—'), findsNothing);

      final double named = _baseline(tester, inCard('Ağ Şəhər Anbar'));
      final double kind = _baseline(tester, inCard('Növü: Standart'));
      final double status = _baseline(tester, inCard('Status:  aktiv'));
      expect(named - card.top, moreOrLessEquals(33.1, epsilon: 0.25));
      expect(kind - card.top, moreOrLessEquals(62.1, epsilon: 0.25));
      expect(status - card.top, moreOrLessEquals(91.1, epsilon: 0.25));

      // The name's capitals as far from the top as a code's are on the
      // card beside it — CalSans' and ChakraPetch's capitals both 0.7 of
      // their size.
      final Finder second = find.byType(WarehouseCard).at(1);
      final double codeCaps =
          _baseline(
            tester,
            find.descendant(of: second, matching: find.text('ANB001')),
          ) -
          14 * 0.7 -
          tester.getRect(second).top;
      expect(
        named - 22 * 0.7 - card.top,
        moreOrLessEquals(codeCaps, epsilon: 0.25),
      );
      // And the gaps under it are the rows' own.
      expect(
        kind - 14 * 0.698 - named,
        moreOrLessEquals(status - 14 * 0.698 - kind, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1C\'s spacing tidied, a long name on a second line, the '
        'kind in the website\'s words, and a warehouse switched off in '
        'red', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      Finder card(int i) => find.byType(WarehouseCard).at(i);

      // `Nizami (6-cı Paralel)  Anbarı` — two spaces in 1C.
      expect(
        find.descendant(
          of: card(2),
          matching: find.text('Nizami (6-cı Paralel) Anbarı'),
        ),
        findsOneWidget,
      );

      // Too long for one line: wrapped, never cut, one 29pt line taller —
      // and a code-less card, as live.
      await tester.dragUntilVisible(
        find.text('Nəsimi rayonu, Mərkəzi Soyuducu Anbarı'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder long = find.ancestor(
        of: find.text('Nəsimi rayonu, Mərkəzi Soyuducu Anbarı'),
        matching: find.byType(WarehouseCard),
      );
      expect(
        tester.getSize(long).height,
        moreOrLessEquals(_noCode + 29, epsilon: 0.25),
      );
      expect(
        find.descendant(
          of: long,
          matching: find.text('Növü: Pərakəndə', findRichText: true),
        ),
        findsOneWidget,
      );

      await tester.dragUntilVisible(
        find.text('Bağlanmış anbar'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder off = find.descendant(
        of: find.ancestor(
          of: find.text('Bağlanmış anbar'),
          matching: find.byType(WarehouseCard),
        ),
        matching: find.text('Status:  deaktiv', findRichText: true),
      );
      expect(off, findsOneWidget);
      expect(_colourOf(tester, off, 'deaktiv'), kSalePending);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(WarehouseCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    testWidgets('the live catalogue, no code anywhere: no `Kod` column', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge(codes: false));
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      expect(_inPanel('Kod'), findsNothing);
      for (final String label in <String>['Anbar adı', 'Növü', 'Status']) {
        expect(_inPanel(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('with codes, the card\'s four fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      for (final WarehousesColumn column in WarehousesColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Növü reads the catalogue once and narrows the list to a '
        'kind', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Növü'));
      await tester.pumpAndSettle();
      expect(database.warehouses.hasEveryone, isTrue);
      expect(bridge.sizes, <int>[20, 20]);
      expect(
        tester.getTopLeft(_inPanel('Standart')).dy,
        lessThan(tester.getTopLeft(_inPanel('Pərakəndə')).dy),
      );

      await tester.tap(_inPanel('Pərakəndə'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <int>[
          for (final Warehouse w in database.warehouses.filtered!.rows) w.id,
        ],
        <int>[9, 14, 19, 24, 29],
      );
      // Nothing more was read for it.
      expect(bridge.sizes, <int>[20, 20]);
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
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
      testWidgets('${device.name} @ ${fontScale}x — cards fit, with a code and '
          'without, and so do the four columns', (WidgetTester tester) async {
        await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
        // The card's own padding on this phone: the design's 23pt, scaled
        // the way `databaseScale` scales it.
        final double s =
            (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

        final int built = find.byType(WarehouseCard).evaluate().length;
        for (int i = 0; i < built && i < 6; i++) {
          final Finder card = find.byType(WarehouseCard).at(i);
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
        for (final WarehousesColumn column in WarehousesColumn.values) {
          inside(glass, tester.getRect(_inPanel(column.label)), column.label);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// A one-line name under a code, on the 402pt frame: `Kassalar`' card.
const double _withCode = 120.13 + 22;

/// A one-line name and no code: the name's capitals where a code's would
/// be, so every line 29pt higher than under a code.
const double _noCode = 91.1 + 22;

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The colour [word] is drawn in, inside the rich [text].
Color? _colourOf(WidgetTester tester, Finder text, String word) {
  Color? found;
  tester.widget<RichText>(text).text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == word) {
      found = span.style?.color;
      return false;
    }
    return true;
  });
  return found;
}

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

Finder _list() => find.descendant(
  of: find.byType(WarehousesList),
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
  )..select(DatabaseSection.warehouses);
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

/// The 1C bridge's warehouses, thirty deep. The first seven are the live
/// catalogue's, as read on 2026-10-09, except that every other one is given
/// a code (unless [codes] is false — live, none has one); after them, with
/// no gap in that pattern, come one more, then a name too long for one line
/// and a warehouse switched off. Every fifth from the ninth is a shop's
/// (`retail`), the rest `default`.
class _Bridge {
  _Bridge({this.codes = true});

  final bool codes;

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  static const int total = 30;

  static const List<String> _live = <String>[
    'Ağ Şəhər Anbar',
    'Badamdar Anbar',
    'Nizami (6-cı Paralel)  Anbarı',
    'Nərimanov Anbar ',
    'Səməd Vurğun',
    'Ulduz Anbarı',
    'istehsalat',
  ];

  Map<String, Object?> row(int i) => <String, Object?>{
    'id': i + 1,
    'onec_guid': 'guid-$i',
    'code': codes && i.isOdd ? 'ANB${i.toString().padLeft(3, '0')}' : '',
    'name': i < _live.length
        ? _live[i]
        : switch (i) {
            8 => 'Nəsimi rayonu, Mərkəzi Soyuducu Anbarı',
            9 => 'Bağlanmış anbar',
            _ => 'Anbar $i',
          },
    'warehouse_type': i % 5 == 3 && i > 5 ? 'retail' : 'default',
    'is_active': i != 9,
    'created_at': '2026-09-18T13:46:20.169681',
    'updated_at': '2026-09-18T13:46:20.169681',
    'baza_id': 18,
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/warehouses/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    sizes.add(size);

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < total; i++)
        if (search == null ||
            '${row(i)['name']}'.toLowerCase().contains(search.toLowerCase()))
          row(i),
    ];
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'total': found.length,
      'page': page,
      'page_size': size,
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
