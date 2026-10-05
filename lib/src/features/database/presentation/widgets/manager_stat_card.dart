import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/manager_stat.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One manager's month: the manager's name, and under it `Dövr`, `Sifariş`
/// and `Cəmi məbləğ`.
///
/// The card does not open — the user's word, there being too little on it
/// to open onto — so a tap does nothing.
///
/// The numbers are the design's, measured off its frame at 3.35px a point:
/// the name CalSans at 22 on 29pt lines, its first baseline 42pt down,
/// taking every line it needs; `Dövr` 30pt under the name's last baseline,
/// in Poppins at 14 with the month in the tab's figures at 15; the other
/// two rows Poppins at 14, 31pt apart (the design's 31.1 and 31.0); the
/// last 29pt above the bottom edge. A one-line name makes a 163pt card —
/// baselines 42, 72, 103.2 and 134.2pt down.
class ManagerStatCard extends StatelessWidget {
  const ManagerStatCard({super.key, required this.stat});

  final ManagerStat stat;

  /// 23pt either side — every `Baza` card's.
  ///
  /// The gaps below are between the lines' boxes, set against the lines
  /// the text engine actually lays out: it rounds each to a whole point
  /// (see [databaseCardStyle]).
  static const double kPadH = 23;
  static const double kPadTop = 19.8;

  /// Under the last row's line.
  static const double kPadBottom = 25.13;

  /// The name's size and its line: 29pt, as on `Komanda`'s cards.
  static const double kName = 22;
  static const double kNameHeight = 29 / kName;

  /// The month, in the tab's figures — a point larger than the words
  /// before it, as the design sets it.
  static const double kPeriod = 15;

  /// From the name's last line to `Dövr`'s.
  static const double kNameGap = 9.07;

  /// Between one row's line and the next: rows 31pt apart. `Dövr`'s line
  /// is a point taller than the others, for its 15pt month, and its
  /// baseline sits that much lower in it, so the same gap serves after it.
  static const double kRowGap = 14;

  /// The name's face on the design's frame.
  static TextStyle nameStyle(double scale) => TextStyle(
    fontFamily: 'CalSans',
    fontSize: kName * scale,
    height: kNameHeight,
    letterSpacing: 0,
    color: kGlassInk,
  );

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final ManagerStat stat = this.stat;
    final int? orders = stat.orders;
    final double? amount = stat.amount;

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          kPadH * s,
          kPadTop * s,
          kPadH * s,
          kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_given(stat.manager) ?? kUnknownValue, style: nameStyle(s)),
            SizedBox(height: kNameGap * s),
            _Pair(
              // The design sets the month two spaces from its label.
              label: 'Dövr: ',
              value: stat.periodLabel ?? kUnknownValue,
              valueStyle: TextStyle(
                fontFamily: kDatabaseFigureFont,
                fontSize: kPeriod * s,
                height: 1.2,
                letterSpacing: 0,
                color: kGlassInk,
              ),
              scale: s,
            ),
            SizedBox(height: kRowGap * s),
            _Pair(
              label: 'Sifariş:',
              value: orders == null
                  ? kUnknownValue
                  : '${formatCount(orders)} sifariş',
              scale: s,
            ),
            SizedBox(height: kRowGap * s),
            _Pair(
              label: 'Cəmi məbləğ:',
              value: amount == null ? kUnknownValue : formatMoney(amount),
              scale: s,
            ),
          ],
        ),
      ),
    );
  }

  /// [text] with 1C's doubled and trailing spaces made one, or null when
  /// that leaves nothing.
  static String? _given(String? text) {
    if (text == null) return null;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? null : tidy;
  }
}

/// `Sifariş: 236 sifariş` — a heading and its value on one line, a space
/// apart as the design sets them.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.value,
    required this.scale,
    this.valueStyle,
  });

  final String label;
  final String value;
  final double scale;

  /// The value's own face — the month's figures — or null for the label's.
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      // An amount too long for the card is set smaller, never cut.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label ',
            children: <InlineSpan>[TextSpan(text: value, style: valueStyle)],
          ),
          maxLines: 1,
          softWrap: false,
          style: databaseCardStyle(14 * scale),
        ),
      ),
    );
  }
}
