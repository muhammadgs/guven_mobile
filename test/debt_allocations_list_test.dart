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
import 'package:guven_mobile/src/features/database/domain/debt_allocation.dart';
import 'package:guven_mobile/src/features/database/domain/debt_allocations_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/bank_account_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/cash_desk_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/debt_allocation_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Borc Bölgüsü` as the user meets it: `Menecer:` over the manager's name
/// in CalSans, `Tarix:` and `Bölgü:` with their values after them — no
/// sale guid; a tap opens nothing; the funnel's three columns; on every
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

  group('on the 402pt frame', () {
    testWidgets('the first share is the card asked for, line for line', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());

      expect(find.text('Borc Bölgüsü'), findsOneWidget);

      final Finder first = find.byType(DebtAllocationCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, as on the other `Maliyyə`
      // pages; a one-line name makes 141.2pt, 9pt to the next.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_oneLine, epsilon: 0.25));
      expect(
        tester.getRect(find.byType(DebtAllocationCard).at(1)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      // The website's sale guid is not on the card.
      expect(find.textContaining('491b97c3', findRichText: true), findsNothing);

      final Map<String, double> lines = <String, double>{
        // Its capitals where the other `Maliyyə` cards' names start.
        'Menecer:': DebtAllocationCard.kLabelBaseline,
        'Mühasib-istehsal': 58.19,
        'Tarix: 2026-10-07': 87.19,
        'Bölgü: 36,398.15 ₼': 116.19,
      };
      for (final MapEntry<String, double> line in lines.entries) {
        expect(inCard(line.key), findsOneWidget, reason: line.key);
        expect(
          _baseline(tester, inCard(line.key)) - card.top,
          moreOrLessEquals(line.value, epsilon: 0.25),
          reason: line.key,
        );
        expect(
          tester.getRect(inCard(line.key)).left - card.left,
          moreOrLessEquals(23, epsilon: 0.01),
          reason: line.key,
        );
      }
      // The first capitals 23.6pt down, as on `Kreditorlar`.
      expect(
        _baseline(tester, inCard('Menecer:')) - 14 * 0.698 - card.top,
        moreOrLessEquals(39 - 22 * 0.7, epsilon: 0.25),
      );
      // The name under its label as `Hesab adı:`'s is.
      expect(
        _baseline(tester, inCard('Mühasib-istehsal')) -
            22 * 0.7 -
            _baseline(tester, inCard('Menecer:')),
        moreOrLessEquals(BankAccountCard.kLabelSeenGap, epsilon: 0.25),
      );
      // Then the tab's one seen gap.
      expect(
        _baseline(tester, inCard('Tarix: 2026-10-07')) -
            14 * 0.698 -
            _baseline(tester, inCard('Mühasib-istehsal')),
        moreOrLessEquals(CashDeskCard.kSeenGap, epsilon: 0.25),
      );
      expect(
        _baseline(tester, inCard('Bölgü: 36,398.15 ₼')) -
            14 * 0.698 -
            _baseline(tester, inCard('Tarix: 2026-10-07')),
        moreOrLessEquals(CashDeskCard.kSeenGap, epsilon: 0.25),
      );
      // The last baseline 25pt above the bottom, as on `Kreditorlar`.
      expect(
        card.bottom - _baseline(tester, inCard('Bölgü: 36,398.15 ₼')),
        moreOrLessEquals(25, epsilon: 0.25),
      );

      // The name in CalSans, `Komanda`'s size; its label SemiBold.
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('Mühasib-istehsal')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(TeamCard.kName));
      final Text label = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('Menecer:')),
      );
      expect(label.style!.fontFamily, 'Poppins');
      expect(label.style!.fontWeight, FontWeight.w600);

      // The field names SemiBold, the values not; the share green.
      final Map<String, (String, String, Color)> pairs =
          <String, (String, String, Color)>{
            'Tarix: 2026-10-07': ('Tarix: ', '2026-10-07', kGlassInk),
            'Bölgü: 36,398.15 ₼': ('Bölgü: ', '36,398.15 ₼', kSaleDone),
          };
      for (final MapEntry<String, (String, String, Color)> pair
          in pairs.entries) {
        final Finder text = inCard(pair.key);
        final (String label, String value, Color color) = pair.value;
        expect(
          _styleOf(tester, text, label)!.fontWeight,
          FontWeight.w600,
          reason: label,
        );
        final TextStyle valueStyle = _styleOf(tester, text, value)!;
        expect(valueStyle.fontWeight, FontWeight.w400, reason: value);
        expect(valueStyle.color, color, reason: value);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a share 1C says nothing about says `—`, in ink', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
                DebtAllocationCard(row: DebtAllocation(id: 1)),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Tarix: —', findRichText: true), findsOneWidget);
      final Finder share = find.text('Bölgü: —', findRichText: true);
      expect(share, findsOneWidget);
      expect(_styleOf(tester, share, '—')!.color, kGlassInk);
      expect(
        tester.getSize(find.byType(DebtAllocationCard)).height,
        moreOrLessEquals(_oneLine, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder first = find.byType(DebtAllocationCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens the card\'s three fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final DebtAllocationsColumn column in DebtAllocationsColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bölgü is a minimum and a maximum', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Bölgü'));
      await tester.pumpAndSettle();
      expect(_inPanel('Min bölgü'), findsOneWidget);
      expect(_inPanel('Maks bölgü'), findsOneWidget);

      await tester.enterText(_field(0), '10000');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        database.debtAllocations.filter.share,
        const FilterRange(min: 10000),
      );

      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <double?>[
          for (final DebtAllocation row
              in database.debtAllocations.filtered!.rows)
            row.allocated,
        ],
        <double>[36398.15, 22544.7, 21136.15],
      );
      expect(find.byType(DebtAllocationCard), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tarix is a run of months', (WidgetTester tester) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Tarix'));
      await tester.pumpAndSettle();
      expect(_inPanel('Başlanğıc'), findsOneWidget);
      expect(_inPanel('Son'), findsOneWidget);

      // September as the start and the end.
      await tester.tap(_inPanel('Sentyabr'));
      await tester.pumpAndSettle();
      await tester.tap(_inPanel('Sentyabr'));
      await tester.pumpAndSettle();
      expect(
        database.debtAllocations.filter.period,
        const FilterPeriod(
          from: FilterMonth(2026, 9),
          to: FilterMonth(2026, 9),
        ),
      );

      await tester.tapAt(const Offset(390, 800));
      await tester.pumpAndSettle();
      expect(
        <String?>[
          for (final DebtAllocation row
              in database.debtAllocations.filtered!.rows)
            row.date,
        ],
        <String>['2026-09-01', '2026-09-21', '2026-09-17'],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Menecer lists every manager, the most collected first', (
      WidgetTester tester,
    ) async {
      final DatabaseController database = await _pump(tester, _Bridge());
      await _openFilter(tester);

      await tester.tap(_inPanel('Menecer'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(_inPanel('Mühasib-istehsal')).dy,
        lessThan(tester.getTopLeft(_inPanel('Nərimanov_S1')).dy),
      );
      await tester.tap(_inPanel('GF20'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 800));
      await tester.pumpAndSettle();
      expect(
        <int>[
          for (final DebtAllocation row
              in database.debtAllocations.filtered!.rows)
            row.id,
        ],
        <int>[14],
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
        '${device.name} @ ${fontScale}x — cards fit, and so do the three '
        'columns',
        (WidgetTester tester) async {
          await _pump(tester, _Bridge(), device: device, fontScale: fontScale);
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          final int built = find.byType(DebtAllocationCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(DebtAllocationCard).at(i);
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
            // The label never runs into the name under it.
            final Rect label = _drawn(
              tester.renderObject<RenderBox>(
                find.descendant(of: card, matching: find.text('Menecer:')),
              ),
            );
            final Finder nameText = find.descendant(
              of: card,
              matching: find.byWidgetPredicate(
                (Widget w) => w is Text && w.style?.fontFamily == 'CalSans',
              ),
            );
            final double nameCaps =
                _baseline(tester, nameText) - TeamCard.kName * 0.7 * s;
            expect(
              _baseline(
                    tester,
                    find.descendant(of: card, matching: find.text('Menecer:')),
                  ) <
                  nameCaps,
              isTrue,
              reason: 'label at $label',
            );
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
          for (final DebtAllocationsColumn column
              in DebtAllocationsColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// A card with a one-line name, on the 402pt frame: `Menecer:`'s baseline
/// 33.4pt down, the name's 58.2, then a row every 29pt; the last 25pt
/// above the bottom.
const double _oneLine = 116.19 + 25;

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
  final RenderParagraph paragraph = tester.renderObject(
    find.descendant(of: text, matching: find.byType(RichText), matchRoot: true),
  );
  final double baseline = paragraph.getDryBaseline(
    paragraph.constraints,
    TextBaseline.alphabetic,
  )!;
  return MatrixUtils.transformPoint(
    paragraph.getTransformTo(null),
    Offset(0, baseline),
  ).dy;
}

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
  )..select(DatabaseSection.debtAllocation);
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

/// The 1C bridge's first fifteen shares as it answered on 2026-10-22, the
/// largest first, and `Menecer Borcları`' managers for the filter.
class _Bridge {
  static const List<(int, String, String, String, double)> live =
      <(int, String, String, String, double)>[
        (
          532,
          '491b97c3-c23e-11f1-ac09-bc24113ee005',
          '2026-10-07',
          'Mühasib-istehsal',
          36398.15,
        ),
        (
          4158,
          'ff57e1d2-a5de-11f1-ac09-bc24113ee005',
          '2026-09-01',
          'Mühasib-istehsal',
          22544.7,
        ),
        (
          14,
          '356925ea-9191-11f1-ac06-bc24113ee005',
          '2026-08-06',
          'GF20',
          21136.15,
        ),
        (
          201,
          '200a43e7-865e-11f1-ac05-bc24113ee005',
          '2026-07-22',
          'Mühasib-istehsal',
          8147.68,
        ),
        (
          202,
          '4e3796f0-8a7b-11f1-ac06-bc24113ee005',
          '2026-07-28',
          'Mühasib-istehsal',
          8012.8,
        ),
        (
          203,
          '670d0231-9247-11f1-ac06-bc24113ee005',
          '2026-08-06',
          'Mühasib-istehsal',
          7957.67,
        ),
        (
          204,
          'aa6cab43-8727-11f1-ac05-bc24113ee005',
          '2026-07-23',
          'Mühasib-istehsal',
          7943.17,
        ),
        (
          205,
          '13c044ca-963e-11f1-ac06-bc24113ee005',
          '2026-08-12',
          'Mühasib-istehsal',
          7906.05,
        ),
        (
          206,
          '1768174d-75e1-11f1-ac05-bc24113ee005',
          '2026-07-02',
          'Mühasib-istehsal',
          7307.0,
        ),
        (
          207,
          'b2bcc2b6-8b6c-11f1-ac06-bc24113ee005',
          '2026-07-29',
          'Mühasib-istehsal',
          7061.29,
        ),
        (
          208,
          '19c9441a-b5c9-11f1-ac09-bc24113ee005',
          '2026-09-21',
          'Nərimanov_S1',
          6971.63,
        ),
        (
          209,
          'bf469c6b-b4da-11f1-ac09-bc24113ee005',
          '2026-09-17',
          'Mühasib-istehsal',
          6720.0,
        ),
        (
          210,
          '09d8f2e3-8727-11f1-ac05-bc24113ee005',
          '2026-07-23',
          'Mühasib-istehsal',
          6318.63,
        ),
        (
          211,
          '5a345920-908c-11f1-ac06-bc24113ee005',
          '2026-08-04',
          'Mühasib-istehsal',
          6292.03,
        ),
        (
          212,
          '7775def0-8726-11f1-ac05-bc24113ee005',
          '2026-07-23',
          'Mühasib-istehsal',
          6212.45,
        ),
      ];

  Map<String, Object?> row(int i) {
    final (int id, String sale, String date, String manager, double amount) =
        live[i];
    return <String, Object?>{
      'id': id,
      'sale_id': sale,
      'sale_date': date,
      'manager_id': 'manager-$manager',
      'phys_id': '00000000-0000-0000-0000-000000000000',
      'manager': manager,
      'allocated': amount,
      'baza_id': 18,
      'synced_at': null,
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (path.endsWith('/onec-data/manager-debt-stats/')) {
      return _json(<String, Object?>{
        'total': 3,
        'data': <Object?>[
          <String, Object?>{
            'id': 2,
            'manager': 'Nərimanov_S1',
            'collected': 142723.77,
          },
          <String, Object?>{'id': 6, 'manager': 'GF20', 'collected': 41775.55},
          <String, Object?>{
            'id': 1,
            'manager': 'Mühasib-istehsal',
            'collected': 516259.08,
          },
        ],
      });
    }
    if (!path.endsWith('/onec-data/manager-debt-allocations/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < live.length; i++)
        if (search == null ||
            '${row(i)['manager']} ${row(i)['sale_id']}'.toLowerCase().contains(
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
      'table': 'manager_debt_allocations',
      'baza_id': 18,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
