import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/debt.dart';
import '../database_format.dart';
import 'bank_account_card.dart';
import 'cash_desk_card.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'team_card.dart';

/// One debt — a creditor's or a debtor's: the counterparty, and under it
/// `Təşkilat:` over the organisation, `Müqavilə:` over the contract, then
/// the amount (`Borcumuz:` on `Kreditorlar`, `Borc:` on `Debitorlar`),
/// `Hesablaşma:` and `Status:`.
///
/// The two designs (2026-10-20) are one card. The amounts are red on
/// `Kreditorlar` — money going out — and green on `Debitorlar` — money
/// coming in; the status is red while the debt is open. The field names are
/// Poppins SemiBold, the user's change to the tab ([databaseCardLabelStyle]).
/// The card does not open — the user's word: this is the whole card — so a
/// tap does nothing.
///
/// Measured off the frames at 2px a point: the counterparty CalSans at 22 on
/// 29pt lines, its first baseline 39pt down, taking every line it needs;
/// Poppins at 14 for the rest; a value written under its label wraps on
/// 21pt lines, as the long contract does in the design; the last line 25pt
/// above the bottom edge. The two frames' gaps wander — 24.75 against 33pt
/// from the name to `Təşkilat:`, 40 against 25pt under the status — and the
/// user's word on `Bank Hesabları` was that such gaps are meant to be one:
/// so every line stands [CashDeskCard.kSeenGap] from the one above it,
/// measured as it is seen — a baseline to the capitals under it — and a
/// label over its value [BankAccountCard.kLabelSeenGap], as on those cards.
/// With a one-line name, organisation and contract the card is 247.4pt.
class DebtCard extends StatelessWidget {
  const DebtCard({super.key, required this.debt, required this.kind});

  final Debt debt;
  final DebtKind kind;

  /// Above the name's line: its first baseline 39pt down.
  static const double kPadTop = 39 - _nameAscent;

  /// Under the last line's: its baseline 25pt above the bottom edge.
  static const double kPadBottom = 25 - _rowDescent;

  /// From one line's baseline to the next row's: a seen gap and a 14pt
  /// Poppins capital (0.698 of its size) — 29pt.
  static const double kRowPitch = CashDeskCard.kSeenGap + 14 * 0.698;

  /// From a label's baseline to its value's: 19.2pt.
  static const double kLabelPitch = BankAccountCard.kLabelSeenGap + 14 * 0.698;

  /// A value's lines under its label: the design's 21pt.
  static const double kValueLine = 21;

  // Where Flutter puts a baseline in each kind of line, measured: Poppins
  // 14 on a 1.2 line is laid out 17pt tall with its baseline 13.5pt down; on
  // a 21pt line, 15.4pt down; CalSans 22 on 29pt lines, 22.2pt down.
  static const double _nameAscent = 22.2;
  static const double _nameDescent = 29 - _nameAscent;
  static const double _rowAscent = 13.5;
  static const double _rowDescent = 17 - _rowAscent;
  static const double _valueAscent = 15.4;
  static const double _valueDescent = kValueLine - _valueAscent;

  /// From the name's last line to the first label's.
  static const double kNameGap = kRowPitch - _nameDescent - _rowAscent;

  /// From a label's line to its value's.
  static const double kLabelGap = kLabelPitch - _rowDescent - _valueAscent;

  /// From a value's last line to the next label or row.
  static const double kValueGap = kRowPitch - _valueDescent - _rowAscent;

  /// From one row's line to the next.
  static const double kRowGap = kRowPitch - _rowDescent - _rowAscent;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final Debt debt = this.debt;
    final Color tone = switch (kind) {
      DebtKind.creditors => kSalePending,
      DebtKind.debitors => kSaleDone,
    };
    final bool paid = debt.paid;

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          TeamCard.kPadH * s,
          kPadTop * s,
          TeamCard.kPadH * s,
          kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Every line it needs, and never one word on the last.
            DatabaseCardName(
              text: _given(debt.contractor) ?? kUnknownValue,
              style: TeamCard.nameStyle(s),
            ),
            SizedBox(height: kNameGap * s),
            _Label('Təşkilat:', scale: s),
            SizedBox(height: kLabelGap * s),
            _Value(_given(debt.organization) ?? kUnknownValue, scale: s),
            SizedBox(height: kValueGap * s),
            _Label('Müqavilə:', scale: s),
            SizedBox(height: kLabelGap * s),
            _Value(_given(debt.contract) ?? kUnknownValue, scale: s),
            SizedBox(height: kValueGap * s),
            _Pair(
              label: '${kind.debtLabel}:',
              value: _money(debt.debt),
              color: debt.debt == null ? null : tone,
              scale: s,
            ),
            SizedBox(height: kRowGap * s),
            _Pair(
              label: 'Hesablaşma:',
              value: _money(debt.settlement),
              color: debt.settlement == null ? null : tone,
              scale: s,
            ),
            SizedBox(height: kRowGap * s),
            _Pair(
              // The tab's other cards set the status two spaces from its
              // label, and so does this design.
              label: 'Status: ',
              value: paid ? 'Ödənilib' : 'Açıq borc',
              color: paid ? kSaleDone : kSalePending,
              scale: s,
            ),
          ],
        ),
      ),
    );
  }

  /// The design's `240,714.51 ₼` for manat; any other currency by its code.
  String _money(double? value) {
    if (value == null) return kUnknownValue;
    final String? currency = debt.currency;
    if (currency == null || currency == 'AZN') return formatMoney(value);
    return '${formatDecimal(value)} $currency';
  }

  /// [text] with 1C's doubled and trailing spaces made one, or null when
  /// that leaves nothing.
  static String? _given(String? text) {
    if (text == null) return null;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? null : tidy;
  }
}

/// `Təşkilat:` — a field name on a line of its own, its value under it.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: databaseCardLabelStyle(14 * scale),
    );
  }
}

/// The value under a [_Label]: every line it needs, 21pt apart — a contract
/// 1C names by its date and number runs to two.
class _Value extends StatelessWidget {
  const _Value(this.text, {required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: databaseCardStyle(14 * scale, height: DebtCard.kValueLine / 14),
    );
  }
}

/// `Borc: 101,371.59 ₼` — a field name and its value on one line, a space
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
