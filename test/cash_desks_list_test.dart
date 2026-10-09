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
import 'package:guven_mobile/src/features/database/domain/cash_desk.dart';
import 'package:guven_mobile/src/features/database/domain/cash_desks_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/cash_desk_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/cash_desks_list.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Kassalar` as the user meets it: `Komanda`'s card with a desk's four
/// fields and no guid; a tap opens nothing; the funnel's four columns; on
/// every phone.
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
    testWidgets('a desk is `Komanda`\'s card: code, name, Valyuta, Status — '
        'and no guid', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      expect(find.text('Kassalar'), findsOneWidget);

      final Finder first = find.byType(CashDeskCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, on the 402pt frame; a one-line
      // name and two rows, every gap the same, make 142.1pt.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_oneLine, epsilon: 0.25));
      // 9pt to the next, as on `Komanda`.
      expect(
        tester.getRect(find.byType(CashDeskCard).at(1)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
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

      // The code where `Komanda`'s is; then every line so that the gap the
      // eye sees — a baseline to the capitals under it — is the rows' own
      // (the user, 2026-10-06).
      onBaseline('NT0000003', 27.5);
      onBaseline('Danət Kassa', 62.13);
      onBaseline('Valyuta: AZN', 91.13);
      onBaseline('Status:  aktiv', 120.13);

      final double code = _baseline(tester, inCard('NT0000003'));
      final double named = _baseline(tester, inCard('Danət Kassa'));
      final double currency = _baseline(tester, inCard('Valyuta: AZN'));
      final double status = _baseline(tester, inCard('Status:  aktiv'));
      // Capitals: CalSans' and Poppins' own, 0.7 and 0.698 of their size.
      final double nameGap = named - 22 * 0.7 - code;
      final double currencyGap = currency - 14 * 0.698 - named;
      final double statusGap = status - 14 * 0.698 - currency;
      expect(nameGap, moreOrLessEquals(statusGap, epsilon: 0.25));
      expect(currencyGap, moreOrLessEquals(statusGap, epsilon: 0.25));
      // And the rows' gap is what it was: they are still 29pt apart.
      expect(status - currency, moreOrLessEquals(29, epsilon: 0.25));

      // The website's last column is not on the phone.
      expect(
        find.descendant(
          of: first,
          matching: find.textContaining('2579847b', findRichText: true),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: first,
          matching: find.textContaining('GUID', findRichText: true),
        ),
        findsNothing,
      );

      // The name in `Komanda`'s face and size.
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('Danət Kassa')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(TeamCard.kName));

      // Every row at the content's edge; the code in the tab's figures.
      for (final String text in <String>[
        'NT0000003',
        'Danət Kassa',
        'Valyuta: AZN',
        'Status:  aktiv',
      ]) {
        expect(
          tester.getRect(inCard(text)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: text,
        );
      }
      expect(
        tester
            .widget<Text>(
              find.descendant(of: first, matching: find.text('NT0000003')),
            )
            .style!
            .fontFamily,
        kDatabaseFigureFont,
      );

      // `aktiv` in the tab's green.
      expect(_colourOf(tester, inCard('Status:  aktiv'), 'aktiv'), kSaleDone);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name takes a second line, and a desk switched off '
        'says so in red', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      Finder card(int i) => find.byType(CashDeskCard).at(i);

      // The bridge's order, the live desks first.
      for (final (int i, String name) in <(int, String)>[
        (0, 'Danət Kassa'),
        (1, 'Nərimanov kassası'),
        (2, 'Əsas Kassa'),
      ]) {
        expect(
          find.descendant(of: card(i), matching: find.text(name)),
          findsOneWidget,
          reason: name,
        );
      }

      // A name too long for one line wraps — never cut — and the card is
      // one 29pt line taller.
      expect(
        tester.getSize(card(3)).height,
        moreOrLessEquals(_oneLine + 29, epsilon: 0.25),
      );
      expect(
        find.descendant(
          of: card(3),
          matching: find.text('Valyuta: USD', findRichText: true),
        ),
        findsOneWidget,
      );

      // A desk 1C has switched off: `deaktiv`, in red.
      await tester.dragUntilVisible(
        find.text('Bağlanmış kassa'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder off = find.descendant(
        of: find.ancestor(
          of: find.text('Bağlanmış kassa'),
          matching: find.byType(CashDeskCard),
        ),
        matching: find.text('Status:  deaktiv', findRichText: true),
      );
      expect(off, findsOneWidget);
      expect(_colourOf(tester, off, 'deaktiv'), kSalePending);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(CashDeskCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      await tester.drag(_list(), const Offset(0, -500));
      await tester.pump();
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      for (int i = 0; i < 2; i++) {
        await tester.drag(_list(), const Offset(0, -800));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
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
      for (final CashDesksColumn column in CashDesksColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(_inPanel('GUID'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Valyuta reads the catalogue once and lists every currency, '
        'the most common first', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Valyuta'));
      await tester.pumpAndSettle();
      expect(database.cashDesks.hasEveryone, isTrue);
      expect(bridge.sizes, <int>[20, 20]);
      expect(
        tester.getTopLeft(_inPanel('AZN')).dy,
        lessThan(tester.getTopLeft(_inPanel('USD')).dy),
      );

      await tester.tap(_inPanel('USD'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <int>[
          for (final CashDesk desk in database.cashDesks.filtered!.rows)
            desk.id,
        ],
        <int>[97, 92, 87, 82, 77, 72],
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
      testWidgets(
        '${device.name} @ ${fontScale}x — cards fit, and so do the four '
        'columns',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          final int built = find.byType(CashDeskCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(CashDeskCard).at(i);
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
          for (final CashDesksColumn column in CashDesksColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// A card with a one-line name, on the 402pt frame: the code's baseline
/// 27.5pt down, three equal gaps to the last row's, and 22pt under it.
const double _oneLine = 120.13 + 22;

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
  of: find.byType(CashDesksList),
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
  )..select(DatabaseSection.cashDesks);
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

/// The 1C bridge's cash desks, thirty deep, newest first as it gives them.
/// The first three are the live catalogue's, as read on 2026-10-05; the
/// fourth has a name too long for one line and keeps dollars; the fifth is
/// switched off. After them every fifth from the ninth keeps dollars too,
/// and the rest manat.
class _Bridge {
  /// The page of every unfiltered list request of the list's own size.
  final List<int> pages = <int>[];

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  static const int total = 30;

  Map<String, Object?> row(int i) {
    // The live desks' own ids, then ids of their own.
    final int id = i < 3 ? 15 - i : 100 - i;
    return <String, Object?>{
      'id': id,
      'onec_guid': switch (i) {
        0 => '2579847b-8fd7-11f1-ac06-bc24113ee005',
        1 => '72523f6a-5e66-11f1-ac01-bc24113ee005',
        2 => '157c5e35-0c4d-11f1-abf8-bc24113ee005',
        _ => 'guid-$i',
      },
      'code': switch (i) {
        0 => 'NT0000003',
        1 => 'NT0000002',
        2 => 'NT0000001',
        _ => 'NT00001${i.toString().padLeft(2, '0')}',
      },
      'name': switch (i) {
        0 => 'Danət Kassa',
        1 => 'Nərimanov kassası',
        2 => 'Əsas Kassa',
        3 => 'Nizami (6-cı Paralel) Mağazasının Kassası',
        4 => 'Bağlanmış kassa',
        _ => 'Kassa $i',
      },
      'currency': i == 3 || (i > 4 && i % 5 == 3) ? 'USD' : 'AZN',
      'is_active': i != 4,
      'created_at': '2026-09-18T13:58:33.728406',
      'updated_at': '2026-09-18T13:58:33.728406',
      'baza_id': 18,
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/cash-desks/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    sizes.add(size);
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
