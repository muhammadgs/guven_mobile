import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/database_metric.dart';
import 'database_glass.dart';

/// One figure on `Əsas panel`: a glyph and a name on the left, the figure on
/// the right, and the metric's colour curling round the left end.
///
/// Not glass, by design: a flat grey fill over a plain background blur. Ten of
/// them stack on this screen, and ten live lenses would be both slower and
/// busier than the page wants. The blur is grouped with the rest of the list's
/// (`BackdropGroup`), so all ten are sampled once per frame.
class DatabaseOverviewRow extends StatelessWidget {
  const DatabaseOverviewRow({
    super.key,
    required this.metric,
    required this.value,
    required this.height,
  });

  final DatabaseMetric metric;

  /// The figure, already written out, or null while it is not known — the row
  /// then says `—`, never a 0 it would have to take back.
  final String? value;

  final double height;

  @override
  Widget build(BuildContext context) {
    // Every number below is the design's, on its own frame.
    final double s = databaseScale(context);

    return SizedBox(
      height: height,
      child: ClipRRect(
        // Fully round: the arc is drawn to the cap's own circle.
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter.grouped(
          filter: ui.ImageFilter.blur(
            sigmaX: kDatabaseRowBlurSigma,
            sigmaY: kDatabaseRowBlurSigma,
          ),
          child: ColoredBox(
            color: kDatabaseRowFill,
            child: CustomPaint(
              painter: DatabaseRowArcPainter(
                color: metric.arc,
                thickness: kDatabaseArcThickness * s,
              ),
              child: Padding(
                padding: EdgeInsets.only(left: 22.5 * s, right: 20 * s),
                child: Row(
                  children: <Widget>[
                    // One column for every glyph, as wide as the widest, so
                    // every glyph is centred on the same line and every name
                    // starts at the same x — the glyphs are different sizes,
                    // the rows must not look it.
                    SizedBox(
                      width: 28 * s,
                      child: Center(
                        child: SvgPicture.asset(
                          metric.icon,
                          width: metric.iconSize * s,
                          height: metric.iconSize * s,
                          colorFilter: const ColorFilter.mode(
                            kGlassInk,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    Expanded(
                      // `Ümumi Satış Məbləği` beside a seven-figure amount
                      // does not fit a 360pt phone at the design's size; it
                      // is set a little smaller there rather than cut.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metric.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: kGlassInk,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 15 * s,
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 150 * s),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _Figure(
                          value: value,
                          // Amounts are set smaller than counts, as the
                          // design does: `1,455,475.61 ₼` at a count's size
                          // would crowd the name off the row.
                          fontSize: (metric.isMoney ? 15 : 20) * s,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.fontSize});

  final String? value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final String? value = this.value;
    // Swapped rather than cross-faded, like the home screen's counts: a
    // half-faded digit is exactly the ambiguity a figure must never have.
    return Text(
      value ?? '—',
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: value == null ? kGlassInkMuted : kGlassInk,
        fontFamily: kDatabaseFigureFont,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        height: 1.1,
        letterSpacing: 0,
      ),
    );
  }
}

/// The coloured crescent on a row's left end.
///
/// The cap's own circle minus the same circle moved [thickness] to the right:
/// widest at the far left, thinning to nothing where it meets the row's top
/// and bottom edges, and fading as it goes — full colour round the end, clear
/// by the tips.
///
/// Public so the arithmetic can be tested without a screen.
class DatabaseRowArcPainter extends CustomPainter {
  const DatabaseRowArcPainter({required this.color, required this.thickness});

  final Color color;

  /// Width of the crescent at its widest, in logical pixels.
  final double thickness;

  /// The crescent for a row of [size], in the row's own coordinates.
  ///
  /// The outer circle is let out a point past the cap: the row's clip draws
  /// the outer edge, and two antialiased edges laid exactly over each other
  /// leave a faint seam of the backdrop between them.
  static Path crescent(Size size, double thickness) {
    final double radius = size.height / 2;
    final Rect cap = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );
    return Path.combine(
      PathOperation.difference,
      Path()..addOval(cap.inflate(1)),
      Path()..addOval(cap.shift(Offset(thickness, 0))),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || thickness <= 0) return;
    // How far right the crescent reaches: its tips sit half a thickness past
    // the end of the cap.
    final double reach = size.height / 2 + thickness / 2;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[color, color, color.withValues(alpha: 0)],
        stops: const <double>[0, 0.4, 1],
      ).createShader(Rect.fromLTWH(0, 0, reach, size.height));
    canvas.drawPath(crescent(size, thickness), paint);
  }

  @override
  bool shouldRepaint(covariant DatabaseRowArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}
