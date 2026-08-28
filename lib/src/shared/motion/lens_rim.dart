import 'package:flutter/material.dart';

/// How much of the painted bevel below is drawn.
///
/// It was built at full strength for a capsule whose shader contributed no
/// visible border at all. `liquid_glass_easy`'s optical border now draws a rim
/// of its own inside the same edge, so the paint is held back to a supporting
/// role: it carries the shaded band on the underside, which no shader here
/// draws, without restating the highlight the rim already has. This is the
/// knob if the two read as one thick edge, or as none.
const double _kRimStrength = 0.55;

/// The bevel, painted over the lens.
///
/// A lens on light ground has very little contrast to make an edge out of, so
/// the border here is built the way a real bevel reads on white: a shaded band
/// just inside the edge carrying most of the definition, and a specular
/// highlight on top of it catching the light from above. Both follow the
/// superellipse's own continuous curve, and the spill is allowed either side
/// of the edge rather than stopping at it.
class LensRimPainter extends CustomPainter {
  const LensRimPainter({required this.radius, required this.lens});

  final double radius;

  /// Fades the whole bevel in with the swell, and widens the spill as it goes.
  final double lens;

  /// The bevel's own opacity is folded into every colour rather than into a
  /// `saveLayer` — a layer opened above a lens is what turns it black.
  Color _white(double alpha) =>
      Color.fromRGBO(255, 255, 255, alpha * lens * _kRimStrength);

  Color _shade(double alpha) =>
      Color.fromRGBO(18, 26, 38, alpha * lens * _kRimStrength);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || lens <= 0) return;

    final Rect rect = Offset.zero & size;
    final BorderRadius corner = BorderRadius.circular(radius);
    final Path rim = RoundedSuperellipseBorder(
      borderRadius: corner,
    ).getOuterPath(rect.deflate(0.55));

    // The wide spill first — light leaving the edge and landing on the bar.
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _white(0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 9 + 5 * lens),
    );

    // The shaded band, inside the edge and heaviest along the bottom, where a
    // dome this shape stops catching the light. This is what actually gives
    // the capsule an outline against a white background.
    canvas.drawPath(
      RoundedSuperellipseBorder(
        borderRadius: corner,
      ).getOuterPath(rect.deflate(1.9)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6)
        ..shader =
            LinearGradient(
              begin: const Alignment(-0.3, -1),
              end: const Alignment(0.3, 1),
              colors: <Color>[_shade(0), _shade(0.08), _shade(0.22)],
              stops: const <double>[0, 0.5, 1],
            ).createShader(rect),
    );

    // The specular on top of it: brightest where the light lands, a second
    // softer arc opposite, and dim flanks between the two.
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader =
            LinearGradient(
              begin: const Alignment(-0.35, -1),
              end: const Alignment(0.35, 1),
              colors: <Color>[
                _white(0.95),
                _white(0.40),
                _white(0.10),
                _white(0.30),
                _white(0.60),
              ],
              stops: const <double>[0, 0.24, 0.52, 0.78, 1],
            ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant LensRimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.lens != lens;
}
