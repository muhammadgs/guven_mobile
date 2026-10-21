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
import 'package:guven_mobile/src/features/database/application/database_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/unit_of_measure.dart';
import 'package:guven_mobile/src/features/database/domain/units_of_measure_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/unit_of_measure_row.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/units_of_measure_list.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Ölçü Vahidləri` as the user meets it: the whole catalogue as the lines
/// of one card — code, name, international code on one baseline, a rule
/// between every two — closing under the last unit only once there is no
/// more to come; a tap opens nothing; the funnel's three columns; on every
/// phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where a line's words land depends on what they *measure*, so the
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

  group('on the design\'s frame', () {
    testWidgets('a line a unit, on one card, measured as drawn', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Ölçü Vahidləri'), findsOneWidget);

      Finder line(int i) => find.byType(UnitOfMeasureRow).at(i);
      final Rect first = tester.getRect(line(0));
      final Rect second = tester.getRect(line(1));

      // 19.5pt either side of a 363pt card, and the lines touching.
      for (final Rect box in <Rect>[first, second]) {
        expect(box.left, moreOrLessEquals(19.5, epsilon: 0.01));
        expect(box.width, moreOrLessEquals(363, epsilon: 0.01));
      }
      expect(second.top, moreOrLessEquals(first.bottom, epsilon: 0.01));
      expect(first.height, moreOrLessEquals(_firstLine, epsilon: 0.25));
      expect(second.height, moreOrLessEquals(_pitch, epsilon: 0.25));

      Finder inLine(int i, String text) =>
          find.descendant(of: line(i), matching: find.text(text));

      // The design's line — `110  Bağlama  Bağ` — is the second.
      final double baseline = _baseline(tester, inLine(1, 'Bağlama'));
      for (final String text in <String>['110', 'Bağ']) {
        expect(
          _baseline(tester, inLine(1, text)),
          moreOrLessEquals(baseline, epsilon: 0.01),
          reason: '$text on the name\'s baseline',
        );
      }
      // The first baseline 31pt down the card, the next a line further.
      expect(
        _baseline(tester, inLine(0, '104')) - first.top,
        moreOrLessEquals(31.0, epsilon: 0.25),
      );
      expect(
        baseline - _baseline(tester, inLine(0, '104')),
        moreOrLessEquals(_pitch, epsilon: 0.25),
      );

      // A 1pt rule 9.55pt under each baseline, 12pt short of either edge.
      final Rect rule = _rule(tester, line(1));
      expect(rule.height, moreOrLessEquals(1, epsilon: 0.01));
      expect(rule.center.dy - baseline, moreOrLessEquals(9.55, epsilon: 0.25));
      expect(rule.left - second.left, moreOrLessEquals(12, epsilon: 0.01));
      expect(second.right - rule.right, moreOrLessEquals(12, epsilon: 0.01));

      // The code at the card's 23pt, the international code at 305.3pt,
      // the name centred 175.1pt in.
      expect(
        tester.getRect(inLine(1, '110')).left - second.left,
        moreOrLessEquals(23, epsilon: 0.01),
      );
      expect(
        tester.getRect(inLine(1, 'Bağ')).left - second.left,
        moreOrLessEquals(305.3, epsilon: 0.01),
      );
      expect(
        tester.getRect(inLine(1, 'Bağlama')).center.dx - second.left,
        moreOrLessEquals(175.1, epsilon: 0.01),
      );

      // Each in the design's face.
      TextStyle styleOf(String text) =>
          tester.widget<Text>(inLine(1, text)).style!;
      expect(styleOf('110').fontFamily, kDatabaseFigureFont);
      expect(styleOf('110').fontSize, moreOrLessEquals(14));
      expect(styleOf('Bağlama').fontFamily, 'CalSans');
      expect(styleOf('Bağlama').fontSize, moreOrLessEquals(22));
      expect(styleOf('Bağ').fontFamily, 'Poppins');
      expect(styleOf('Bağ').fontStyle, FontStyle.italic);
      expect(styleOf('Bağ').fontSize, moreOrLessEquals(14));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a blank international code is no word at all', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      // `123  DƏFƏ`, nothing on the right — not a dash.
      final Finder times = find.byType(UnitOfMeasureRow).at(3);
      expect(
        find.descendant(of: times, matching: find.text('DƏFƏ')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: times, matching: find.byType(RichText)).evaluate(),
        hasLength(2),
      );
      expect(
        find.descendant(of: times, matching: find.text('—')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the card closes under the catalogue\'s last unit, and only '
        'once there is no more to come', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge(holdSecondPage: true);
      // Not settled: the spinner under the card turns for as long as page
      // two is held.
      final DatabaseController database = await _pump(
        tester,
        bridge,
        settle: false,
      );

      // Twenty read, twelve still to come: the twentieth keeps its rule.
      expect(database.unitsOfMeasure.units, hasLength(20));
      await tester.dragUntilVisible(
        find.text('dəst'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pump();
      final Finder twentieth = find.ancestor(
        of: find.text('dəst'),
        matching: find.byType(UnitOfMeasureRow),
      );
      expect(tester.widget<UnitOfMeasureRow>(twentieth).last, isFalse);
      expect(_rules(tester, twentieth), hasLength(1));

      bridge.release();
      await tester.pumpAndSettle();
      expect(database.unitsOfMeasure.units, hasLength(32));
      expect(tester.widget<UnitOfMeasureRow>(twentieth).last, isFalse);

      await tester.dragUntilVisible(
        find.text('əd'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder last = find.ancestor(
        of: find.text('əd'),
        matching: find.byType(UnitOfMeasureRow),
      );
      expect(tester.widget<UnitOfMeasureRow>(last).last, isTrue);
      // No rule under it, and its baseline 20pt off the card's foot.
      expect(_rules(tester, last), isEmpty);
      final Rect box = tester.getRect(last);
      expect(box.height, moreOrLessEquals(_lastLine, epsilon: 0.25));
      expect(
        box.bottom -
            _baseline(
              tester,
              find.descendant(of: last, matching: find.text('796')),
            ),
        moreOrLessEquals(20, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(UnitOfMeasureRow).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens the line\'s three fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final UnitsOfMeasureColumn column in UnitsOfMeasureColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Beynəlxalq kod reads the catalogue once and narrows the '
        'card to a code\'s units', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Beynəlxalq kod'));
      await tester.pumpAndSettle();
      expect(database.unitsOfMeasure.hasEveryone, isTrue);
      final int asked = bridge.sizes.length;

      await tester.tap(_inPanel('KGM'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <String?>[
          for (final UnitOfMeasure u in database.unitsOfMeasure.filtered!.rows)
            u.name,
        ],
        <String>['kletka', 'kq'],
      );
      // Nothing more was read for it.
      expect(bridge.sizes, hasLength(asked));

      // The two found are a card of their own: both its corners' lines.
      final Finder lines = find.byType(UnitOfMeasureRow);
      expect(lines, findsNWidgets(2));
      expect(tester.widget<UnitOfMeasureRow>(lines.first).first, isTrue);
      expect(tester.widget<UnitOfMeasureRow>(lines.last).last, isTrue);
      expect(find.text('2 vahid'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
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
      testWidgets('${device.name} @ ${fontScale}x — every line\'s words fit '
          'their places, apart, and so do the three columns', (
        WidgetTester tester,
      ) async {
        await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
        // The card's own padding on this phone: the design's 23pt, scaled
        // the way `databaseScale` scales it.
        final double s =
            (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

        final int built = find.byType(UnitOfMeasureRow).evaluate().length;
        for (int i = 0; i < built && i < 12; i++) {
          final Finder line = find.byType(UnitOfMeasureRow).at(i);
          final Rect box = tester.getRect(line);
          final Rect content = Rect.fromLTRB(
            box.left + 23 * s - 0.5,
            box.top,
            box.right - 23 * s + 0.5,
            box.bottom,
          );
          final List<Rect> words = <Rect>[];
          for (final Element text
              in find
                  .descendant(of: line, matching: find.byType(RichText))
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
            words.add(drawn);
          }
          // Left to right, never touching.
          words.sort((Rect a, Rect b) => a.left.compareTo(b.left));
          for (int k = 1; k < words.length; k++) {
            expect(
              words[k].left,
              greaterThan(words[k - 1].right + 4 * s),
              reason: 'line $i: ${words[k - 1]} runs into ${words[k]}',
            );
          }
          // The rule stays under the words.
          final List<Rect> rules = _rules(tester, line);
          if (rules.isNotEmpty) {
            for (final Rect word in words) {
              expect(word.bottom, lessThanOrEqualTo(rules.single.top + 0.01));
            }
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
        for (final UnitsOfMeasureColumn column in UnitsOfMeasureColumn.values) {
          inside(glass, tester.getRect(_inPanel(column.label)), column.label);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// A line's height on the design's frame: 7.31pt over the name's 26pt line,
/// 3.95pt to the 1pt rule — a baseline every 38.26pt.
const double _pitch = 38.26;

/// The first line: 2.79pt more above it, its baseline 31pt down the card.
const double _firstLine = _pitch + 2.79;

/// The last: no rule, and 14.9pt under its line.
const double _lastLine = 7.31 + 26 + 14.9;

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The rules drawn in [line]: the ink-coloured boxes in it.
List<Rect> _rules(WidgetTester tester, Finder line) => <Rect>[
  for (final Element box
      in find
          .descendant(
            of: line,
            matching: find.byWidgetPredicate(
              (Widget w) => w is ColoredBox && w.color == kGlassInk,
            ),
          )
          .evaluate())
    _drawn(box.renderObject! as RenderBox),
];

Rect _rule(WidgetTester tester, Finder line) => _rules(tester, line).single;

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
  of: find.byType(UnitsOfMeasureList),
  matching: find.byType(Scrollable),
);

/// [text] on the filter's glass, not on a line behind it.
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
  bool settle = true,
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
  )..select(DatabaseSection.unitsOfMeasure);
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  return controller;
}

/// The live catalogue, as the bridge answered on 2026-10-10: 32 units by
/// name, byte by byte — `[id, code, name, international code]`.
const List<(int, String, String, String)> _live =
    <(int, String, String, String)>[
      (491, '104', 'Ay', 'Ay'),
      (498, '110', 'Bağlama', 'Bağ'),
      (483, '113', 'Boy', 'm2'),
      (507, '123', 'DƏFƏ', ''),
      (490, '103', 'Gün', 'GN'),
      (492, '105', 'Kisə', 'Kis'),
      (503, '222', 'Komple', 'Kom'),
      (510, '112', 'L', 'LTR'),
      (493, '107', 'Nəfər', ''),
      (500, '888', 'Nəfər', 'N'),
      (486, '341', 'PK', 'PK'),
      (489, '102', 'PM', 'PM'),
      (487, '231', 'Qutu', 'Qt'),
      (496, '345', 'RL', ''),
      (495, '109', 'Reys', 'Rey'),
      (494, '108', 'TOP', 'Ay'),
      (481, '444', 'Ton', ''),
      (505, '333', 'Xidmət', 'X'),
      (485, '223', 'cüt', ''),
      (484, '121', 'dəst', 'dst'),
      (501, '412', 'gecə', 'GC'),
      (502, '207', 'kletka', 'KGM'),
      (499, '555', 'km', ''),
      (511, '166', 'kq', 'KGM'),
      (488, '342', 'kub', 'm3'),
      (506, '111', 'kubmetr', ''),
      (509, '106', 'm', 'MTR'),
      (482, '101', 'm2', 'm2'),
      (504, '794', 'paqonmetr', 'PCE'),
      (508, '129', 'pors', '129'),
      (497, '212', 'Çəllək', 'Ay'),
      (512, '796', 'əd', 'PCE'),
    ];

/// The 1C bridge's units of measure, the live 32. With [holdSecondPage] the
/// answer to page two waits for [release], so the list can be seen with
/// more still to come.
class _Bridge {
  _Bridge({this.holdSecondPage = false});

  final bool holdSecondPage;
  final Completer<void> _held = Completer<void>();

  void release() => _held.complete();

  /// Every list request's page size.
  final List<int> sizes = <int>[];

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/units-of-measure/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    sizes.add(size);
    if (holdSecondPage && page > 1) await _held.future;

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final (int id, String code, String name, String international)
          in _live)
        if (search == null ||
            code.contains(search) ||
            name.toLowerCase().contains(search.toLowerCase()))
          <String, Object?>{
            'id': id,
            'onec_guid': 'guid-$id',
            'code': code,
            'name': name,
            'international_code': international,
            'baza_id': 18,
          },
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
