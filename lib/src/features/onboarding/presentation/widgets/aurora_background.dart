import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Full-screen animated liquid-wave backdrop for the onboarding flow.
///
/// The design follows the supplied reference image: deep navy negative space,
/// large royal-blue / violet flowing surfaces and soft lavender light along the
/// wave edges. It is intentionally built with Flutter's native [CustomPainter]
/// and one slow [AnimationController], so the four onboarding pages share one
/// continuous background without adding packages or a WebView.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// Calm but visible motion. The loop is long enough to feel premium, while the
  /// wave edges still drift clearly when the user watches the background.
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
  static const Color _deepPocket = Color(0xFF01022A);
  static const Color _royalBlue = Color(0xFF1557FF);
  static const Color _cobalt = Color(0xFF1735D8);
  static const Color _electricBlue = Color(0xFF2F73FF);
  static const Color _violet = Color(0xFF6C36F4);
  static const Color _lavender = Color(0xFFD5C8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double t = animation.value;

    _paintBase(canvas, bounds);
    _paintTopLiquidSheet(canvas, size, t);
    _paintLeftLiquidSheet(canvas, size, t);
    _paintBottomRightSheet(canvas, size, t);
    _paintCentralLightFold(canvas, size, t);
    _paintDeepPockets(canvas, size, t);
    _paintSoftVignette(canvas, bounds);
  }

  void _paintBase(Canvas canvas, Rect bounds) {
    const LinearGradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[_navyTop, _navyBottom],
    );

    canvas.drawRect(bounds, Paint()..shader = gradient.createShader(bounds));
  }

  /// Large top wave with the broad blue surface and lavender lower rim.
  void _paintTopLiquidSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t);
    final double b = math.sin(math.pi * 2 * t + 1.4);
    final double c = math.sin(math.pi * 4 * t + 0.8);

    final Path sheet = Path()
      ..moveTo(-0.24 * w, -0.10 * h)
      ..lineTo(1.16 * w, -0.10 * h)
      ..cubicTo(
        1.03 * w + b * 18,
        0.10 * h,
        0.91 * w + a * 24,
        0.34 * h,
        0.91 * w + b * 18,
        0.48 * h,
      )
      ..cubicTo(
        0.72 * w + c * 18,
        0.52 * h,
        0.55 * w - a * 20,
        0.45 * h,
        0.41 * w + b * 16,
        0.34 * h,
      )
      ..cubicTo(
        0.27 * w + a * 12,
        0.23 * h,
        0.15 * w - b * 24,
        0.31 * h,
        -0.14 * w,
        0.20 * h,
      )
      ..close();

    final Rect shaderRect = Rect.fromLTWH(0, -0.08 * h, w, 0.58 * h);
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF060A55),
          _royalBlue,
          _cobalt,
          Color(0xFF090B43),
        ],
        stops: <double>[0.0, 0.36, 0.70, 1.0],
      ).createShader(shaderRect);
    canvas.drawPath(sheet, fill);

    final Path rim = Path()
      ..moveTo(-0.05 * w, 0.22 * h)
      ..cubicTo(
        0.16 * w - b * 12,
        0.30 * h,
        0.27 * w + a * 10,
        0.22 * h,
        0.41 * w + b * 16,
        0.34 * h,
      )
      ..cubicTo(
        0.55 * w - a * 20,
        0.45 * h,
        0.72 * w + c * 18,
        0.52 * h,
        0.96 * w + b * 8,
        0.48 * h,
      );

    _drawGlowStroke(
      canvas,
      rim,
      width: longest * 0.040,
      blur: longest * 0.020,
      color: _lavender.withValues(alpha: 0.42),
    );
    _drawGlowStroke(
      canvas,
      rim,
      width: longest * 0.014,
      blur: longest * 0.006,
      color: _lavender.withValues(alpha: 0.62),
    );
  }

  /// Broad lower-left surface from the reference image.
  void _paintLeftLiquidSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 2.2);
    final double b = math.sin(math.pi * 2 * t + 3.7);
    final double c = math.sin(math.pi * 4 * t + 1.6);

    final Path sheet = Path()
      ..moveTo(-0.20 * w, 0.24 * h)
      ..cubicTo(
        0.06 * w + a * 18,
        0.29 * h,
        0.22 * w - b * 18,
        0.30 * h,
        0.32 * w + c * 10,
        0.44 * h,
      )
      ..cubicTo(
        0.43 * w + b * 18,
        0.59 * h,
        0.62 * w - a * 24,
        0.58 * h,
        0.48 * w + c * 14,
        0.73 * h,
      )
      ..cubicTo(
        0.37 * w - b * 14,
        0.85 * h,
        0.63 * w + a * 20,
        0.83 * h,
        0.45 * w,
        1.10 * h,
      )
      ..lineTo(-0.20 * w, 1.10 * h)
      ..close();

    final Rect shaderRect = Rect.fromLTWH(-0.12 * w, 0.25 * h, 0.72 * w, 0.80 * h);
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF06104C),
          _electricBlue,
          _cobalt,
          _violet,
          Color(0xFF040533),
        ],
        stops: <double>[0.0, 0.27, 0.56, 0.78, 1.0],
      ).createShader(shaderRect);
    canvas.drawPath(sheet, fill);

    final Path leftRim = Path()
      ..moveTo(-0.08 * w, 0.30 * h)
      ..cubicTo(
        0.12 * w + a * 18,
        0.36 * h,
        0.23 * w - b * 18,
        0.31 * h,
        0.32 * w + c * 10,
        0.44 * h,
      )
      ..cubicTo(
        0.43 * w + b * 18,
        0.59 * h,
        0.62 * w - a * 24,
        0.58 * h,
        0.48 * w + c * 14,
        0.73 * h,
      );

    _drawGlowStroke(
      canvas,
      leftRim,
      width: longest * 0.050,
      blur: longest * 0.030,
      color: _lavender.withValues(alpha: 0.34),
    );
  }

  /// Violet-blue sheet flowing through the lower-right corner.
  void _paintBottomRightSheet(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 4.1);
    final double b = math.sin(math.pi * 2 * t + 5.4);
    final double c = math.sin(math.pi * 4 * t + 2.8);

    final Path sheet = Path()
      ..moveTo(0.44 * w + b * 10, 0.66 * h)
      ..cubicTo(
        0.55 * w + a * 18,
        0.77 * h,
        0.62 * w - c * 14,
        0.70 * h,
        0.66 * w + b * 12,
        0.81 * h,
      )
      ..cubicTo(
        0.73 * w + c * 18,
        0.94 * h,
        0.90 * w - a * 10,
        0.86 * h,
        1.18 * w,
        0.99 * h,
      )
      ..lineTo(1.18 * w, 1.16 * h)
      ..lineTo(0.36 * w, 1.16 * h)
      ..cubicTo(
        0.34 * w - b * 8,
        0.98 * h,
        0.52 * w + a * 14,
        0.94 * h,
        0.44 * w + b * 10,
        0.66 * h,
      )
      ..close();

    final Rect shaderRect = Rect.fromLTWH(0.34 * w, 0.62 * h, 0.82 * w, 0.52 * h);
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF061157),
          _royalBlue,
          _violet,
          Color(0xFF4620B8),
        ],
        stops: <double>[0.0, 0.38, 0.76, 1.0],
      ).createShader(shaderRect);
    canvas.drawPath(sheet, fill);

    final Path rim = Path()
      ..moveTo(0.43 * w + b * 10, 0.66 * h)
      ..cubicTo(
        0.55 * w + a * 18,
        0.77 * h,
        0.62 * w - c * 14,
        0.70 * h,
        0.66 * w + b * 12,
        0.81 * h,
      )
      ..cubicTo(
        0.73 * w + c * 18,
        0.94 * h,
        0.90 * w - a * 10,
        0.86 * h,
        1.08 * w,
        0.95 * h,
      );

    _drawGlowStroke(
      canvas,
      rim,
      width: longest * 0.045,
      blur: longest * 0.026,
      color: _lavender.withValues(alpha: 0.30),
    );
  }

  /// The S-shaped illuminated fold that makes the background look like liquid
  /// sheets sliding over each other instead of static blobs.
  void _paintCentralLightFold(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 0.9);
    final double b = math.sin(math.pi * 2 * t + 2.6);

    final Path fold = Path()
      ..moveTo(0.29 * w - a * 10, 0.34 * h)
      ..cubicTo(
        0.40 * w + b * 16,
        0.44 * h,
        0.56 * w - a * 18,
        0.44 * h,
        0.50 * w + b * 12,
        0.58 * h,
      )
      ..cubicTo(
        0.45 * w - a * 14,
        0.70 * h,
        0.62 * w + b * 18,
        0.68 * h,
        0.62 * w - a * 12,
        0.79 * h,
      )
      ..cubicTo(
        0.62 * w - a * 12,
        0.88 * h,
        0.76 * w + b * 14,
        0.83 * h,
        0.84 * w,
        1.03 * h,
      );

    _drawGradientStroke(
      canvas,
      fold,
      width: longest * 0.120,
      blur: longest * 0.052,
      colors: <Color>[
        _lavender.withValues(alpha: 0.00),
        _lavender.withValues(alpha: 0.30),
        _royalBlue.withValues(alpha: 0.18),
        _violet.withValues(alpha: 0.24),
      ],
      rect: Offset.zero & size,
    );

    _drawGradientStroke(
      canvas,
      fold,
      width: longest * 0.036,
      blur: longest * 0.013,
      colors: <Color>[
        _lavender.withValues(alpha: 0.20),
        _lavender.withValues(alpha: 0.58),
        _electricBlue.withValues(alpha: 0.22),
        _violet.withValues(alpha: 0.36),
      ],
      rect: Offset.zero & size,
    );
  }

  /// Dark curved cavities from the reference image. They make the blue surfaces
  /// feel layered and give the later blur pass enough contrast to work with.
  void _paintDeepPockets(Canvas canvas, Size size, double t) {
    final double w = size.width;
    final double h = size.height;
    final double longest = math.max(w, h);
    final double a = math.sin(math.pi * 2 * t + 1.8);
    final double b = math.sin(math.pi * 2 * t + 4.8);

    final Paint pocketPaint = Paint()
      ..color = _deepPocket.withValues(alpha: 0.74)
      ..maskFilter = ui.MaskFilter.blur(
        ui.BlurStyle.normal,
        longest * 0.034,
      );

    final Path rightPocket = Path()
      ..moveTo(0.86 * w + a * 14, -0.04 * h)
      ..cubicTo(
        0.77 * w + b * 12,
        0.13 * h,
        0.77 * w - a * 10,
        0.30 * h,
        0.92 * w + b * 16,
        0.40 * h,
      )
      ..lineTo(1.22 * w, 0.42 * h)
      ..lineTo(1.22 * w, -0.04 * h)
      ..close();
    canvas.drawPath(rightPocket, pocketPaint);

    final Path middlePocket = Path()
      ..moveTo(0.35 * w - b * 10, 0.39 * h)
      ..cubicTo(
        0.46 * w + a * 16,
        0.48 * h,
        0.55 * w - b * 14,
        0.46 * h,
        0.50 * w + a * 12,
        0.58 * h,
      )
      ..cubicTo(
        0.43 * w - b * 16,
        0.70 * h,
        0.62 * w,
        0.68 * h,
        0.49 * w,
        0.79 * h,
      )
      ..cubicTo(
        0.41 * w,
        0.70 * h,
        0.25 * w,
        0.58 * h,
        0.35 * w - b * 10,
        0.39 * h,
      )
      ..close();
    canvas.drawPath(middlePocket, pocketPaint);

    final Path bottomPocket = Path()
      ..moveTo(-0.12 * w, 0.82 * h)
      ..cubicTo(
        0.15 * w + a * 10,
        0.77 * h,
        0.44 * w - b * 18,
        0.80 * h,
        0.48 * w + a * 16,
        0.90 * h,
      )
      ..cubicTo(
        0.53 * w + b * 14,
        1.01 * h,
        0.35 * w,
        1.08 * h,
        0.36 * w,
        1.18 * h,
      )
      ..lineTo(-0.12 * w, 1.18 * h)
      ..close();
    canvas.drawPath(bottomPocket, pocketPaint);
  }

  void _paintSoftVignette(Canvas canvas, Rect bounds) {
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
        colors: <Color>[Color(0x66010116), Color(0x00010116)],
      ).createShader(bounds);
    canvas.drawRect(bounds, topShade);
  }

  void _drawGlowStroke(
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
      ..blendMode = BlendMode.screen
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
