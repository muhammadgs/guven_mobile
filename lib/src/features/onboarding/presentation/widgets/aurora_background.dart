import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _loop = Duration(seconds: 12);

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
    _base(canvas, bounds);
    _top(canvas, size, t);
    _upperMid(canvas, size, t);
    _left(canvas, size, t);
    _bottom(canvas, size, t);
    _lowerAccent(canvas, size, t);
    _shadowChannels(canvas, size, t);
    _lightFolds(canvas, size, t);
    _extraFold(canvas, size, t);
    _vignette(canvas, bounds);
  }

  void _base(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_navyTop, _navyBottom],
        ).createShader(bounds),
    );
  }

  void _top(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height;
    final double a = math.sin(math.pi * 2 * t);
    final double b = math.sin(math.pi * 2 * t + 1.35);
    final double c = math.sin(math.pi * 4 * t + .75);
    final Path p = Path()
      ..moveTo(-.34 * w, -.20 * h)
      ..cubicTo(.16 * w + a * 22, -.22 * h, .78 * w - b * 24, -.15 * h, 1.30 * w, -.08 * h)
      ..cubicTo(1.05 * w + b * 22, .10 * h, .94 * w - a * 30, .30 * h, .95 * w + c * 18, .47 * h)
      ..cubicTo(.76 * w + c * 24, .50 * h, .59 * w - a * 30, .47 * h, .43 * w + b * 24, .36 * h)
      ..cubicTo(.28 * w + a * 18, .25 * h, .13 * w - b * 28, .32 * h, -.34 * w, .18 * h)
      ..cubicTo(-.42 * w, .03 * h, -.42 * w, -.13 * h, -.34 * w, -.20 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(-.05 * w, -.12 * h, 1.12 * w, .68 * h), const <Color>[Color(0xFF050844), _royalBlue, _cobalt, Color(0xFF090B40)], const <double>[0, .36, .72, 1], 5);
  }

  void _upperMid(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height;
    final double a = math.sin(math.pi * 2 * t + .60);
    final double b = math.sin(math.pi * 2 * t + 2.10);
    final double c = math.sin(math.pi * 4 * t + 1.20);
    final Path p = Path()
      ..moveTo(.06 * w, .15 * h)
      ..cubicTo(.27 * w + a * 22, .06 * h, .56 * w - b * 26, .10 * h, .73 * w + c * 18, .27 * h)
      ..cubicTo(.86 * w + b * 20, .40 * h, .72 * w - a * 22, .55 * h, .52 * w + c * 16, .51 * h)
      ..cubicTo(.30 * w - b * 22, .47 * h, .05 * w + a * 18, .37 * h, .06 * w, .15 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(.02 * w, .06 * h, .82 * w, .52 * h), const <Color>[Color(0xFF071054), _royalBlue, _electricBlue, _violet], const <double>[0, .34, .66, 1], 8);
  }

  void _left(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height;
    final double a = math.sin(math.pi * 2 * t + 2.15);
    final double b = math.sin(math.pi * 2 * t + 3.55);
    final double c = math.sin(math.pi * 4 * t + 1.55);
    final Path p = Path()
      ..moveTo(-.34 * w, .20 * h)
      ..cubicTo(-.02 * w + a * 24, .25 * h, .22 * w - b * 26, .31 * h, .31 * w + c * 18, .45 * h)
      ..cubicTo(.39 * w + b * 28, .59 * h, .57 * w - a * 26, .59 * h, .46 * w + c * 20, .73 * h)
      ..cubicTo(.38 * w - b * 22, .85 * h, .58 * w + a * 24, .88 * h, .42 * w, 1.20 * h)
      ..cubicTo(.14 * w, 1.26 * h, -.25 * w, 1.16 * h, -.34 * w, .92 * h)
      ..cubicTo(-.42 * w, .68 * h, -.43 * w, .39 * h, -.34 * w, .20 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(-.12 * w, .22 * h, .82 * w, .98 * h), const <Color>[Color(0xFF06104C), _electricBlue, _cobalt, _violet, Color(0xFF04042D)], const <double>[0, .24, .54, .80, 1], 7);
  }

  void _bottom(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height;
    final double a = math.sin(math.pi * 2 * t + 4.10);
    final double b = math.sin(math.pi * 2 * t + 5.35);
    final double c = math.sin(math.pi * 4 * t + 2.70);
    final Path p = Path()
      ..moveTo(.42 * w + b * 18, .65 * h)
      ..cubicTo(.53 * w + a * 22, .76 * h, .63 * w - c * 20, .71 * h, .67 * w + b * 18, .82 * h)
      ..cubicTo(.74 * w + c * 24, .96 * h, .95 * w - a * 20, .88 * h, 1.28 * w, 1.02 * h)
      ..cubicTo(1.30 * w, 1.18 * h, 1.03 * w, 1.26 * h, .60 * w, 1.22 * h)
      ..cubicTo(.34 * w - b * 18, 1.12 * h, .31 * w + a * 22, .86 * h, .42 * w + b * 18, .65 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(.30 * w, .60 * h, .98 * w, .62 * h), const <Color>[Color(0xFF061157), _royalBlue, _violet, Color(0xFF4620B8)], const <double>[0, .35, .76, 1], 7);
  }

  void _lowerAccent(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height;
    final double a = math.sin(math.pi * 2 * t + 3.20);
    final double b = math.sin(math.pi * 2 * t + 4.70);
    final double c = math.sin(math.pi * 4 * t + 2.40);
    final Path p = Path()
      ..moveTo(.03 * w, .76 * h)
      ..cubicTo(.18 * w + a * 20, .68 * h, .38 * w - b * 24, .72 * h, .45 * w + c * 16, .84 * h)
      ..cubicTo(.53 * w + b * 18, .96 * h, .39 * w - a * 18, 1.06 * h, .21 * w + b * 12, 1.04 * h)
      ..cubicTo(.03 * w - a * 14, 1.02 * h, -.06 * w, .88 * h, .03 * w, .76 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(-.04 * w, .68 * h, .58 * w, .42 * h), const <Color>[Color(0xFF07114B), _cobalt, _violet, Color(0xFF2B1B86)], const <double>[0, .34, .72, 1], 8);
  }

  void _shadowChannels(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + 1.70);
    final double b = math.sin(math.pi * 2 * t + 4.40);
    final Path center = Path()
      ..moveTo(-.10 * w, .22 * h)
      ..cubicTo(.14 * w + a * 26, .29 * h, .30 * w - b * 24, .34 * h, .36 * w + a * 18, .49 * h)
      ..cubicTo(.43 * w + b * 20, .66 * h, .61 * w - a * 24, .62 * h, .55 * w, .80 * h)
      ..cubicTo(.52 * w - b * 20, .94 * h, .43 * w, 1.03 * h, .34 * w, 1.16 * h);
    _stroke(canvas, center, longest * .125, longest * .045, _deepNavy.withValues(alpha: .58), false);

    final Path right = Path()
      ..moveTo(.90 * w + b * 18, -.12 * h)
      ..cubicTo(.78 * w + a * 20, .12 * h, .79 * w - b * 18, .30 * h, 1.16 * w, .44 * h);
    _stroke(canvas, right, longest * .180, longest * .060, _deepNavy.withValues(alpha: .52), false);
  }

  void _lightFolds(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + .95);
    final double b = math.sin(math.pi * 2 * t + 2.55);
    final double c = math.sin(math.pi * 4 * t + .55);
    final Path topRim = Path()
      ..moveTo(-.14 * w, .24 * h)
      ..cubicTo(.12 * w - b * 24, .31 * h, .28 * w + a * 18, .24 * h, .43 * w + b * 22, .36 * h)
      ..cubicTo(.58 * w - a * 26, .48 * h, .76 * w + c * 22, .53 * h, 1.13 * w, .47 * h);
    _gradientStroke(canvas, topRim, longest * .085, longest * .038, <Color>[_lavender.withValues(alpha: .04), _lavender.withValues(alpha: .42), _royalBlue.withValues(alpha: .22), _lavender.withValues(alpha: .18)], Offset.zero & size);

    final Path fold = Path()
      ..moveTo(.30 * w - a * 18, .35 * h)
      ..cubicTo(.40 * w + b * 22, .44 * h, .55 * w - a * 24, .45 * h, .50 * w + b * 18, .59 * h)
      ..cubicTo(.46 * w - a * 20, .71 * h, .62 * w + b * 24, .69 * h, .63 * w - a * 18, .80 * h)
      ..cubicTo(.64 * w - a * 18, .90 * h, .77 * w + b * 20, .86 * h, .88 * w, 1.08 * h);
    _gradientStroke(canvas, fold, longest * .075, longest * .040, <Color>[_lavender.withValues(alpha: .02), _lavender.withValues(alpha: .36), _electricBlue.withValues(alpha: .18), _violet.withValues(alpha: .30)], Offset.zero & size);
    _gradientStroke(canvas, fold, longest * .026, longest * .015, <Color>[_lavender.withValues(alpha: .18), _lavender.withValues(alpha: .46), _electricBlue.withValues(alpha: .16), _violet.withValues(alpha: .28)], Offset.zero & size);
  }

  void _extraFold(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + 1.40);
    final double b = math.sin(math.pi * 2 * t + 3.00);
    final Path p = Path()
      ..moveTo(-.04 * w, .62 * h)
      ..cubicTo(.15 * w + a * 20, .55 * h, .29 * w - b * 22, .58 * h, .38 * w + a * 16, .70 * h)
      ..cubicTo(.46 * w + b * 18, .82 * h, .35 * w - a * 18, .92 * h, .24 * w, 1.05 * h);
    _gradientStroke(canvas, p, longest * .060, longest * .030, <Color>[_lavender.withValues(alpha: .06), _lavender.withValues(alpha: .34), _electricBlue.withValues(alpha: .18), _violet.withValues(alpha: .24)], Offset.zero & size);
  }

  void _vignette(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: .98,
          colors: <Color>[Color(0x00000000), Color(0x8A01020D)],
          stops: <double>[.52, 1],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x5C010116), Color(0x00010116)],
        ).createShader(bounds),
    );
  }

  void _fill(Canvas canvas, Path path, Rect rect, List<Color> colors, List<double> stops, double blur) {
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors, stops: stops).createShader(rect)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
    );
  }

  void _stroke(Canvas canvas, Path path, double width, double blur, Color color, bool screen) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur);
    if (screen) paint.blendMode = BlendMode.screen;
    canvas.drawPath(path, paint);
  }

  void _gradientStroke(Canvas canvas, Path path, double width, double blur, List<Color> colors, Rect rect) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_LiquidWavePainter oldDelegate) => false;
}
