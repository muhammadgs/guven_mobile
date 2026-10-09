import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/warehouse.dart';
import 'cash_desk_card.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'team_card.dart';

/// One warehouse: the code, the name, and under them `Növü` and `Status` —
/// the website's four columns.
///
/// There is no design of its own: the user's word (2026-10-09) is that it is
/// drawn like the tab's other cards, and the one with the same four fields is
/// `Kassalar`' ([CashDeskCard]) — so it is that card line for line, with
/// `Növü` where `Valyuta` is: the code ChakraPetch at 14, its baseline 27.5pt
/// down; the name CalSans at 22 on 29pt lines; Poppins at 14 for the rows;
/// every gap the eye sees between two lines the same [CashDeskCard.kSeenGap];
/// the last row 22pt above the bottom edge. A one-line name makes the same
/// 142.1pt card.
///
/// A warehouse 1C gives no code — all seven on 2026-10-09 — has no line for
/// it (the user's word). Its name moves up to where the code was, its
/// capitals standing as far from the card's top as the code's do, so the
/// edge looks the same either way: baselines 33.1, 62.1 and 91.1pt down, a
/// 113.1pt card. The card does not open — `Kassalar`' rule — so a tap does
/// nothing.
class WarehouseCard extends StatelessWidget {
  const WarehouseCard({super.key, required this.warehouse});

  final Warehouse warehouse;

  /// How tall Flutter lays out the code's line: 14pt × 1.2 is 16.8, which it
  /// rounds to a whole point — the line `Komanda`'s pads were set against.
  static const double _codeLine = 17;

  /// From the card's top to the name's line when there is no code above it.
  ///
  /// With a code, the name's capitals stand [CashDeskCard.kSeenGap] under
  /// the code's baseline; without one, they stand where the code's capitals
  /// would — a 14pt ChakraPetch capital (0.7 of its size) over that
  /// baseline. The name's line moves up by the difference: 10.9pt from the
  /// top, where the code's is 14.31.
  static const double kPadTopNoCode =
      TeamCard.kPadTop +
      _codeLine +
      CashDeskCard.kCodeGap -
      (CashDeskCard.kSeenGap + 14 * 0.7);

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final Warehouse warehouse = this.warehouse;
    final String? code = warehouse.code;
    final bool? active = warehouse.active;

    final List<Widget> rows = <Widget>[
      _Pair(label: 'Növü:', value: warehouse.typeLabel, scale: s),
      _Pair(
        // `Komanda`'s design sets the status two spaces from its label.
        label: 'Status: ',
        value: switch (active) {
          true => 'aktiv',
          false => 'deaktiv',
          null => kUnknownValue,
        },
        color: switch (active) {
          true => kSaleDone,
          false => kSalePending,
          null => null,
        },
        scale: s,
      ),
    ];

    return Semantics(
      container: true,
      child: DatabaseCardSurface(
        padding: EdgeInsets.fromLTRB(
          TeamCard.kPadH * s,
          (code == null ? kPadTopNoCode : TeamCard.kPadTop) * s,
          TeamCard.kPadH * s,
          TeamCard.kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (code != null) ...<Widget>[
              Align(
                alignment: Alignment.centerLeft,
                // A code with its tail missing names another warehouse; one
                // too wide for the card is set smaller instead.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    code,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: kDatabaseFigureFont,
                      fontSize: 14 * s,
                      height: 1.2,
                      letterSpacing: 0,
                      color: kGlassInk,
                    ),
                  ),
                ),
              ),
              SizedBox(height: CashDeskCard.kCodeGap * s),
            ],
            Text(
              _given(warehouse.name) ?? kUnknownValue,
              style: TeamCard.nameStyle(s),
            ),
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              SizedBox(
                height: (i == 0 ? CashDeskCard.kNameGap : TeamCard.kRowGap) * s,
              ),
              rows[i],
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

/// `Növü: Standart` — a heading and its value on one line, a space apart as
/// `Komanda`'s design sets them.
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

  /// The value's own colour — the status' green or red — or null for ink.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = databaseCardStyle(14 * scale);
    final Color? color = this.color;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label ',
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: color == null ? null : body.copyWith(color: color),
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
