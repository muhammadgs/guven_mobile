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
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/domain/manager_debt.dart';
import 'package:guven_mobile/src/features/database/domain/manager_debts_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/cash_desk_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/manager_debt_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/manager_debts_list.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Menecer Borcları` as the user meets it: the design's card — five
/// fields, 29pt apart, the share as it really is — a tap opens nothing; the
/// funnel's six columns, every figure a span; on every phone.
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
    testWidgets('the first manager is the design\'s card, line for line', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Menecer Borcları'), findsOneWidget);

      final Finder first = find.byType(ManagerDebtCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, on the 402pt frame; a one-line
      // name makes 213.75pt.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_oneLine, epsilon: 0.25));
      // 9pt to the next.
      expect(
        tester.getRect(find.byType(ManagerDebtCard).at(1)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      // The design's baselines, measured off its frame at 2px a point.
      final Map<String, double> lines = <String, double>{
        'Mühasib-istehsal': 39,
        'Sifariş: 668': 68,
        'Satış: 529,495.28 ₼': 97,
        'Debet: 17,349.99 ₼': 126,
        'Yığılmış: 512,145.29 ₼': 155,
        // 96.7233…%, cut to two places — not the website's 97%.
        'Statistika: 96.72%': 184,
      };
      for (final MapEntry<String, double> line in lines.entries) {
        expect(inCard(line.key), findsOneWidget, reason: line.key);
        expect(
          _baseline(tester, inCard(line.key)) - card.top,
          moreOrLessEquals(line.value, epsilon: 0.25),
          reason: line.key,
        );
        // Every line at the content's edge.
        expect(
          tester.getRect(inCard(line.key)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: line.key,
        );
      }
      // Every gap the one seen gap of the tab's cards.
      final List<String> order = lines.keys.toList();
      for (int i = 1; i < order.length; i++) {
        expect(
          _baseline(tester, inCard(order[i])) -
              14 * 0.698 -
              _baseline(tester, inCard(order[i - 1])),
          moreOrLessEquals(CashDeskCard.kSeenGap, epsilon: 0.25),
          reason: '${order[i - 1]} → ${order[i]}',
        );
      }

      // The name in `Komanda`'s face and size.
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('Mühasib-istehsal')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(TeamCard.kName));

      // The field names SemiBold, the values not; what is owed red, what
      // has come in green.
      final Map<String, (String, String, Color?)> pairs =
          <String, (String, String, Color?)>{
            'Sifariş: 668': ('Sifariş: ', '668', null),
            'Satış: 529,495.28 ₼': ('Satış: ', '529,495.28 ₼', null),
            'Debet: 17,349.99 ₼': ('Debet: ', '17,349.99 ₼', kSalePending),
            'Yığılmış: 512,145.29 ₼': ('Yığılmış: ', '512,145.29 ₼', kSaleDone),
            'Statistika: 96.72%': ('Statistika: ', '96.72%', kSaleDone),
          };
      for (final MapEntry<String, (String, String, Color?)> pair
          in pairs.entries) {
        final Finder text = inCard(pair.key);
        final (String label, String value, Color? color) = pair.value;
        expect(
          _styleOf(tester, text, label)!.fontWeight,
          FontWeight.w600,
          reason: label,
        );
        final TextStyle valueStyle = _styleOf(tester, text, value)!;
        expect(valueStyle.fontWeight, FontWeight.w400, reason: value);
        expect(valueStyle.color, color ?? kGlassInk, reason: value);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a share is shown as it is: 98.99% for a manager still owed '
        'money, 100% only for one owed nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());

      Finder cardOf(String manager) => find.ancestor(
        of: find.text(manager),
        matching: find.byType(ManagerDebtCard),
      );
      Finder line(String manager, String text) => find.descendant(
        of: cardOf(manager),
        matching: find.text(text, findRichText: true),
      );

      await tester.dragUntilVisible(
        find.text('Mühasib Köməkçisi'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      // 98.9985% — the website's `Math.round` would say 99, and from 99.5%
      // up, 100.
      expect(line('Mühasib Köməkçisi', 'Statistika: 98.99%'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Nizami_S2'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(line('Nizami_S2', 'Debet: 0.00 ₼'), findsOneWidget);
      expect(line('Nizami_S2', 'Statistika: 100%'), findsOneWidget);
      expect(
        tester.getSize(cardOf('Nizami_S2')).height,
        moreOrLessEquals(_oneLine, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(ManagerDebtCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('the share\'s colour', () {
    test('the website\'s grades, on the share the card prints', () {
      expect(ManagerDebtCard.shareTone(10000), kSaleDone);
      expect(ManagerDebtCard.shareTone(7000), kSaleDone);
      // 69.99% is not 70%, though the website's `Math.round` would make it.
      expect(ManagerDebtCard.shareTone(6999), kShareMiddling);
      expect(ManagerDebtCard.shareTone(4000), kShareMiddling);
      expect(ManagerDebtCard.shareTone(3999), kSalePending);
      expect(ManagerDebtCard.shareTone(0), kSalePending);
    });

    testWidgets('green, amber and red on the card; no share, ink', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  ManagerDebtCard(
                    row: ManagerDebt(
                      id: 1,
                      manager: 'Yaxşı',
                      sales: 1000,
                      debt: 100,
                      collected: 900,
                    ),
                  ),
                  ManagerDebtCard(
                    row: ManagerDebt(
                      id: 2,
                      manager: 'Orta',
                      sales: 1000,
                      debt: 450,
                      collected: 550,
                    ),
                  ),
                  ManagerDebtCard(
                    row: ManagerDebt(
                      id: 3,
                      manager: 'Zəif',
                      sales: 1000,
                      debt: 800,
                      collected: 200,
                    ),
                  ),
                  ManagerDebtCard(
                    row: ManagerDebt(id: 4, manager: 'Satışsız', sales: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      Color? toneOf(String manager, String share) {
        final Finder line = find.descendant(
          of: find.ancestor(
            of: find.text(manager),
            matching: find.byType(ManagerDebtCard),
          ),
          matching: find.text('Statistika: $share', findRichText: true),
        );
        expect(line, findsOneWidget, reason: manager);
        return _styleOf(tester, line, share)!.color;
      }

      expect(toneOf('Yaxşı', '90%'), kSaleDone);
      expect(toneOf('Orta', '55%'), kShareMiddling);
      expect(toneOf('Zəif', '20%'), kSalePending);
      expect(toneOf('Satışsız', '—'), kGlassInk);
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
      for (final ManagerDebtsColumn column in ManagerDebtsColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Statistika is a minimum and a maximum, held against the '
        'share the card prints', (WidgetTester tester) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Statistika'));
      await tester.pumpAndSettle();
      expect(_inPanel('Min faiz'), findsOneWidget);
      expect(_inPanel('Maks faiz'), findsOneWidget);

      await tester.enterText(_field(1), '95');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        database.managerDebts.filter.rangeOf(ManagerDebtsColumn.share),
        const FilterRange(max: 95),
      );

      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <String?>[
          for (final ManagerDebt row in database.managerDebts.filtered!.rows)
            row.manager,
        ],
        <String>['Nizami_S1', 'Ağ Şəhər_S1', 'Badamdar_S2', 'Mühasib'],
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Menecer lists every manager, the largest debt first', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Menecer'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(_inPanel('Mühasib-istehsal')).dy,
        lessThan(tester.getTopLeft(_inPanel('Nizami_S1')).dy),
      );
      await tester.tap(_inPanel('Nizami_S1'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(
        <int>[
          for (final ManagerDebt row in database.managerDebts.filtered!.rows)
            row.id,
        ],
        <int>[4],
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

          final int built = find.byType(ManagerDebtCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(ManagerDebtCard).at(i);
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
          for (final ManagerDebtsColumn column in ManagerDebtsColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// A card with a one-line name, on the 402pt frame: the name's baseline
/// 39pt down, then a field every 29pt; the last 29.75pt above the bottom.
const double _oneLine = 184 + 29.75;

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The style [word] is drawn in, inside the rich [text]: its own, or the
/// one it takes from the span around it.
TextStyle? _styleOf(WidgetTester tester, Finder text, String word) {
  TextStyle? found;
  void visit(InlineSpan span, TextStyle? inherited) {
    if (found != null || span is! TextSpan) return;
    final TextStyle? style = inherited?.merge(span.style) ?? span.style;
    if (span.text == word) {
      found = style;
      return;
    }
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      visit(child, style);
    }
  }

  visit(tester.widget<RichText>(text).text, null);
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
  of: find.byType(ManagerDebtsList),
  matching: find.byType(Scrollable),
);

/// [text] on the filter's glass, not on a card behind it.
Finder _inPanel(String text) => find.descendant(
  of: find.byType(DatabaseFilterPanel),
  matching: find.text(text),
);

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
  )..select(DatabaseSection.managerDebts);
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

/// The 1C bridge's managers as it answered on 2026-10-21: all thirteen, the
/// largest debt first.
class _Bridge {
  static const List<(int, String, int, double, double, double)> live =
      <(int, String, int, double, double, double)>[
        (1, 'Mühasib-istehsal', 668, 529495.28, 17349.99, 512145.29),
        (4, 'Nizami_S1', 660, 100140.12, 7513.55, 92626.57),
        (3, 'Ağ Şəhər_S1', 1070, 106067.46, 7501.66, 98565.8),
        (2, 'Nərimanov_S1', 832, 145234.98, 3612.81, 141622.17),
        (5, 'S_Vurğun_S1', 1126, 72753.45, 2777.05, 69976.4),
        (7, 'Badamdar_S2', 511, 42049.43, 2147.8, 39901.63),
        (6, 'GF20', 82, 42255.13, 479.58, 41775.55),
        (13, 'Mühasib', 8, 2323.4, 279.66, 2043.74),
        (10, 'S_Vurğun_S2', 262, 16635.07, 255.54, 16379.53),
        (12, 'Mühasib Köməkçisi', 27, 6230.85, 62.4, 6168.45),
        (11, 'Badamdar_S1', 199, 14817.23, 0.0, 14817.23),
        (9, 'Ağ Şəhər_S2', 353, 23433.84, 0.0, 23433.84),
        (8, 'Nizami_S2', 484, 40339.2, 0.0, 40339.2),
      ];

  Map<String, Object?> row(int i) {
    final (
      int id,
      String manager,
      int orders,
      double sales,
      double debt,
      double collected,
    ) = live[i];
    return <String, Object?>{
      'id': id,
      'manager_id': 'manager-$id',
      'phys_id': '00000000-0000-0000-0000-000000000000',
      'manager': manager,
      'orders_count': orders,
      'total_sales': sales,
      'total_debet': debt,
      'collected': collected,
      'baza_id': 18,
      'synced_at': '2026-10-19T23:19:34',
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/onec-data/manager-debt-stats/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < live.length; i++)
        if (search == null ||
            '${row(i)['manager']}'.toLowerCase().contains(search.toLowerCase()))
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
      'table': 'manager_debt_stats',
      'baza_id': 18,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
