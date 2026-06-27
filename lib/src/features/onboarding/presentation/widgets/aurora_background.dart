import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen, slowly moving liquid wallpaper for onboarding.
///
/// The background is generated entirely with Flutter painting primitives: a deep
/// navy base, large cubic-Bezier ribbons, soft screen-blended glow passes,
/// lavender edge highlights, and a subtle vignette for foreground readability.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _loopDuration = Duration(seconds: 52);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _loopDuration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_controller),
        size: Size.infinite,
        isComplex: true,
        willChange: true,
      ),
    );
  }
}

class _RibbonSpec {
  const _RibbonSpec({
    required this.phase,
    required this.cycles,
    required this.topOffset,
    required this.thickness,
    required this.amplitude,
    required this.colorA,
    required this.colorB,
    required this.colorC,
    required this.blurSigma,
    required this.highlightAlpha,
    required this.highlightShift,
  });

  final double phase;
  final double cycles;
  final double topOffset;
  final double thickness;
  final double amplitude;
  final Color colorA;
  final Color colorB;
  final Color colorC;
  final double blurSigma;
  final int highlightAlpha;
  final double highlightShift;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const Color _navyTop = Color(0xFF02030B);
  static const Color _navyMid = Color(0xFF050827);
  static const Color _navyBottom = Color(0xFF03020F);
  static const Color _electricBlue = Color(0xFF246BFF);
  static const Color _violet = Color(0xFF6934E8);
  static const Color _lavender = Color(0xFFC9BDFF);

  static const List<_RibbonSpec> _ribbons = <_RibbonSpec>[
    _RibbonSpec(
      phase: 0.15,
      cycles: 1,
      topOffset: 0.13,
      thickness: 0.29,
      amplitude: 0.085,
      colorA: Color(0xEC1232C7),
      colorB: Color(0xE92762FF),
      colorC: Color(0xD16D37E7),
      blurSigma: 18,
      highlightAlpha: 135,
      highlightShift: 0.006,
    ),
    _RibbonSpec(
      phase: 2.20,
      cycles: 1,
      topOffset: 0.42,
      thickness: 0.25,
      amplitude: 0.105,
      colorA: Color(0xE5111D85),
      colorB: Color(0xE43463FF),
      colorC: Color(0xC7A541F3),
      blurSigma: 20,
      highlightAlpha: 150,
      highlightShift: -0.004,
    ),
    _RibbonSpec(
      phase: 4.35,
      cycles: 1,
      topOffset: 0.69,
      thickness: 0.30,
      amplitude: 0.095,
      colorA: Color(0xDD1335B9),
      colorB: Color(0xD92B77FF),
      colorC: Color(0xC37528DE),
      blurSigma: 22,
      highlightAlpha: 120,
      highlightShift: 0.008,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double t = animation.value;

    _paintBase(canvas, bounds);
    _paintAmbientGlows(canvas, bounds, t);

    for (final _RibbonSpec ribbon in _ribbons) {
      _paintRibbon(canvas, size, ribbon, t, glow: true);
    }
    for (final _RibbonSpec ribbon in _ribbons) {
      _paintRibbon(canvas, size, ribbon, t);
      _paintHighlight(canvas, size, ribbon, t);
    }

    _paintReadabilityWash(canvas, bounds);
    _paintVignette(canvas, bounds);
  }

  void _paintBase(Canvas canvas, Rect bounds) {
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[_navyTop, _navyMid, _navyBottom],
        stops: <double>[0, 0.48, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  void _paintAmbientGlows(Canvas canvas, Rect bounds, double t) {
    final double pulse = math.sin(math.pi * 2 * t);
    final Offset blueCenter = Offset(
      bounds.width * (0.18 + 0.025 * math.cos(math.pi * 2 * t)),
      bounds.height * (0.78 + 0.018 * pulse),
    );
    final Offset violetCenter = Offset(
      bounds.width * (0.86 + 0.02 * math.sin(math.pi * 2 * t)),
      bounds.height * (0.20 + 0.018 * math.cos(math.pi * 2 * t)),
    );

    _paintGlow(canvas, bounds, blueCenter, _electricBlue.withAlpha(66), 0.82);
    _paintGlow(canvas, bounds, violetCenter, _violet.withAlpha(51), 0.72);
  }

  void _paintGlow(
    Canvas canvas,
    Rect bounds,
    Offset center,
    Color color,
    double radius,
  ) {
    final Paint paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / bounds.width) * 2 - 1,
          (center.dy / bounds.height) * 2 - 1,
        ),
        radius: radius,
        colors: <Color>[color, color.withAlpha(0)],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  void _paintRibbon(
    Canvas canvas,
    Size size,
    _RibbonSpec spec,
    double t, {
    bool glow = false,
  }) {
    final Path path = _buildRibbonPath(size, spec, t);
    final Rect shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint paint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          spec.colorA.withAlpha(glow ? 92 : 209),
          spec.colorB.withAlpha(glow ? 110 : 235),
          spec.colorC.withAlpha(glow ? 71 : 184),
        ],
        stops: const <double>[0.02, 0.52, 1],
      ).createShader(shaderRect);

    if (glow) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, spec.blurSigma);
    }

    canvas.drawPath(path, paint);
  }

  Path _buildRibbonPath(Size size, _RibbonSpec spec, double t) {
    final double w = size.width;
    final double h = size.height;
    final double phase = math.pi * 2 * (spec.cycles * t) + spec.phase;
    final double amp = spec.amplitude * h;
    final double top = spec.topOffset * h;
    final double bottom = top + spec.thickness * h;

    double wave(double x, double direction) {
      return math.sin(phase + direction * x * 1.55) * amp +
          math.cos(phase * 0.7 - direction * x * 2.05) * amp * 0.42;
    }

    final Offset a0 = Offset(-0.20 * w, top + wave(0.00, 1));
    final Offset a1 = Offset(0.18 * w, top + wave(0.28, 1));
    final Offset a2 = Offset(0.42 * w, top + wave(0.55, 1));
    final Offset a3 = Offset(0.76 * w, top + wave(0.82, 1));
    final Offset a4 = Offset(1.20 * w, top + wave(1.12, 1));

    final Offset b0 = Offset(1.20 * w, bottom + wave(1.12, -1));
    final Offset b1 = Offset(0.80 * w, bottom + wave(0.82, -1));
    final Offset b2 = Offset(0.54 * w, bottom + wave(0.55, -1));
    final Offset b3 = Offset(0.24 * w, bottom + wave(0.28, -1));
    final Offset b4 = Offset(-0.20 * w, bottom + wave(0.00, -1));

    return Path()
      ..moveTo(a0.dx, a0.dy)
      ..cubicTo(0.04 * w, a0.dy - amp, 0.08 * w, a1.dy + amp, a1.dx, a1.dy)
      ..cubicTo(0.30 * w, a1.dy - amp, 0.30 * w, a2.dy + amp, a2.dx, a2.dy)
      ..cubicTo(0.56 * w, a2.dy - amp, 0.58 * w, a3.dy + amp, a3.dx, a3.dy)
      ..cubicTo(0.96 * w, a3.dy - amp, 0.98 * w, a4.dy + amp, a4.dx, a4.dy)
      ..lineTo(b0.dx, b0.dy)
      ..cubicTo(0.98 * w, b0.dy + amp, 0.96 * w, b1.dy - amp, b1.dx, b1.dy)
      ..cubicTo(0.64 * w, b1.dy + amp, 0.68 * w, b2.dy - amp, b2.dx, b2.dy)
      ..cubicTo(0.34 * w, b2.dy + amp, 0.42 * w, b3.dy - amp, b3.dx, b3.dy)
      ..cubicTo(0.02 * w, b3.dy + amp, 0.03 * w, b4.dy - amp, b4.dx, b4.dy)
      ..close();
  }

  void _paintHighlight(Canvas canvas, Size size, _RibbonSpec spec, double t) {
    final Path curve = _buildHighlightPath(size, spec, t);
    final Paint glow = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * 0.055
      ..color = _lavender.withAlpha((spec.highlightAlpha * 0.38).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final Paint edge = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.shortestSide * 0.012
      ..color = _lavender.withAlpha(spec.highlightAlpha);

    canvas.drawPath(curve, glow);
    canvas.drawPath(curve, edge);
  }

  Path _buildHighlightPath(Size size, _RibbonSpec spec, double t) {
    final double w = size.width;
    final double h = size.height;
    final double phase = math.pi * 2 * (spec.cycles * t) + spec.phase;
    final double amp = spec.amplitude * h;
    final double y = (spec.topOffset + spec.thickness + spec.highlightShift) * h;

    double wave(double x) {
      return math.sin(phase - x * 1.65) * amp +
          math.cos(phase * 0.7 + x * 2.1) * amp * 0.35;
    }

    final Offset p0 = Offset(-0.14 * w, y + wave(0.00));
    final Offset p1 = Offset(0.22 * w, y + wave(0.30));
    final Offset p2 = Offset(0.52 * w, y + wave(0.62));
    final Offset p3 = Offset(0.84 * w, y + wave(0.90));
    final Offset p4 = Offset(1.14 * w, y + wave(1.12));

    return Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(0.05 * w, p0.dy + amp, 0.10 * w, p1.dy - amp, p1.dx, p1.dy)
      ..cubicTo(0.34 * w, p1.dy + amp, 0.36 * w, p2.dy - amp, p2.dx, p2.dy)
      ..cubicTo(0.68 * w, p2.dy + amp, 0.66 * w, p3.dy - amp, p3.dx, p3.dy)
      ..cubicTo(1.00 * w, p3.dy + amp, 1.00 * w, p4.dy - amp, p4.dx, p4.dy);
  }

  void _paintReadabilityWash(Canvas canvas, Rect bounds) {
    final Paint paint = Paint()
      ..color = const Color(0x2B02030B)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(bounds, paint);
  }

  void _paintVignette(Canvas canvas, Rect bounds) {
    final Paint paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.94,
        colors: <Color>[Color(0x00000000), Color(0x8A01020A)],
        stops: <double>[0.50, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;
}
