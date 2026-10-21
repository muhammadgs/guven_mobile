import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/manager_debt.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'debt_card.dart';
import 'team_card.dart';

/// One manager's debt collection: the manager's name, and under it
/// `Sifariş`, `Satış`, `Debet`, `Yığılmış` and `Statistika`, a line each.
///
/// The design (2026-10-21) is `Kreditorlar`' card in rhythm — measured off
/// its frame at 2px a point, the name CalSans at 22 on 29pt lines, its first
/// baseline 39pt down, then every row 29pt under the one before — with one
/// field on each line and the last 29.75pt above the bottom edge: a
/// one-line name makes a 213.75pt card. So the gaps are [DebtCard]'s, and
/// only the bottom is this card's own.
///
/// What is owed is red; what has come in, green. `Statistika` is the
/// user's name for the share of the sales that has come in (2026-10-21),
/// the website's `TOPLAMA %`, shown as it is — `96.72%` — rather than
/// rounded, so a manager still owed money never reads 100%
/// ([ManagerDebt.collectedHundredths]); it is coloured by the website's
/// grades ([shareTone]). The field names are Poppins SemiBold
/// ([databaseCardLabelStyle]). The card does not open, so a tap does
/// nothing.
class ManagerDebtCard extends StatelessWidget {
  const ManagerDebtCard({super.key, required this.row});

  final ManagerDebt row;

  /// The colour of a share given in hundredths of a percent: the website's
  /// grades, the user's word (2026-10-22) — 70% and up green, 40% and up
  /// amber, below that red. Graded on the share the card prints, so 69.99%
  /// is amber.
  static Color shareTone(int hundredths) {
    if (hundredths >= 7000) return kSaleDone;
    if (hundredths >= 4000) return kShareMiddling;
    return kSalePending;
  }

  /// Under the last line's: its baseline 29.75pt above the bottom edge,
  /// less the 3.5pt of a 14pt Poppins line Flutter lays under its baseline.
  static const double kPadBottom = 29.75 - (17 - 13.5);

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final ManagerDebt row = this.row;
    final int? orders = row.orders;
    final double? sales = row.sales;
    final double? debt = row.debt;
    final double? collected = row.collected;
    final int? share = row.collectedHundredths;

    final List<Widget> lines = <Widget>[
      _Pair(
        label: 'Sifariş:',
        value: orders == null ? kUnknownValue : formatCount(orders),
        scale: s,
      ),
      _Pair(
        label: 'Satış:',
        value: sales == null ? kUnknownValue : formatMoney(sales),
        scale: s,
      ),
      _Pair(
        label: 'Debet:',
        value: debt == null ? kUnknownValue : formatMoney(debt),
        color: debt == null ? null : kSalePending,
        scale: s,
      ),
      _Pair(
        label: 'Yığılmış:',
        value: collected == null ? kUnknownValue : formatMoney(collected),
        color: collected == null ? null : kSaleDone,
        scale: s,
      ),
      _Pair(
        label: 'Statistika:',
        value: share == null ? kUnknownValue : formatPercentHundredths(share),
        color: share == null ? null : shareTone(share),
        scale: s,
      ),
    ];

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          TeamCard.kPadH * s,
          DebtCard.kPadTop * s,
          TeamCard.kPadH * s,
          kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Every line it needs, and never one word on the last.
            DatabaseCardName(
              text: _given(row.manager) ?? kUnknownValue,
              style: TeamCard.nameStyle(s),
            ),
            SizedBox(height: DebtCard.kNameGap * s),
            for (int i = 0; i < lines.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: DebtCard.kRowGap * s),
              lines[i],
            ],
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

/// `Debet: 14,612.94 ₼` — a field name and its value on one line, a space
/// apart as the design sets them.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.value,
    required this.scale,
    this.color,
  });

  final String label;
  final String value;
  final double scale;

  /// The value's own colour, or null for ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = databaseCardStyle(14 * scale);
    final Color? color = this.color;
    return Align(
      alignment: Alignment.centerLeft,
      // An amount too wide for the card is set smaller, never cut.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label ',
            style: databaseCardLabelStyle(14 * scale),
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: color == null ? body : body.copyWith(color: color),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: body,
        ),
      ),
    );
  }
}
