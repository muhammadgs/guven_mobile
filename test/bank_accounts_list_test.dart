import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
import 'package:guven_mobile/src/features/database/domain/bank_account.dart';
import 'package:guven_mobile/src/features/database/domain/bank_accounts_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_filter_metrics.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/bank_account_card.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/bank_accounts_list.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_glass.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/team_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// `Bank Hesabları` as the user meets it: the design's two cards — shut,
/// five bare lines; open, labelled, `Valyuta` included, with the account's
/// own figures under them — every gap one gap; the funnel's seven columns;
/// on every phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Where a card's lines land depends on what its words *measure*, so the
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
    testWidgets('shut, an account is the design\'s first card: code, name, '
        'bank, number, currency — bare, every gap one gap', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);

      expect(find.text('Bank Hesabları'), findsOneWidget);

      final Finder second = find.byType(BankAccountCard).at(1);
      final Rect card = tester.getRect(second);

      // 19.5pt either side of a 363pt card, on the 402pt frame, as drawn; a
      // one-line name makes 171.1pt.
      expect(card.left, moreOrLessEquals(19.5, epsilon: 0.01));
      expect(card.width, moreOrLessEquals(363, epsilon: 0.01));
      expect(card.height, moreOrLessEquals(_shut, epsilon: 0.25));
      // 9pt to the next, as on `Kassalar`.
      expect(
        tester.getRect(find.byType(BankAccountCard).at(2)).top - card.bottom,
        moreOrLessEquals(9, epsilon: 0.01),
      );

      final _Card on = _Card(tester, second);
      // The code where `Kassalar`' is; then every line so that the gap the
      // eye sees — a baseline to the capitals under it — is one gap.
      on.baseline('NT0000001', 27.5);
      on.baseline('CARI-Pasha bank AZ60 (əsas)', 62.13);
      on.baseline('Pasha bank', 91.13);
      on.baseline('AZ60PAHA40060AZNHC0100191890', 120.13);
      on.baseline('AZN', 149.13);

      final List<double> gaps = <double>[
        on.seen('NT0000001', 'CARI-Pasha bank AZ60 (əsas)', _calSans),
        on.seen('CARI-Pasha bank AZ60 (əsas)', 'Pasha bank', _poppins),
        on.seen('Pasha bank', 'AZ60PAHA40060AZNHC0100191890', _poppins),
        on.seen('AZ60PAHA40060AZNHC0100191890', 'AZN', _poppins),
      ];
      for (final double gap in gaps) {
        expect(gap, moreOrLessEquals(19.23, epsilon: 0.25));
      }

      // Bare: no label shows, and the values stand at the content's edge.
      for (final String label in <String>[
        'Hesab adı:',
        'Hesab nömrəsi:',
        'Ödəniş sayı',
        'Balans',
      ]) {
        expect(on.text(label), findsNothing, reason: label);
      }
      for (final String text in <String>[
        'NT0000001',
        'CARI-Pasha bank AZ60 (əsas)',
        'Pasha bank',
        'AZ60PAHA40060AZNHC0100191890',
        'AZN',
      ]) {
        expect(on.left(text), moreOrLessEquals(23, epsilon: 0.01));
      }
      // The name in `Kassalar`' face and size; the code in the tab's
      // figures; the number in Poppins, as drawn.
      TextStyle styleOf(String text) => tester
          .widget<Text>(find.descendant(of: second, matching: find.text(text)))
          .style!;
      final TextStyle name = styleOf('CARI-Pasha bank AZ60 (əsas)');
      expect(name.fontFamily, 'CalSans');
      expect(name.fontSize, moreOrLessEquals(TeamCard.kName));
      expect(styleOf('NT0000001').fontFamily, kDatabaseFigureFont);
      expect(styleOf('AZ60PAHA40060AZNHC0100191890').fontFamily, 'Poppins');

      // Nothing is asked for a shut card.
      expect(bridge.details, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('open, it is the design\'s second card — with `Valyuta:` — '
        'and the figures are asked for on every opening', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder second = find.byType(BankAccountCard).at(1);

      await tester.tap(second);
      await tester.pumpAndSettle();
      final Rect card = tester.getRect(second);
      expect(bridge.details, <int>[46]);

      final _Card on = _Card(tester, second);
      on.baseline('NT0000001', 27.5);
      on.baseline('Hesab adı:', 56.5);
      on.baseline('CARI-Pasha bank AZ60 (əsas)', 81.31);
      on.baseline('Bank: ', 110.31);
      on.baseline('Pasha bank', 110.31);
      on.baseline('Hesab nömrəsi:', 139.31);
      on.baseline('AZ60PAHA40060AZNHC0100191890', 158.5);
      on.baseline('Valyuta: ', 187.5);
      on.baseline('AZN', 187.5);
      on.baseline('Ödəniş sayı: 0', 216.5);
      on.baseline('Daxil olan: 0.00 ₼', 245.5);
      on.baseline('Çıxan: 0.00 ₼', 274.5);
      on.baseline('Balans: 0.00 ₼', 303.5);
      on.baseline('Növ: Əlavə', 332.5);
      on.baseline('Status:  aktiv', 361.5);
      // And 22pt under the last, as shut.
      expect(card.height, moreOrLessEquals(_open, epsilon: 0.25));

      // Every line one gap from the line above it…
      for (final (String above, String below) in <(String, String)>[
        ('NT0000001', 'Hesab adı:'),
        ('CARI-Pasha bank AZ60 (əsas)', 'Pasha bank'),
        ('Pasha bank', 'Hesab nömrəsi:'),
        ('AZ60PAHA40060AZNHC0100191890', 'AZN'),
        ('AZN', 'Ödəniş sayı: 0'),
        ('Ödəniş sayı: 0', 'Daxil olan: 0.00 ₼'),
        ('Daxil olan: 0.00 ₼', 'Çıxan: 0.00 ₼'),
        ('Çıxan: 0.00 ₼', 'Balans: 0.00 ₼'),
        ('Balans: 0.00 ₼', 'Növ: Əlavə'),
        ('Növ: Əlavə', 'Status:  aktiv'),
      ]) {
        expect(
          on.seen(above, below, _poppins),
          moreOrLessEquals(19.23, epsilon: 0.25),
          reason: '$above → $below',
        );
      }
      // …but a label stands closer over its value: one gap, both times.
      final double overName = on.seen(
        'Hesab adı:',
        'CARI-Pasha bank AZ60 (əsas)',
        _calSans,
      );
      final double overNumber = on.seen(
        'Hesab nömrəsi:',
        'AZ60PAHA40060AZNHC0100191890',
        _poppins,
      );
      expect(overName, moreOrLessEquals(9.41, epsilon: 0.25));
      expect(overNumber, moreOrLessEquals(overName, epsilon: 0.25));

      // Every line at the content's edge, the bank and the currency a
      // space after their labels.
      for (final String text in <String>[
        'NT0000001',
        'Hesab adı:',
        'CARI-Pasha bank AZ60 (əsas)',
        'Bank: ',
        'Hesab nömrəsi:',
        'AZ60PAHA40060AZNHC0100191890',
        'Valyuta: ',
        'Ödəniş sayı: 0',
        'Status:  aktiv',
      ]) {
        expect(
          on.left(text),
          moreOrLessEquals(23, epsilon: 0.01),
          reason: text,
        );
      }
      expect(
        tester.getRect(on.text('Pasha bank')).left,
        moreOrLessEquals(tester.getRect(on.text('Bank: ')).right),
      );
      expect(
        tester.getRect(on.text('AZN')).left,
        moreOrLessEquals(tester.getRect(on.text('Valyuta: ')).right),
      );
      expect(_colourOf(tester, on.text('Status:  aktiv'), 'aktiv'), kSaleDone);

      // Shut again, it is the first card again; opened again, it asks
      // again: money moves.
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(second).height,
        moreOrLessEquals(_shut, epsilon: 0.25),
      );
      expect(on.text('Hesab adı:'), findsNothing);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(bridge.details, <int>[46, 46]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the card opens, a label over a line is never drawn '
        'over that line', (WidgetTester tester) async {
      await _pump(tester, _Bridge());
      final Finder second = find.byType(BankAccountCard).at(1);
      final _Card on = _Card(tester, second);

      await tester.tap(second);
      for (int ms = 0; ms < 420; ms += 30) {
        await tester.pump(const Duration(milliseconds: 30));
        for (final (String label, String under, double capital)
            in <(String, String, double)>[
              ('Hesab adı:', 'CARI-Pasha bank AZ60 (əsas)', _calSans),
              ('Hesab nömrəsi:', 'AZ60PAHA40060AZNHC0100191890', _poppins),
            ]) {
          // What of the label is shown: its letters — none of them reach
          // under the baseline — cut at the room's foot while the card is
          // on its way…
          if (ms == 0 && on.text(label).evaluate().isEmpty) continue;
          final double letters = _baseline(tester, on.text(label));
          final RenderClipRect clip = tester.renderObject<RenderClipRect>(
            find
                .ancestor(of: on.text(label), matching: find.byType(ClipRect))
                .first,
          );
          final Rect room = MatrixUtils.transformRect(
            clip.getTransformTo(null),
            Offset.zero & clip.size,
          );
          final double shown = clip.clipBehavior == Clip.none
              ? letters
              : math.min(room.bottom, letters);
          // …and the line under it starts at its capitals.
          expect(
            shown,
            lessThanOrEqualTo(_baseline(tester, on.text(under)) - capital),
            reason: '$label at ${ms}ms',
          );
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the figures say `…` while they are on their way, and `—` '
        'with a way to ask again when they cannot be read', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge()..holdDetails = true;
      await _pump(tester, bridge);
      final Finder first = find.byType(BankAccountCard).first;
      final _Card on = _Card(tester, first);

      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(on.text('Ödəniş sayı: …'), findsOneWidget);
      expect(on.text('Balans: …'), findsOneWidget);
      // What the row says is there already.
      expect(on.text('Növ: Əlavə'), findsOneWidget);
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(_open, epsilon: 0.25),
      );

      bridge
        ..failDetail = true
        ..release();
      await tester.pumpAndSettle();
      expect(on.text('Balans: —'), findsOneWidget);
      expect(on.text('Server xətası'), findsOneWidget);

      bridge
        ..holdDetails = false
        ..failDetail = false;
      await tester.tap(on.text('Yenidən cəhd et'));
      await tester.pumpAndSettle();
      expect(on.text('Server xətası'), findsNothing);
      // The retry did not shut the card.
      expect(on.text('Balans: 0.00 ₼'), findsOneWidget);
      expect(
        tester.getSize(first).height,
        moreOrLessEquals(_open, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('another currency is written by its code; the main account '
        'says `Əsas`, and one switched off says so in red', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      final Finder dollars = find.ancestor(
        of: find.text('Dollar hesabı'),
        matching: find.byType(BankAccountCard),
      );
      await tester.dragUntilVisible(
        find.text('Dollar hesabı'),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final _Card on = _Card(tester, dollars);
      expect(on.text('USD'), findsOneWidget);

      await tester.ensureVisible(dollars);
      await tester.tap(dollars);
      await tester.pumpAndSettle();
      expect(on.text('Ödəniş sayı: 1,250'), findsOneWidget);
      expect(on.text('Daxil olan: 1,234,567.89 USD'), findsOneWidget);
      expect(on.text('Çıxan: 34,567.80 USD'), findsOneWidget);
      expect(on.text('Balans: 1,200,000.09 USD'), findsOneWidget);
      expect(on.text('Növ: Əsas'), findsOneWidget);
      expect(
        _colourOf(tester, on.text('Status:  deaktiv'), 'deaktiv'),
        kSalePending,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name takes a second line, shut and open', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      final Finder long = find.ancestor(
        of: find.text(_Bridge.longName),
        matching: find.byType(BankAccountCard),
      );
      await tester.dragUntilVisible(
        find.text(_Bridge.longName),
        _list(),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(long).height,
        moreOrLessEquals(_shut + 29, epsilon: 0.25),
      );
      await tester.ensureVisible(long);
      await tester.tap(long);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(long).height,
        moreOrLessEquals(_open + 29, epsilon: 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the next page is asked for well before the end is reached', (
      WidgetTester tester,
    ) async {
      final _Bridge bridge = _Bridge();
      await _pump(tester, bridge);
      expect(bridge.pages, <int>[1]);

      // Two screens short of page one's end is where page two goes out.
      for (int i = 0; i < 3; i++) {
        await tester.drag(_list(), const Offset(0, -800));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(bridge.pages, <int>[1, 2]);
      expect(tester.takeException(), isNull);
    });
  });

  group('the filter', () {
    testWidgets('the funnel opens the seven fields a row carries', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _Bridge());
      await _openFilter(tester);

      expect(find.text('Filter'), findsOneWidget);
      for (final BankAccountsColumn column in BankAccountsColumn.values) {
        expect(_inPanel(column.label), findsOneWidget, reason: column.label);
      }
      // The figures only an account's own answer has are not columns.
      expect(_inPanel('Balans'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bank reads the catalogue once and lists every bank, the '
        'most common first', (WidgetTester tester) async {
      final _Bridge bridge = _Bridge();
      final DatabaseController database = await _pump(tester, bridge);
      await _openFilter(tester);

      await tester.tap(_inPanel('Bank'));
      await tester.pumpAndSettle();
      expect(database.bankAccounts.hasEveryone, isTrue);
      expect(bridge.sizes, <int>[20, 20]);
      expect(
        tester.getTopLeft(_inPanel('Pasha bank')).dy,
        lessThan(tester.getTopLeft(_inPanel('Kapital Bank')).dy),
      );

      await tester.tap(_inPanel('Kapital Bank'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 700));
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseFilterPanel), findsNothing);
      expect(<String?>[
        for (final BankAccount account in database.bankAccounts.filtered!.rows)
          account.bankName,
      ], everyElement('Kapital Bank'));
      expect(database.bankAccounts.filtered!.rows, hasLength(_Bridge.kapital));
      // Nothing more was read for it.
      expect(bridge.sizes, <int>[20, 20]);
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
      testWidgets(
        '${device.name} @ ${fontScale}x — cards fit shut and open, and so do '
        'the seven columns',
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

          final int built = find.byType(BankAccountCard).evaluate().length;
          for (int i = 0; i < built && i < 4; i++) {
            fits(find.byType(BankAccountCard).at(i));
          }
          final Finder second = find.byType(BankAccountCard).at(1);
          await tester.tap(second);
          await tester.pumpAndSettle();
          fits(second);
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
          for (final BankAccountsColumn column in BankAccountsColumn.values) {
            inside(glass, tester.getRect(_inPanel(column.label)), column.label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// A shut card with a one-line name, on the 402pt frame: the code's
/// baseline 27.5pt down, four equal gaps to the currency's, and 22pt under
/// it.
const double _shut = 149.13 + 22;

/// The same card open: twelve lines, `Status`' baseline 361.5pt down.
const double _open = 361.5 + 22;

/// A capital's height: Poppins' at 14, CalSans' at 22.
const double _poppins = 14 * 0.698;
const double _calSans = 22 * 0.7;

/// The lines of one card, found and measured.
class _Card {
  _Card(this.tester, this.card);

  final WidgetTester tester;
  final Finder card;

  Finder text(String text) =>
      find.descendant(of: card, matching: find.text(text, findRichText: true));

  double top() => tester.getRect(card).top;

  double left(String text) =>
      tester.getRect(this.text(text)).left - tester.getRect(card).left;

  /// Where [text]'s first baseline is under the card's top edge.
  double baselineOf(String text) => _baseline(tester, this.text(text)) - top();

  void baseline(String text, double design) {
    expect(this.text(text), findsOneWidget, reason: text);
    expect(
      baselineOf(text),
      moreOrLessEquals(design, epsilon: 0.25),
      reason: text,
    );
  }

  /// The gap the eye sees from [above]'s baseline to the capitals of
  /// [below], [capital] tall.
  double seen(String above, String below, double capital) =>
      baselineOf(below) - capital - baselineOf(above);
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
  of: find.byType(BankAccountsList),
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
  )..select(DatabaseSection.bankAccounts);
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

/// The 1C bridge's bank accounts, forty deep, by name as it gives them. The
/// first ten are the live catalogue's, as read on 2026-10-08; then one with
/// a name too long for one line, one in dollars — the main account, and
/// switched off — and the rest plain, held at Kapital Bank one in three.
class _Bridge {
  bool failDetail = false;

  /// Accounts' own answers are held back until [release].
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

  /// The id of every account asked for on its own.
  final List<int> details = <int>[];

  static const int total = 40;

  static const String longName =
      'Kapital Bank Biznes Hesabı — Nizami filialı (əsas)';

  /// How many accounts are held at Kapital Bank.
  static int get kapital => <int>[
    for (int i = 0; i < total; i++)
      if (_bank(i) == 'Kapital Bank') i,
  ].length;

  static const List<(int, String, String, String, String)> _live =
      <(int, String, String, String, String)>[
        (42, 'NT0000003', 'Access Bank', 'Access Bank', '12345'),
        (
          46,
          'NT0000001',
          'CARI-Pasha bank AZ60 (əsas)',
          'Pasha bank',
          'AZ60PAHA40060AZNHC0100191890',
        ),
        (
          49,
          'NT0000009',
          'POST PASHA',
          'Pasha bank',
          '1234567891234567891234567890',
        ),
        (
          50,
          'NT0000010',
          'Pasha Biznes Hesabı 2( PASSİV)',
          'Pasha Bank Biznes Hesabı 2',
          'AZ60PAHA40060AZNHC0100191890',
        ),
        (
          47,
          'NT0000006',
          'Pasha_Biznes  AZ40',
          'Pasha Bank Biznes Hesabı 2',
          'AZ60PAHA40060AZNHC0100191890',
        ),
        (43, 'NT0000004', 'Respublika Bank (NMG)', 'Respublika Bank', '123456'),
        (48, 'NT0000008', 'USD ', 'Pasha bank', '1234567891234567891234567896'),
        (44, 'NT0000005', 'YapıKredi  Bank ', 'YapıKredi  Bank ', '1234567'),
        (41, 'NT0000002', 'Yellow bank ', 'Yellow bank ', '1234'),
        (45, 'NT0000007', 'ƏDV Depozit', 'ƏDV Depozit', '123456789'),
      ];

  static String _bank(int i) {
    if (i < _live.length) return _live[i].$4;
    if (i == 10) return 'Kapital Bank';
    if (i == 11) return 'Pasha bank';
    return i % 3 == 0 ? 'Kapital Bank' : 'Pasha bank';
  }

  static Map<String, Object?> row(int i) {
    final (int, String, String, String, String)? live = i < _live.length
        ? _live[i]
        : null;
    return <String, Object?>{
      'id': live?.$1 ?? 100 + i,
      'onec_guid': 'guid-$i',
      'code': live?.$2 ?? 'NT00001${i.toString().padLeft(2, '0')}',
      'name':
          live?.$3 ??
          switch (i) {
            10 => longName,
            11 => 'Dollar hesabı',
            _ => 'Hesab $i',
          },
      'bank_name': _bank(i),
      'account_number': live?.$5 ?? 'AZ${i}NABZ0000000000000000${i}00',
      'currency': i == 11 ? 'USD' : 'AZN',
      'is_default': i == 11,
      'is_active': i != 11,
      'created_at': '2026-09-18T13:58:33.686361',
      'updated_at': '2026-09-18T13:58:33.686361',
      'baza_id': 18,
    };
  }

  Future<http.Response> answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    final RegExpMatch? one = RegExp(r'/bank-accounts/(\d+)$').firstMatch(path);
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
      final int i = <int>[
        for (int k = 0; k < total; k++)
          if (row(k)['id'] == id) k,
      ].single;
      final bool dollars = i == 11;
      return _json(<String, Object?>{
        ...row(i),
        'payments_count': dollars ? 1250 : 0,
        'total_in': dollars ? 1234567.891 : 0.0,
        'total_out': dollars ? 34567.8 : 0.0,
        'balance': dollars ? 1200000.091 : 0.0,
        'payments': <Object?>[],
      });
    }
    if (!path.endsWith('/bank-accounts/')) {
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
            '${row(i)['code']} ${row(i)['name']} ${row(i)['account_number']}'
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
