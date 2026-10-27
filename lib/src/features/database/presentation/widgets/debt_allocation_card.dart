import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/debt_allocation.dart';
import '../database_format.dart';
import 'bank_account_card.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'debt_card.dart';
import 'team_card.dart';

/// One sale's share of what a manager has collected: `Menecer:` over the
/// manager's name, then `Tarix:` and `Bölgü:` with their values after them
/// — the website's columns without its sale guid, laid out as the user
/// asked (2026-10-22): the manager's label a line above the name, the name
/// in CalSans, every other value ahead of its label.
///
/// There is no design of its own, so it is built from the tab's measures:
/// the field names Poppins SemiBold at 14 ([databaseCardLabelStyle]), the
/// name CalSans at 22 on 29pt lines ([TeamCard.nameStyle]) standing
/// [BankAccountCard.kLabelSeenGap] under its label as `Hesab adı:`'s does,
/// then a row every 29pt ([DebtCard.kRowPitch]); the edges are the other
/// `Maliyyə` cards' — the first capitals 23.6pt down, where theirs start,
/// and the last baseline 25pt above the bottom ([DebtCard.kPadBottom]). A
/// one-line name makes a 141.2pt card: baselines 33.4, 58.2, 87.2 and
/// 116.2pt down.
///
/// The share is green: it is money that has come in — a manager's shares
/// add up to their `Yığılmış` on `Menecer Borcları`, which is green there.
/// The card does not open, so a tap does nothing.
class DebtAllocationCard extends StatelessWidget {
  const DebtAllocationCard({super.key, required this.row});

  final DebtAllocation row;

  // Where Flutter puts a baseline, measured: Poppins 14 on a 1.2 line is
  // laid out 17pt tall with its baseline 13.5pt down; CalSans 22 on 29pt
  // lines, 22.2pt down. Capitals stand 0.698 of Poppins' size and 0.7 of
  // CalSans'.
  static const double _labelAscent = 13.5;
  static const double _nameAscent = 22.2;

  /// From the card's top to `Menecer:`'s baseline: its capitals start where
  /// the names' do on `Kreditorlar`, `Debitorlar` and `Menecer Borcları` —
  /// 39pt down to a 22pt CalSans baseline, less the capital — 33.4pt.
  static const double kLabelBaseline = 39 - 22 * 0.7 + 14 * 0.698;

  /// Above `Menecer:`'s line.
  static const double kPadTop = kLabelBaseline - _labelAscent;

  /// From `Menecer:`'s line to the name's: the name's capitals
  /// [BankAccountCard.kLabelSeenGap] under the label's baseline. The label's
  /// line runs on 0.9pt into the air over the name's capitals.
  static const double kLabelBlock =
      _labelAscent + BankAccountCard.kLabelSeenGap + 22 * 0.7 - _nameAscent;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final DebtAllocation row = this.row;
    final double? allocated = row.allocated;
    final String? date = row.date;

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          TeamCard.kPadH * s,
          kPadTop * s,
          TeamCard.kPadH * s,
          DebtCard.kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: kLabelBlock * s,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Menecer:',
                      maxLines: 1,
                      softWrap: false,
                      style: databaseCardLabelStyle(14 * s),
                    ),
                  ),
                ],
              ),
            ),
            // Every line it needs, and never one word on the last.
            DatabaseCardName(
              text: _given(row.manager) ?? kUnknownValue,
              style: TeamCard.nameStyle(s),
            ),
            SizedBox(height: DebtCard.kNameGap * s),
            _Pair(
              label: 'Tarix:',
              value: date == null || date.isEmpty ? kUnknownValue : date,
              scale: s,
            ),
            SizedBox(height: DebtCard.kRowGap * s),
            _Pair(
              label: 'Bölgü:',
              value: allocated == null ? kUnknownValue : formatMoney(allocated),
              color: allocated == null ? null : kSaleDone,
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

/// `Bölgü: 36,398.15 ₼` — a field name and its value on one line, a space
/// apart as the tab's designs set them.
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
