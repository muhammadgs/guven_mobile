import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

import '../../domain/database_filter.dart' show tidySpaces;
import '../../domain/unit_of_measure.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'team_card.dart';

/// One unit of measure: its code on the left, its name in the middle, its
/// international code on the right — a line of the one card the whole
/// catalogue is drawn on.
///
/// A unit is too little for a card of its own (the user, 2026-10-10), so the
/// list is a single pane, the tab's yellow, with a rule between one line and
/// the next. A line is built on its own, as the list scrolls, so each draws
/// its own slice of that pane — [first] the slice with the pane's top
/// corners, [last] the one with its bottom ones; the slices meet with no seam
/// between them (see [_Slice]).
///
/// The numbers are the design's, measured off its frame at 1.386px a point:
/// the code ChakraPetch at 14, the name CalSans at 22, the international
/// code Poppins italic at 14, all three on one baseline; the first baseline
/// 31pt below the pane's top; a 1pt rule in ink 9.55pt under each baseline,
/// 12pt short of either edge; the next baseline 28.71pt under the rule — a
/// line every 38.26pt. The code stands at every card's 23pt, the
/// international code at 305.3pt, and the name is centred between them,
/// 175.1pt in, where the design draws it. The last line has no rule: its
/// baseline is 20pt off the pane's bottom, the way a card's last row sits
/// 4.3pt further from its foot than its first capitals from its head.
class UnitOfMeasureRow extends StatelessWidget {
  const UnitOfMeasureRow({
    super.key,
    required this.unit,
    required this.first,
    required this.last,
  });

  final UnitOfMeasure unit;

  /// The pane's first line: its top corners, and a little more room above.
  final bool first;

  /// The pane's last line — the catalogue's, not only the last one loaded:
  /// its bottom corners, and no rule under it.
  final bool last;

  /// Above the line's box on the first line: the first baseline 31pt down.
  ///
  /// The name's 22pt CalSans line is the line's box — laid out 26pt tall
  /// (26.4, rounded to a whole point), its baseline 20.9pt down it, as
  /// measured; the code's and the international code's lie inside it.
  static const double kPadTopFirst = 10.1;

  /// Above the line's box on every other line: the baseline 28.71pt under
  /// the middle of the rule above.
  static const double kPadTop = 7.31;

  /// From the line's box to the rule: the rule's middle 9.55pt under the
  /// baseline.
  static const double kRuleGap = 3.95;

  /// Under the last line's box: its baseline 20pt off the pane's foot.
  static const double kPadBottomLast = 14.9;

  /// The rule between lines: 1pt of ink, 12pt short of either edge.
  static const double kRule = 1;
  static const double kRuleInset = 12;

  /// The room the code has, from [TeamCard.kPadH]: a three-figure code is
  /// at most 24pt; a longer one is set smaller rather than cut.
  static const double kCodeColumn = 32;

  /// From the pane's right edge to the international code's left: it stands
  /// at 305.3pt on the 363pt pane.
  static const double kUnitInset = 57.7;

  /// The name's room stops this short of the international code — which
  /// centres it at the design's 175.1pt.
  static const double kUnitGap = 10.1;

  /// The name's face: `Komanda`'s 22pt CalSans, on a line of its own size.
  static TextStyle nameStyle(double scale) => TextStyle(
    fontFamily: 'CalSans',
    fontSize: TeamCard.kName * scale,
    height: 1.2,
    letterSpacing: 0,
    color: kGlassInk,
  );

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final String? code = _given(unit.code);
    final String? international = _given(unit.internationalCode);

    final Widget line = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: kCodeColumn * s,
          child: code == null
              ? null
              : _Fitted(
                  code,
                  alignment: Alignment.centerLeft,
                  style: TextStyle(
                    fontFamily: kDatabaseFigureFont,
                    fontSize: 14 * s,
                    height: 1.2,
                    letterSpacing: 0,
                    color: kGlassInk,
                  ),
                ),
        ),
        Expanded(
          child: _Fitted(
            _given(unit.name) ?? kUnknownValue,
            alignment: Alignment.center,
            style: nameStyle(s),
          ),
        ),
        SizedBox(width: kUnitGap * s),
        SizedBox(
          width: (kUnitInset - TeamCard.kPadH) * s,
          // A blank international code — nine of the 32 — is no word at all
          // rather than a `—` (the user's rule for a blank field).
          child: international == null
              ? null
              : _Fitted(
                  international,
                  alignment: Alignment.centerLeft,
                  style: databaseCardStyle(14 * s, style: FontStyle.italic),
                ),
        ),
      ],
    );

    return Semantics(
      container: true,
      child: _Slice(
        top: first,
        bottom: last,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: (first ? kPadTopFirst : kPadTop) * s),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: TeamCard.kPadH * s),
              child: line,
            ),
            if (last)
              SizedBox(height: kPadBottomLast * s)
            else ...<Widget>[
              SizedBox(height: kRuleGap * s),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kRuleInset * s),
                child: SizedBox(
                  height: kRule * s,
                  child: const ColoredBox(color: kGlassInk),
                ),
              ),
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

/// One word on one line, set smaller rather than cut when it has not the
/// room: a code or a name with its tail missing names another unit.
class _Fitted extends StatelessWidget {
  const _Fitted(this.text, {required this.alignment, required this.style});

  final String text;
  final AlignmentGeometry alignment;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

/// A line's slice of the pane: [kDatabaseCardFill] over the list's shared
/// blur, with the pane's corners if it is the [top] or [bottom] slice.
///
/// The slices meet at fractional pixels, and scroll through every fraction
/// of one. An anti-aliased edge there would be half-drawn by each slice —
/// a pale seam between every two lines. So the slice is cut with a hard
/// edge, which gives each pixel to exactly one slice, and the tint is laid
/// on past its edges for the cut to trim. Only the corners are cut
/// smoothly, by a rounded clip that reaches well past the slice's straight
/// edges so its own softening falls where the hard cut has already been.
class _Slice extends StatelessWidget {
  const _Slice({required this.top, required this.bottom, required this.child});

  final bool top;
  final bool bottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget slice = ClipRect(
      clipBehavior: Clip.hardEdge,
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(
          sigmaX: kDatabaseRowBlurSigma,
          sigmaY: kDatabaseRowBlurSigma,
        ),
        child: CustomPaint(painter: const _Tint(), child: child),
      ),
    );
    if (!top && !bottom) return slice;
    return ClipRRect(
      clipper: _Corners(
        top: top,
        bottom: bottom,
        radius: kDatabaseCardRadius * databaseScale(context),
      ),
      child: slice,
    );
  }
}

/// The pane's tint, laid a pixel past the slice on every side for the hard
/// cut around it to trim.
class _Tint extends CustomPainter {
  const _Tint();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      (Offset.zero & size).inflate(1),
      Paint()
        ..color = kDatabaseCardFill
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_Tint oldDelegate) => false;
}

/// The pane's corners on a slice: rounded at its [top], its [bottom], or
/// both — and running on past whichever edge meets another slice.
class _Corners extends CustomClipper<RRect> {
  const _Corners({
    required this.top,
    required this.bottom,
    required this.radius,
  });

  final bool top;
  final bool bottom;
  final double radius;

  @override
  RRect getClip(Size size) {
    final Radius round = Radius.circular(radius);
    return RRect.fromRectAndCorners(
      Rect.fromLTRB(
        0,
        top ? 0 : -radius,
        size.width,
        bottom ? size.height : size.height + radius,
      ),
      topLeft: top ? round : Radius.zero,
      topRight: top ? round : Radius.zero,
      bottomLeft: bottom ? round : Radius.zero,
      bottomRight: bottom ? round : Radius.zero,
    );
  }

  @override
  bool shouldReclip(_Corners oldClipper) =>
      oldClipper.top != top ||
      oldClipper.bottom != bottom ||
      oldClipper.radius != radius;
}
