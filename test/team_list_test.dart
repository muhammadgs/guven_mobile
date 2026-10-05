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
import 'package:guven_mobile/src/features/database/domain/team_filter.dart';
import 'package:guven_mobile/src/features/database/domain/team_member.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Komanda` as the user meets it: the design's card, row for row; a field
/// 1C left blank is no row at all; a tap opens nothing; the funnel's six
/// columns; on every phone.
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
    testWidgets('a person with every field is the design\'s card, row for '
        'row', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      // The page's own name under `Baza` — the design's says `Müştərilər`,
      // which the user called a slip (2026-10-05).
      expect(find.text('Komanda'), findsOneWidget);
      expect(find.text('Müştərilər'), findsNothing);

      final Finder first = find.byType(TeamCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, on the design's 402pt frame;
      // 238pt tall with a two-line name and all four rows.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(238, epsilon: 0.25));
      // 9pt to the next, as on `Müştərilər`' frame it was drawn in.
      expect(
        tester.getRect(find.byType(TeamCard).at(1)).top - card.bottom,
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

      // The design's baselines, measured at 2px a point.
      onBaseline('0000000051', 27.5);
      onBaseline('Məhərrəmova Pərvanə Ələstun qızı', 66);
      onBaseline('Vəzifə: Paketçi', 129);
      onBaseline('Şöbə: ƏSAS şöbə', 158);
      onBaseline('Maaş: 687.00 ₼', 187);
      onBaseline('Status:  aktiv', 216);

      // The name at the design's 22pt, wrapped onto two 29pt lines.
      final Finder name = find.descendant(
        of: first,
        matching: find.text('Məhərrəmova Pərvanə Ələstun qızı'),
      );
      final Text nameText = tester.widget<Text>(name);
      expect(nameText.style!.fontSize, moreOrLessEquals(22));
      expect(nameText.style!.fontFamily, 'CalSans');
      expect(tester.getSize(name).height, moreOrLessEquals(58, epsilon: 0.5));
      // Broken where the design breaks it — `Məhərrəmova Pərvanə / Ələstun
      // qızı` — not with `qızı` left alone on the second line, which is
      // where filling the first line as full as it goes would put it.
      final RenderParagraph lines = tester.renderObject(name);
      double lineOf(String word) {
        final int at = nameText.data!.indexOf(word);
        return lines
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 1),
            )
            .first
            .top;
      }

      expect(lineOf('Pərvanə'), moreOrLessEquals(0, epsilon: 0.5));
      expect(lineOf('Ələstun'), moreOrLessEquals(29, epsilon: 0.5));
      expect(lineOf('qızı'), moreOrLessEquals(29, epsilon: 0.5));

      // Every row at the content's edge; the code in the tab's figures.
      for (final String text in <String>[
        '0000000051',
        'Vəzifə: Paketçi',
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
              find.descendant(of: first, matching: find.text('0000000051')),
            )
            .style!
            .fontFamily,
        kDatabaseFigureFont,
      );

      // `aktiv` in the tab's green.
      expect(_colourOf(tester, inCard('Status:  aktiv'), 'aktiv'), kSaleDone);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a field 1C left blank is no row, and the card closes up', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      Finder card(int i) => find.byType(TeamCard).at(i);
      Finder inCard(int i, String text) => find.descendant(
        of: card(i),
        matching: find.textContaining(text, findRichText: true),
      );

      // Nothing but the status: no `Vəzifə`, `Şöbə` or `Maaş` row — not
      // even one saying `—` — and three rows shorter than the design's, on
      // top of a name that fits one line.
      expect(inCard(1, 'Status:  aktiv'), findsOneWidget);
      for (final String label in <String>['Vəzifə', 'Şöbə', 'Maaş', '—']) {
        expect(inCard(1, label), findsNothing, reason: label);
      }
      expect(
        tester.getSize(card(1)).height,
        moreOrLessEquals(238 - 29 - 3 * 29, epsilon: 0.25),
      );
      // The status comes up to where the first row would have been, 34pt
      // under the name.
      final Rect second = tester.getRect(card(1));
      expect(
        _baseline(tester, inCard(1, 'Status')) - second.top,
        moreOrLessEquals(66 + 34, epsilon: 0.25),
      );

      // A department and no position or salary: two rows.
      expect(inCard(2, 'Şöbə: Ağ Şəhər'), findsOneWidget);
      expect(inCard(2, 'Vəzifə'), findsNothing);
      expect(inCard(2, 'Maaş'), findsNothing);
      expect(
        tester.getSize(card(2)).height,
        moreOrLessEquals(238 - 29 - 2 * 29, epsilon: 0.25),
      );

      // A one-line name is one 29pt line shorter.
      expect(
        tester.getSize(card(3)).height,
        moreOrLessEquals(238 - 29, epsilon: 0.25),
      );
      expect(
        find.descendant(
          of: card(3),
          matching: find.text('Maaş: 1,160.00 ₼', findRichText: true),
        ),
        findsOneWidget,
      );

      // A person 1C has switched off: `deaktiv`, in red.
      await tester.dragUntilVisible(
        find.text('Hüseynov Emil'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder off = find.descendant(
        of: find.ancestor(
          of: find.text('Hüseynov Emil'),
          matching: find.byType(TeamCard),
        ),
        matching: find.text('Status:  deaktiv', findRichText: true),
      );
      expect(off, findsOneWidget);
      expect(_colourOf(tester, off, 'deaktiv'), kSalePending);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(TeamCard).first;
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
    testWidgets('the funnel opens the card\'s six fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final TeamColumn column in TeamColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Şöbə reads the register once and lists every department, '
        'the most common first', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Şöbə'));
      await tester.pumpAndSettle();
      expect(database.team.hasEveryone, isTrue);
      expect(bridge.sizes, <int>[20, 20]);
      expect(
        tester.getTopLeft(_inPanel('ƏSAS şöbə')).dy,
        lessThan(tester.getTopLeft(_inPanel('Nərimanov')).dy),
      );

      await tester.tap(_inPanel('Ağ Şəhər'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <int>[
          for (final TeamMember member in database.team.filtered!.rows)
            member.id,
        ],
        <int>[3, 13, 23, 33],
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
        '${device.name} @ ${fontScale}x — cards fit, and so do the six '
        'columns',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          final int built = find.byType(TeamCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(TeamCard).at(i);
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
          for (final TeamColumn column in TeamColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
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
  of: find.byType(TeamList),
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
  )..select(DatabaseSection.team);
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

/// The 1C bridge's staff register, forty deep, in its order. The first is
/// the design's person; the second has nothing but a status, as most of the
/// live register does; the third a department only; the fourth every field
/// under a one-line name; the fifth switched off. After them every tenth
/// from the fourth is in `Ağ Şəhər`, and the rest are spread over the
/// departments.
class _Bridge {
  /// The page of every unfiltered list request of the list's own size.
  final List<int> pages = <int>[];

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  static const int total = 40;

  Map<String, Object?> row(int i) => <String, Object?>{
    'id': i + 1,
    'onec_guid': 'guid-$i',
    'code': switch (i) {
      0 => '0000000051',
      1 => 'д000000014',
      _ => '00000001${i.toString().padLeft(2, '0')}',
    },
    'full_name': switch (i) {
      0 => 'Məhərrəmova Pərvanə Ələstun qızı',
      1 => 'Abdullayev Rəşad Asif oğlu',
      2 => 'Babayeva Dürrxanım Fazil qızı',
      3 => 'Abdullayev Rəşad Asif',
      4 => 'Hüseynov Emil',
      _ => 'Əməkdaş $i',
    },
    'position': switch (i) {
      0 => 'Paketçi',
      3 => 'Qəssab',
      _ => '',
    },
    'department': switch (i) {
      0 || 3 => 'ƏSAS şöbə',
      1 || 4 => '',
      2 => 'Ağ Şəhər',
      _ when i % 10 == 2 => 'Ağ Şəhər',
      _ when i == 7 => 'Nərimanov',
      _ => 'ƏSAS şöbə',
    },
    'phone': null,
    'email': null,
    'hire_date': null,
    'salary': switch (i) {
      0 => 687.0,
      3 => 1160.0,
      4 => 1000.0,
      _ => 0.0,
    },
    'is_active': i != 4,
    'baza_id': 18,
  };

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/onec-data/team/')) {
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
            '${row(i)['code']} ${row(i)['full_name']} '
                    '${row(i)['position']} ${row(i)['department']}'
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
