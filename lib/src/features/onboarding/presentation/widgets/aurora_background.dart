import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Full-screen animated liquid-wave backdrop for the onboarding flow.
///
/// The background is intentionally made from smooth oversized curves and thick
/// rounded strokes, not sharp polygons. That keeps the liquid sheets soft even
/// before an extra blur layer is added over the onboarding content.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// Calm but visible motion.
  static const Duration _loop = Duration(seconds: 24);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _loop)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LiquidWavePainter(_controller),
        size: Size.infinite,
        isComplex: true,
        willChange: true,
      ),
    );
  }
}

class _LiquidWavePainter extends CustomPainter {
  _LiquidWavePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const Color _navyTop = Color(0xFF030416);
  static const Color _navyBottom = Color(0xFF050736);
  static const Color _deepNavy = Color(0xFF01021F);
  static const Color _royalBlue = Color(0xFF1557FF);
  static const Color _cobalt = Color(0xFF1735D8);
  static const Color _electricBlue = Color(0xFF2F73FF);
  static const Color _violet = Color(0xFF6C36F4);
  static const Color _lavender = Color(0xFFD8CCFF);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double t = animation.value;

    _paintBase(canvas, bounds);
    _paintTopSheet(canvas, size, t);
    _paintLeftSheet(canvas, size, t);
    _paintBottomSheet(canvas, size, t);
    _paintSoftShadowChannels(canvas, size, t);
    _paintLightFolds(canvas, size, t);
    _paintVignette(canvas, bounds);
  }

  void _paintBase(Canvas canvas, Rect bounds) {
    const LinearGradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[_navyTop, _navyBottom],
    );

    canvas.drawRect(bounds, Paint()..shader = gradient.createShader(bounds));
  }

  /// The wide upper liquid surface. All control points that close the shape are
  /// outside the visible screen, so no straight / pointed closing edge can show.
  void _paintTopSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double a = math.sin(math.pi * 2 * t);
    final double b = math.sin(math.pi * 2 * t + 1.35);
    final double c = math.sin(math.pi * 4 * t + 0.75);

    final Path sheet = Path()
      ..moveTo(-0.34 * w, -0.20 * h)
      ..cubicTo(
        0.16 * w + a * 14,
        -0.22 * h,
        0.78 * w - b * 18,
        -0.15 * h,
        1.30 * w,
        -0.08 * h,
      )
      ..cubicTo(
        1.05 * w + b * 14,
        0.10 * h,
        0.94 * w - a * 22,
        0.30 * h,
        0.95 * w + c * 10,
        0.47 * h,
      )
      ..cubicTo(
        0.76 * w + c * 16,
        0.50 * h,
        0.59 * w - a * 22,
        0.47 * h,
        0.43 * w + b * 16,
        0.36 * h,
      )
      ..cubicTo(
        0.28 * w + a * 12,
        0.25 * h,
        0.13 * w - b * 22,
        0.32 * h,
        -0.34 * w,
        0.18 * h,
      )
      ..cubicTo(
        -0.42 * w,
        0.03 * h,
        -0.42 * w,
        -0.13 * h,
        -0.34 * w,
        -0.20 * h,
      )
      ..close();

    _drawSoftFill(
      canvas,
      sheet,
      Rect.fromLTWH(-0.05 * w, -0.12 * h, 1.12 * w, 0.68 * h),
      const <Color>[
        Color(0xFF050844),
        _royalBlue,
        _cobalt,
        Color(0xFF090B40),
      ],
      const <double>[0.0, 0.36, 0.72, 1.0],
      blur: 5,
    );
  }

  /// Large lower-left liquid mass. This replaces the earlier angular pocket that
  /// created a visible sharp wedge around the logo area.
  void _paintLeftSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double a = math.sin(math.pi * 2 * t + 2.15);
    final double b = math.sin(math.pi * 2 * t + 3.55);
    final double c = math.sin(math.pi * 4 * t + 1.55);

    final Path sheet = Path()
      ..moveTo(-0.34 * w, 0.20 * h)
      ..cubicTo(
        -0.02 * w + a * 16,
        0.25 * h,
        0.22 * w - b * 18,
        0.31 * h,
        0.31 * w + c * 10,
        0.45 * h,
      )
      ..cubicTo(
        0.39 * w + b * 20,
        0.59 * h,
        0.57 * w - a * 18,
        0.59 * h,
        0.46 * w + c * 12,
        0.73 * h,
      )
      ..cubicTo(
        0.38 * w - b * 14,
        0.85 * h,
        0.58 * w + a * 16,
        0.88 * h,
        0.42 * w,
        1.20 * h,
      )
      ..cubicTo(
        0.14 * w,
        1.26 * h,
        -0.25 * w,
        1.16 * h,
        -0.34 * w,
        0.92 * h,
      )
      ..cubicTo(
        -0.42 * w,
        0.68 * h,
        -0.43 * w,
        0.39 * h,
        -0.34 * w,
        0.20 * h,
      )
      ..close();

    _drawSoftFill(
      canvas,
      sheet,
      Rect.fromLTWH(-0.12 * w, 0.22 * h, 0.82 * w, 0.98 * h),
      const <Color>[
        Color(0xFF06104C),
        _electricBlue,
        _cobalt,
        _violet,
        Color(0xFF04042D),
      ],
      const <double>[0.0, 0.24, 0.54, 0.80, 1.0],
      blur: 7,
    );
  }

  /// Violet-blue surface flowing through the lower-right corner.
  void _paintBottomSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double a = math.sin(math.pi * 2 * t + 4.1);
    final double b = math.sin(math.pi * 2 * t + 5.35);
    final double c = math.sin(math.pi * 4 * t + 2.7);

    final Path sheet = Path()
      ..moveTo(0.42 * w + b * 10, 0.65 * h)
      ..cubicTo(
        0.53 * w + a * 14,
        0.76 * h,
        0.63 * w - c * 12,
        0.71 * h,
        0.67 * w + b * 10,
        0.82 * h,
      )
      ..cubicTo(
        0.74 * w + c * 16,
        0.96 * h,
        0.95 * w - a * 12,
        0.88 * h,
        1.28 * w,
        1.02 * h,
      )
      ..cubicTo(
        1.30 * w,
        1.18 * h,
        1.03 * w,
        1.26 * h,
        0.60 * w,
        1.22 * h,
      )
      ..cubicTo(
        0.34 * w - b * 10,
        1.12 * h,
        0.31 * w + a * 14,
        0.86 * h,
        0.42 * w + b * 10,
        0.65 * h,
      )
      ..close();

    _drawSoftFill(
      canvas,
      sheet,
      Rect.fromLTWH(0.30 * w, 0.60 * h, 0.98 * w, 0.62 * h),
      const <Color>[
        Color(0xFF061157),
        _royalBlue,
        _violet,
        Color(0xFF4620B8),
      ],
      const <double>[0.0, 0.35, 0.76, 1.0],
      blur: 7,
    );
  }

  /// Smooth negative-space channels. They are drawn as huge rounded blurred
  /// strokes instead of closed pointed paths, so the dark folds cannot form
  /// triangular sharp tips while the animation moves.
  void _paintSoftShadowChannels(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 1.7);
    final double b = math.sin(math.pi * 2 * t + 4.4);

    final Path centralChannel = Path()
      ..moveTo(-0.10 * w, 0.22 * h)
      ..cubicTo(
        0.14 * w + a * 18,
        0.29 * h,
        0.30 * w - b * 16,
        0.34 * h,
        0.36 * w + a * 10,
        0.49 * h,
      )
      ..cubicTo(
        0.43 * w + b * 12,
        0.66 * h,
        0.61 * w - a * 16,
        0.62 * h,
        0.55 * w,
        0.80 * h,
      )
      ..cubicTo(
        0.52 * w - b * 12,
        0.94 * h,
        0.43 * w,
        1.03 * h,
        0.34 * w,
        1.16 * h,
      );

    _drawRoundedShadowStroke(
      canvas,
      centralChannel,
      width: longest * 0.125,
      blur: longest * 0.045,
      color: _deepNavy.withValues(alpha: 0.62),
    );

    final Path rightChannel = Path()
      ..moveTo(0.90 * w + b * 10, -0.12 * h)
      ..cubicTo(
        0.78 * w + a * 12,
        0.12 * h,
        0.79 * w - b * 10,
        0.30 * h,
        1.16 * w,
        0.44 * h,
      );

    _drawRoundedShadowStroke(
      canvas,
      rightChannel,
      width: longest * 0.180,
      blur: longest * 0.060,
      color: _deepNavy.withValues(alpha: 0.56),
    );
  }

  /// Lavender / blue light only follows open curves with round caps. End points
  /// sit outside or very close to the screen edge and are heavily blurred, so no
  /// small pointed glow appears on the right side.
  void _paintLightFolds(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 0.95);
    final double b = math.sin(math.pi * 2 * t + 2.55);
    final double c = math.sin(math.pi * 4 * t + 0.55);

    final Path topRim = Path()
      ..moveTo(-0.14 * w, 0.24 * h)
      ..cubicTo(
        0.12 * w - b * 16,
        0.31 * h,
        0.28 * w + a * 10,
        0.24 * h,
        0.43 * w + b * 14,
        0.36 * h,
      )
      ..cubicTo(
        0.58 * w - a * 18,
        0.48 * h,
        0.76 * w + c * 14,
        0.53 * h,
        1.13 * w,
        0.47 * h,
      );

    _drawGradientStroke(
      canvas,
      topRim,
      width: longest * 0.085,
      blur: longest * 0.038,
      colors: <Color>[
        _lavender.withValues(alpha: 0.04),
        _lavender.withValues(alpha: 0.42),
        _royalBlue.withValues(alpha: 0.22),
        _lavender.withValues(alpha: 0.18),
      ],
      rect: Offset.zero & size,
    );

    final Path centralFold = Path()
      ..moveTo(0.30 * w - a * 10, 0.35 * h)
      ..cubicTo(
        0.40 * w + b * 14,
        0.44 * h,
        0.55 * w - a * 16,
        0.45 * h,
        0.50 * w + b * 10,
        0.59 * h,
      )
      ..cubicTo(
        0.46 * w - a * 12,
        0.71 * h,
        0.62 * w + b * 16,
        0.69 * h,
        0.63 * w - a * 10,
        0.80 * h,
      )
      ..cubicTo(
        0.64 * w - a * 10,
        0.90 * h,
        0.77 * w + b * 12,
        0.86 * h,
        0.88 * w,
        1.08 * h,
      );

    _drawGradientStroke(
      canvas,
      centralFold,
      width: longest * 0.075,
      blur: longest * 0.040,
      colors: <Color>[
        _lavender.withValues(alpha: 0.02),
        _lavender.withValues(alpha: 0.36),
        _electricBlue.withValues(alpha: 0.18),
        _violet.withValues(alpha: 0.30),
      ],
      rect: Offset.zero & size,
    );

    _drawGradientStroke(
      canvas,
      centralFold,
      width: longest * 0.026,
      blur: longest * 0.015,
      colors: <Color>[
        _lavender.withValues(alpha: 0.18),
        _lavender.withValues(alpha: 0.46),
        _electricBlue.withValues(alpha: 0.16),
        _violet.withValues(alpha: 0.28),
      ],
      rect: Offset.zero & size,
    );
  }

  void _paintVignette(Canvas canvas, Rect bounds) {
    final Paint paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: <Color>[Color(0x00000000), Color(0x8A01020D)],
        stops: <double>[0.52, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);

    final Paint topShade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0x5C010116), Color(0x00010116)],
      ).createShader(bounds);
    canvas.drawRect(bounds, topShade);
  }

  void _drawSoftFill(
    Canvas canvas,
    Path path,
    Rect shaderRect,
    List<Color> colors,
    List<double> stops, {
    required double blur,
  }) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: stops,
      ).createShader(shaderRect)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

    canvas.drawPath(path, paint);
  }

  void _drawRoundedShadowStroke(
    Canvas canvas,
    Path path, {
    required double width,
    required double blur,
    required Color color,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

    canvas.drawPath(path, paint);
  }

  void _drawGradientStroke(
    Canvas canvas,
    Path path, {
    required double width,
    required double blur,
    required List<Color> colors,
    required Rect rect,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LiquidWavePainter oldDelegate) => false;
}
