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
  static const Duration _loop = Duration(seconds: 7);

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
    _rightFlowingWaves(canvas, size, t);
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
      ..cubicTo(.16 * w + a * 24, -.22 * h, .78 * w - b * 28, -.15 * h, 1.30 * w, -.08 * h)
      ..cubicTo(1.05 * w + b * 26, .10 * h, .94 * w - a * 34, .30 * h, .95 * w + c * 22, .47 * h)
      ..cubicTo(.76 * w + c * 28, .50 * h, .59 * w - a * 34, .47 * h, .43 * w + b * 26, .36 * h)
      ..cubicTo(.28 * w + a * 20, .25 * h, .13 * w - b * 32, .32 * h, -.34 * w, .18 * h)
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
      ..cubicTo(.27 * w + a * 24, .06 * h, .56 * w - b * 28, .10 * h, .73 * w + c * 20, .27 * h)
      ..cubicTo(.86 * w + b * 22, .40 * h, .72 * w - a * 24, .55 * h, .52 * w + c * 18, .51 * h)
      ..cubicTo(.30 * w - b * 24, .47 * h, .05 * w + a * 20, .37 * h, .06 * w, .15 * h)
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
      ..cubicTo(-.02 * w + a * 26, .25 * h, .22 * w - b * 30, .31 * h, .31 * w + c * 20, .45 * h)
      ..cubicTo(.39 * w + b * 32, .59 * h, .57 * w - a * 30, .59 * h, .46 * w + c * 22, .73 * h)
      ..cubicTo(.38 * w - b * 24, .85 * h, .58 * w + a * 28, .88 * h, .42 * w, 1.20 * h)
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
      ..moveTo(.42 * w + b * 20, .65 * h)
      ..cubicTo(.53 * w + a * 24, .76 * h, .63 * w - c * 22, .71 * h, .67 * w + b * 20, .82 * h)
      ..cubicTo(.74 * w + c * 26, .96 * h, .95 * w - a * 22, .88 * h, 1.28 * w, 1.02 * h)
      ..cubicTo(1.30 * w, 1.18 * h, 1.03 * w, 1.26 * h, .60 * w, 1.22 * h)
      ..cubicTo(.34 * w - b * 20, 1.12 * h, .31 * w + a * 24, .86 * h, .42 * w + b * 20, .65 * h)
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
      ..cubicTo(.18 * w + a * 22, .68 * h, .38 * w - b * 26, .72 * h, .45 * w + c * 18, .84 * h)
      ..cubicTo(.53 * w + b * 20, .96 * h, .39 * w - a * 20, 1.06 * h, .21 * w + b * 14, 1.04 * h)
      ..cubicTo(.03 * w - a * 16, 1.02 * h, -.06 * w, .88 * h, .03 * w, .76 * h)
      ..close();
    _fill(canvas, p, Rect.fromLTWH(-.04 * w, .68 * h, .58 * w, .42 * h), const <Color>[Color(0xFF07114B), _cobalt, _violet, Color(0xFF2B1B86)], const <double>[0, .34, .72, 1], 8);
  }

  void _shadowChannels(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + 1.70);
    final double b = math.sin(math.pi * 2 * t + 4.40);
    final Path center = Path()
      ..moveTo(-.10 * w, .22 * h)
      ..cubicTo(.14 * w + a * 28, .29 * h, .30 * w - b * 26, .34 * h, .36 * w + a * 20, .49 * h)
      ..cubicTo(.43 * w + b * 22, .66 * h, .61 * w - a * 26, .62 * h, .55 * w, .80 * h)
      ..cubicTo(.52 * w - b * 22, .94 * h, .43 * w, 1.03 * h, .34 * w, 1.16 * h);
    _stroke(canvas, center, longest * .115, longest * .045, _deepNavy.withValues(alpha: .48), false);

    final Path right = Path()
      ..moveTo(.92 * w + b * 20, -.14 * h)
      ..cubicTo(.84 * w + a * 18, .12 * h, .88 * w - b * 16, .32 * h, 1.24 * w, .48 * h);
    _stroke(canvas, right, longest * .110, longest * .055, _deepNavy.withValues(alpha: .28), false);
  }

  void _rightFlowingWaves(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    _movingRibbon(canvas, size, t, .00, .43 * h, longest * .155, <Color>[_royalBlue.withValues(alpha: .00), _electricBlue.withValues(alpha: .34), _violet.withValues(alpha: .30), _lavender.withValues(alpha: .20)]);
    _movingRibbon(canvas, size, t, .33, .54 * h, longest * .125, <Color>[_violet.withValues(alpha: .00), _royalBlue.withValues(alpha: .32), _lavender.withValues(alpha: .26), _cobalt.withValues(alpha: .16)]);
    _movingRibbon(canvas, size, t, .66, .66 * h, longest * .145, <Color>[_cobalt.withValues(alpha: .00), _electricBlue.withValues(alpha: .30), _violet.withValues(alpha: .28), _lavender.withValues(alpha: .18)]);
  }

  void _movingRibbon(Canvas canvas, Size size, double t, double phase, double y, double width, List<Color> colors) {
    final double w = size.width, h = size.height;
    final double period = w * 1.35;
    final double dx = ((t + phase) % 1.0) * period;
    final double wave = math.sin(math.pi * 2 * (t + phase));
    final Path p = Path()
      ..moveTo(-.40 * w, y)
      ..cubicTo(-.10 * w, y - .13 * h + wave * 20, .22 * w, y + .10 * h - wave * 16, .55 * w, y - .02 * h)
      ..cubicTo(.88 * w, y - .13 * h - wave * 22, 1.15 * w, y + .06 * h + wave * 18, 1.48 * w, y - .04 * h);
    for (final double shift in <double>[dx - period, dx, dx + period]) {
      canvas.save();
      canvas.translate(shift - period * .55, 0);
      _gradientStroke(canvas, p, width, 30, colors, Offset.zero & size);
      canvas.restore();
    }
  }

  void _lightFolds(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + .95);
    final double b = math.sin(math.pi * 2 * t + 2.55);
    final double c = math.sin(math.pi * 4 * t + .55);
    final Path topRim = Path()
      ..moveTo(-.14 * w, .24 * h)
      ..cubicTo(.12 * w - b * 26, .31 * h, .28 * w + a * 20, .24 * h, .43 * w + b * 24, .36 * h)
      ..cubicTo(.58 * w - a * 28, .48 * h, .76 * w + c * 24, .53 * h, 1.13 * w, .47 * h);
    _gradientStroke(canvas, topRim, longest * .085, longest * .038, <Color>[_lavender.withValues(alpha: .04), _lavender.withValues(alpha: .42), _royalBlue.withValues(alpha: .22), _lavender.withValues(alpha: .18)], Offset.zero & size);

    final Path fold = Path()
      ..moveTo(.30 * w - a * 20, .35 * h)
      ..cubicTo(.40 * w + b * 24, .44 * h, .55 * w - a * 26, .45 * h, .50 * w + b * 20, .59 * h)
      ..cubicTo(.46 * w - a * 22, .71 * h, .62 * w + b * 26, .69 * h, .63 * w - a * 20, .80 * h)
      ..cubicTo(.64 * w - a * 20, .90 * h, .77 * w + b * 22, .86 * h, .88 * w, 1.08 * h);
    _gradientStroke(canvas, fold, longest * .075, longest * .040, <Color>[_lavender.withValues(alpha: .02), _lavender.withValues(alpha: .36), _electricBlue.withValues(alpha: .18), _violet.withValues(alpha: .30)], Offset.zero & size);
    _gradientStroke(canvas, fold, longest * .026, longest * .015, <Color>[_lavender.withValues(alpha: .18), _lavender.withValues(alpha: .46), _electricBlue.withValues(alpha: .16), _violet.withValues(alpha: .28)], Offset.zero & size);
  }

  void _extraFold(Canvas canvas, Size size, double t) {
    final double w = size.width, h = size.height, longest = math.max(size.width, size.height);
    final double a = math.sin(math.pi * 2 * t + 1.40);
    final double b = math.sin(math.pi * 2 * t + 3.00);
    final Path p = Path()
      ..moveTo(-.04 * w, .62 * h)
      ..cubicTo(.15 * w + a * 22, .55 * h, .29 * w - b * 24, .58 * h, .38 * w + a * 18, .70 * h)
      ..cubicTo(.46 * w + b * 20, .82 * h, .35 * w - a * 20, .92 * h, .24 * w, 1.05 * h);
    _gradientStroke(canvas, p, longest * .060, longest * .030, <Color>[_lavender.withValues(alpha: .06), _lavender.withValues(alpha: .34), _electricBlue.withValues(alpha: .18), _violet.withValues(alpha: .24)], Offset.zero & size);
  }

  void _vignette(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: .98,
          colors: <Color>[Color(0x00000000), Color(0x7301020D)],
          stops: <double>[.54, 1],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x52010116), Color(0x00010116)],
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
