import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/team_member.dart';
import '../database_format.dart';
import 'database_card.dart';
import 'database_glass.dart';

/// One person on the staff register: the code, the name, and under them
/// `Vəzifə`, `Şöbə`, `Maaş` and `Status` — each only when 1C has it.
///
/// 1C leaves much of the register blank (57 of 61 people had no position on
/// 2026-10-05), and the user's rule is that a field with nothing in it is no
/// row at all rather than a row saying `—`: the rows under it close up and
/// the card is that much shorter. The card does not open — the user's word,
/// there being too little on it to open onto — so a tap does nothing.
///
/// The numbers are the design's, measured off its frame at 2px a point:
/// the code ChakraPetch at 14, its baseline 27.5pt down; the name CalSans at
/// 22 on 29pt lines, its first baseline 38.5pt under the code's, taking
/// every line it needs; the first row's baseline 34pt under the name's
/// last; Poppins at 14, every row 29pt under the one before; the last 22pt
/// above the bottom edge. A two-line name with all four rows is 238pt.
class TeamCard extends StatelessWidget {
  const TeamCard({super.key, required this.member});

  final TeamMember member;

  /// 23pt either side — every `Baza` card's — and above the code's line.
  ///
  /// The gaps below are between the lines' boxes, and a 14pt line at 1.2
  /// is laid out 17pt tall, not 16.8: the text engine rounds it to a whole
  /// point (see [databaseCardStyle]).
  static const double kPadH = 23;
  static const double kPadTop = 14.31;

  /// Under the last row's line.
  static const double kPadBottom = 18.3;

  /// The name's size and its line: 29pt, the rows' own pitch.
  static const double kName = 22;
  static const double kNameHeight = 29 / kName;

  /// From the code's line to the name's.
  static const double kCodeGap = 12.49;

  /// From the name's last line to the first row's.
  static const double kNameGap = 13.9;

  /// Between one row's line and the next: rows 29pt apart.
  static const double kRowGap = 12;

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
    final TeamMember member = this.member;
    final String? position = _given(member.position);
    final String? department = _given(member.department);
    final double? salary = member.salary;
    final bool? active = member.active;

    // Only what 1C has.
    final List<Widget> rows = <Widget>[
      if (position != null) _Pair(label: 'Vəzifə:', value: position, scale: s),
      if (department != null)
        _Pair(label: 'Şöbə:', value: department, scale: s),
      if (salary != null)
        _Pair(label: 'Maaş:', value: formatMoney(salary), scale: s),
      if (active != null)
        _Pair(
          // The design sets the status two spaces from its label.
          label: 'Status: ',
          value: active ? 'aktiv' : 'deaktiv',
          color: active ? kSaleDone : kSalePending,
          scale: s,
        ),
    ];

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
            Align(
              alignment: Alignment.centerLeft,
              // A code with its tail missing names somebody else; one too
              // wide for the card is set smaller instead.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  member.code ?? kUnknownValue,
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
            // Every line it needs, and never one word on the last.
            _Name(
              text: _given(member.name) ?? kUnknownValue,
              style: nameStyle(s),
            ),
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              SizedBox(height: (i == 0 ? kNameGap : kRowGap) * s),
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

/// A name that needs more than one line, with no word left alone on its
/// last.
///
/// Most names on the register are a surname, a name and a patronymic with
/// `oğlu` or `qızı`, and filled line by line they leave that last word on a
/// line of its own: `Məhərrəmova Pərvanə Ələstun / qızı`. The design breaks
/// it `Məhərrəmova Pərvanə / Ələstun qızı`. So when the last line would be
/// one word, the line before gives it its own last word — set a hair
/// narrower than that line — as long as that costs no extra line and leaves
/// a word behind.
class _Name extends StatelessWidget {
  const _Name({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double room = constraints.maxWidth;
        final double width = room.isFinite
            ? _width(room, scaler, direction)
            : room;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            child: Text(text, style: style),
          ),
        );
      },
    );
  }

  /// [room], or the narrower width that brings a lone last word company.
  double _width(double room, TextScaler scaler, TextDirection direction) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: room);
    try {
      final List<LineMetrics> lines = painter.computeLineMetrics();
      if (lines.length < 2) return room;

      String line(int index) {
        final TextRange range = painter.getLineBoundary(
          painter.getPositionForOffset(
            Offset(0, lines[index].baseline - lines[index].ascent / 2),
          ),
        );
        return text.substring(range.start, range.end).trim();
      }

      // The last line already has company, or the one before has only the
      // word it would give away.
      if (line(lines.length - 1).contains(' ')) return room;
      if (!line(lines.length - 2).contains(' ')) return room;

      final double narrower = lines[lines.length - 2].width - 0.5;
      painter.layout(maxWidth: narrower);
      if (painter.computeLineMetrics().length != lines.length) return room;
      return narrower;
    } finally {
      painter.dispose();
    }
  }
}

/// `Vəzifə: Paketçi` — a heading and its value on one line, a space apart
/// as the design sets them.
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
      // A department too long for the card is set smaller, never cut.
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
