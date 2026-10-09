import 'package:flutter/material.dart';

import '../../domain/cash_desk.dart';
import '../../domain/database_filter.dart' show tidySpaces;
import 'database_card.dart';
import 'database_glass.dart';
import 'team_card.dart';

/// One cash desk: the code, the name, and under them `Valyuta` and
/// `Status` — the website's four columns, without its guid (the user's
/// word).
///
/// There is no design of its own: the user's word is that the tab's cards
/// are all of a kind, and this one is `Komanda`'s — a code over a name over
/// rows — so it takes that card's faces, sizes and edges ([TeamCard]): the
/// code ChakraPetch at 14, its baseline 27.5pt down; the name CalSans at 22
/// on 29pt lines, taking every line it needs; Poppins at 14 for the rows;
/// the last 22pt above the bottom edge.
///
/// What it does not take is `Komanda`'s spacing. There the name stands
/// further off than the rows do from each other; here the user asked for
/// the three gaps — code to name, name to `Valyuta`, `Valyuta` to
/// `Status` — to be the same (2026-10-06), and set to the one between the
/// rows, which they left as it was. A gap is measured as it is seen: from
/// one line's baseline to the top of the capitals under it. A one-line name
/// makes a 142.1pt card — baselines 27.5, 62.1, 91.1 and 120.1pt down. The
/// card does not open — the user's word, there being too little on it to
/// open onto — so a tap does nothing.
class CashDeskCard extends StatelessWidget {
  const CashDeskCard({super.key, required this.desk});

  final CashDesk desk;

  /// The one gap the eye sees between every two lines: from the rows' 29pt
  /// pitch, less the capitals of a 14pt Poppins line (0.698 of its size).
  static const double kSeenGap = 29 - 14 * 0.698;

  /// From the code's line to the name's: the name's first baseline
  /// [kSeenGap] plus a 22pt CalSans capital (0.7 of its size) under the
  /// code's — 34.6pt, where `Komanda`'s is 38.5.
  static const double kCodeGap =
      TeamCard.kCodeGap - (38.5 - (kSeenGap + TeamCard.kName * 0.7));

  /// From the name's last line to `Valyuta`'s: the rows' own 29pt pitch,
  /// where `Komanda`'s is 34.
  static const double kNameGap = TeamCard.kNameGap - (34 - 29);

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final CashDesk desk = this.desk;
    final bool? active = desk.active;

    final List<Widget> rows = <Widget>[
      _Pair(label: 'Valyuta:', value: desk.currency, scale: s),
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
          TeamCard.kPadTop * s,
          TeamCard.kPadH * s,
          TeamCard.kPadBottom * s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              // A code with its tail missing names another desk; one too
              // wide for the card is set smaller instead.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  desk.code ?? kUnknownValue,
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
            SizedBox(height: kCodeGap * s),
            Text(
              _given(desk.name) ?? kUnknownValue,
              style: TeamCard.nameStyle(s),
            ),
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              SizedBox(height: (i == 0 ? kNameGap : TeamCard.kRowGap) * s),
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

/// `Valyuta: AZN` — a heading and its value on one line, a space apart as
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
