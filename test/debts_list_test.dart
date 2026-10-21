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
import 'package:guven_mobile/src/features/database/domain/debt.dart';
import 'package:guven_mobile/src/features/database/domain/debts_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/bank_account_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/cash_desk_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/debt_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/debts_list.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Kreditorlar` and `Debitorlar` as the user meets them: one card drawn
/// twice — `Borcumuz` in red, `Borc` in green — with SemiBold field names,
/// every gap one gap; a tap opens nothing; the funnel's six columns; on
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

  group('on the frame it was drawn on', () {
    testWidgets('a creditor is the design\'s card, line for line', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge(DebtKind.creditors));

      expect(find.text('Kreditorlar'), findsOneWidget);

      final Finder first = find.byType(DebtCard).first;
      final Rect card = tester.getRect(first);

      // 19.5pt either side of a 363pt card, on the 402pt frame; a one-line
      // name, organisation and contract make 247.4pt.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_oneLine, epsilon: 0.25));
      // 9pt to the next.
      expect(
        tester.getRect(find.byType(DebtCard).at(1)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      final Map<String, double> lines = <String, double>{
        // 1C's tripled spaces made one; the underscores are the name's.
        'ORXAN ƏT MMC __': 39,
        'Təşkilat:': 68,
        'NaTural-İD': 87.19,
        'Müqavilə:': 116.19,
        // 1C's trailing space dropped.
        '2026 Əsas müqavilə': 135.37,
        'Borcumuz: 482,813.55 ₼': 164.37,
        'Hesablaşma: 482,813.55 ₼': 193.37,
        'Status:  Açıq borc': 222.37,
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

      // Every gap one gap, as it is seen — a baseline to the capitals under
      // it — and a label over its value closer, as on `Bank Hesabları`.
      double seen(String above, String below) =>
          _baseline(tester, inCard(below)) -
          14 * 0.698 -
          _baseline(tester, inCard(above));
      expect(
        _baseline(tester, inCard('Təşkilat:')) -
            14 * 0.698 -
            _baseline(tester, inCard('ORXAN ƏT MMC __')),
        moreOrLessEquals(CashDeskCard.kSeenGap, epsilon: 0.25),
      );
      for (final (String, String) pair in <(String, String)>[
        ('NaTural-İD', 'Müqavilə:'),
        ('2026 Əsas müqavilə', 'Borcumuz: 482,813.55 ₼'),
        ('Borcumuz: 482,813.55 ₼', 'Hesablaşma: 482,813.55 ₼'),
        ('Hesablaşma: 482,813.55 ₼', 'Status:  Açıq borc'),
      ]) {
        expect(
          seen(pair.$1, pair.$2),
          moreOrLessEquals(CashDeskCard.kSeenGap, epsilon: 0.25),
          reason: '${pair.$1} → ${pair.$2}',
        );
      }
      for (final (String, String) pair in <(String, String)>[
        ('Təşkilat:', 'NaTural-İD'),
        ('Müqavilə:', '2026 Əsas müqavilə'),
      ]) {
        expect(
          seen(pair.$1, pair.$2),
          moreOrLessEquals(BankAccountCard.kLabelSeenGap, epsilon: 0.25),
          reason: '${pair.$1} → ${pair.$2}',
        );
      }

      // The name in `Komanda`'s face and size.
      final Text name = tester.widget<Text>(
        find.descendant(of: first, matching: find.text('ORXAN ƏT MMC __')),
      );
      expect(name.style!.fontFamily, 'CalSans');
      expect(name.style!.fontSize, moreOrLessEquals(TeamCard.kName));

      // The field names SemiBold — the user's change — and the values not.
      for (final String label in <String>['Təşkilat:', 'Müqavilə:']) {
        expect(
          tester
              .widget<Text>(
                find.descendant(of: first, matching: find.text(label)),
              )
              .style!
              .fontWeight,
          FontWeight.w600,
          reason: label,
        );
      }
      expect(
        tester
            .widget<Text>(
              find.descendant(of: first, matching: find.text('NaTural-İD')),
            )
            .style!
            .fontWeight,
        FontWeight.w400,
      );
      final Finder amount = inCard('Borcumuz: 482,813.55 ₼');
      expect(
        _styleOf(tester, amount, 'Borcumuz: ')!.fontWeight,
        FontWeight.w600,
      );
      expect(
        _styleOf(tester, amount, '482,813.55 ₼')!.fontWeight,
        FontWeight.w400,
      );

      // Money going out, in red; the open debt, in red.
      expect(_styleOf(tester, amount, '482,813.55 ₼')!.color, kSalePending);
      expect(
        _styleOf(
          tester,
          inCard('Hesablaşma: 482,813.55 ₼'),
          '482,813.55 ₼',
        )!.color,
        kSalePending,
      );
      expect(
        _styleOf(tester, inCard('Status:  Açıq borc'), 'Açıq borc')!.color,
        kSalePending,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long contract runs to a second line, 21pt under the '
        'first, and a long name keeps its last word company', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge(DebtKind.creditors));
      Finder card(int i) => find.byType(DebtCard).at(i);

      // `LADES GROUP MMC *`: the contract 1C cut at fifty characters.
      final Finder contract = find.descendant(
        of: card(1),
        matching: find.text(
          '08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M',
        ),
      );
      final RenderParagraph paragraph = tester.renderObject(contract);
      expect(paragraph.size.height, moreOrLessEquals(42, epsilon: 0.01));
      expect(
        tester.getSize(card(1)).height,
        moreOrLessEquals(_oneLine + 21, epsilon: 0.25),
      );

      // `ŞAMAXI PALACE …`: two 29pt lines, never `___` on its own.
      final Finder name = find.descendant(
        of: card(2),
        matching: find.text('ŞAMAXI PALACE - YENİ ŞAMAXİ HOTEL COMPANY ___'),
      );
      final RenderParagraph named = tester.renderObject(name);
      expect(named.size.height, moreOrLessEquals(58, epsilon: 0.01));
      // The second line starts where a finger on its left end lands.
      const String text = 'ŞAMAXI PALACE - YENİ ŞAMAXİ HOTEL COMPANY ___';
      final int second = named
          .getPositionForOffset(const Offset(1, 29 + 14.5))
          .offset;
      expect(text.substring(second).trim(), contains(' '));
      expect(
        tester.getSize(card(2)).height,
        moreOrLessEquals(_oneLine + 29, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a debtor is the same card: `Borc`, in green', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge(DebtKind.debitors));

      expect(find.text('Debitorlar'), findsOneWidget);
      final Finder first = find.byType(DebtCard).first;
      Finder inCard(String text) => find.descendant(
        of: first,
        matching: find.text(text, findRichText: true),
      );

      final Finder amount = inCard('Borc: 291,704.59 ₼');
      expect(amount, findsOneWidget);
      expect(inCard('Borcumuz: 291,704.59 ₼'), findsNothing);
      expect(
        _baseline(tester, amount) - tester.getRect(first).top,
        moreOrLessEquals(164.37, epsilon: 0.25),
      );
      // Money coming in, in green; the debt still open, in red.
      expect(_styleOf(tester, amount, '291,704.59 ₼')!.color, kSaleDone);
      expect(
        _styleOf(
          tester,
          inCard('Hesablaşma: 291,704.59 ₼'),
          '291,704.59 ₼',
        )!.color,
        kSaleDone,
      );
      expect(
        _styleOf(tester, inCard('Status:  Açıq borc'), 'Açıq borc')!.color,
        kSalePending,
      );
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(_oneLine, epsilon: 0.25),
      );

      // A debt with nothing left on it is paid — the website's test — and
      // says so in green.
      await tester.dragUntilVisible(
        find.text('Ödənmiş MMC'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final Finder paid = find.descendant(
        of: find.ancestor(
          of: find.text('Ödənmiş MMC'),
          matching: find.byType(DebtCard),
        ),
        matching: find.text('Status:  Ödənilib', findRichText: true),
      );
      expect(paid, findsOneWidget);
      expect(_styleOf(tester, paid, 'Ödənilib')!.color, kSaleDone);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap opens nothing', (WidgetTester tester) async {
      await _pump(tester, _Bridge(DebtKind.creditors));
      final Finder first = find.byType(DebtCard).first;
      final double before = tester.getSize(first).height;

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge(DebtKind.debitors);
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      for (int i = 0; i < 6; i++) {
        await tester.drag(_list(), const Offset(0, -800));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    for (final DebtKind kind in DebtKind.values) {
      testWidgets('the funnel opens the ${kind.name}\' card\'s six fields', (
        WidgetTester tester,
      ) async {
        await _pump(tester, _Bridge(kind));
        await _openFilter(tester);

        expect(find.text('Filter'), findsOneWidget);
        for (final DebtsColumn column in DebtsColumn.of(kind)) {
          expect(_inPanel(column.label), findsOneWidget, reason: column.label);
        }
        // The amount by the card's own name only.
        expect(
          _inPanel(kind == DebtKind.creditors ? 'Borc' : 'Borcumuz'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Müqavilə reads the list once and lists every contract, the '
        'most common first', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge(DebtKind.creditors);
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Müqavilə'));
      await tester.pumpAndSettle();
      expect(database.creditors.hasEveryone, isTrue);
      expect(
        tester.getTopLeft(_inPanel('Əsas müqavilə')).dy,
        lessThan(tester.getTopLeft(_inPanel('2026 Əsas müqavilə')).dy),
      );

      await tester.tap(_inPanel('2026 Əsas müqavilə'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(
        <int>[
          for (final Debt debt in database.creditors.filtered!.rows) debt.id,
        ],
        <int>[1, 9, 17, 25],
      );
      expect(
        find.descendant(
          of: find.byType(GlassToolButton),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Debitorlar has its own filter, and none is on.
      expect(database.debitors.isFiltered, isFalse);
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
          await _pump(
            tester,
            _Bridge(DebtKind.creditors),
            device: device,
            fontScale: fontScale,
          );
          // The card's own padding on this phone: the design's 23pt, scaled
          // the way `databaseScale` scales it.
          final double s =
              (device.size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;

          final int built = find.byType(DebtCard).evaluate().length;
          for (int i = 0; i < built && i < 6; i++) {
            final Finder card = find.byType(DebtCard).at(i);
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
          for (final DebtsColumn column in DebtsColumn.of(DebtKind.creditors)) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// A card with a one-line name, organisation and contract, on the 402pt
/// frame: the name's baseline 39pt down, then every line 29pt under the one
/// before but a value under its label, 19.2pt; the last 25pt above the
/// bottom.
const double _oneLine = 222.37 + 25;

/// Where [box] actually lands on screen. A text inside a `FittedBox` keeps
/// its unscaled size; only the transform says how small it was drawn.
Rect _drawn(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The style [word] is drawn in, inside the rich [text].
TextStyle? _styleOf(WidgetTester tester, Finder text, String word) {
  TextStyle? found;
  tester.widget<RichText>(text).text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == word) {
      found = span.style;
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
  of: find.byType(DebtsList),
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
  final DatabaseController controller =
      DatabaseController(
        session,
        api: DatabaseApi(
          ApiClient(
            tokens: TokenStore(),
            httpClient: MockClient(bridge.answer),
          ),
        ),
      )..select(switch (bridge.kind) {
        DebtKind.creditors => DatabaseSection.creditors,
        DebtKind.debitors => DatabaseSection.debitors,
      });
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

/// The 1C bridge's creditors or debtors, thirty deep, the largest first as
/// it gives them. The first is the live list's own first row, as read on
/// 2026-10-20; the second has `LADES GROUP`'s long contract and the third
/// `ŞAMAXI PALACE`'s long name; the fourth owes nothing. After them every
/// eighth from the ninth is under `2026 Əsas müqavilə ` (1C's trailing
/// space), the rest `Əsas müqavilə`.
class _Bridge {
  _Bridge(this.kind);

  final DebtKind kind;

  /// The page of every unfiltered list request of the list's own size.
  final List<int> pages = <int>[];

  static const int total = 30;

  Map<String, Object?> row(int i) {
    final bool creditors = kind == DebtKind.creditors;
    return <String, Object?>{
      'id': i + 1,
      'onec_guid': 'guid-$i',
      'contractor': switch (i) {
        0 => creditors ? 'ORXAN ƏT MMC   __' : 'Pərakəndə müştəri-Nərimanov',
        1 => 'LADES GROUP MMC *',
        2 => 'ŞAMAXI PALACE - YENİ ŞAMAXİ HOTEL COMPANY   ___',
        3 => 'Ödənmiş MMC',
        _ => 'Kontraqent $i',
      },
      'contract_id': 'contract-$i',
      'contract': switch (i) {
        0 => creditors ? '2026 Əsas müqavilə ' : 'Əsas müqavilə',
        1 => '08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M',
        _ when i % 8 == 0 => '2026 Əsas müqavilə ',
        _ => 'Əsas müqavilə',
      },
      'total_debt': switch (i) {
        0 => creditors ? 482813.55 : 291704.59,
        3 => 0.0,
        _ => (total - i) * 1000.0,
      },
      'settlement_total': switch (i) {
        0 => creditors ? 482813.55 : 291704.59,
        3 => 0.0,
        _ => (total - i) * 1000.0,
      },
      'currency': 'AZN',
      'organization': 'NaTural-İD',
      'is_paid': false,
      'baza_id': 18,
      'synced_at': '2026-10-19T23:19:34',
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;
    if (!path.endsWith('/onec-data/${kind.endpoint}/')) {
      // `Əsas panel`'s figures, which the tab loads whatever page it is on.
      return _json(<String, Object?>{'data': <Object?>[], 'total': 1});
    }

    final String? search = query['search'];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    if (search == null && size == 20) pages.add(page);

    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (int i = 0; i < total; i++)
        if (search == null ||
            '${row(i)['contractor']} ${row(i)['contract']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
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
