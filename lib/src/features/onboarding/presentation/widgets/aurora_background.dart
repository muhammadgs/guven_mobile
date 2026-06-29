import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen animated liquid wallpaper.
/// Dark, rich, and saturated blue/purple tones with a perceptible slow wave.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  // Animasyon hızını 48'den 32'ye düşürdük. Yavaş ama daha "bilinir" seviyede bir akış sağlar.
  static const Duration _loop = Duration(seconds: 32);

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
        painter: _AuroraPainter(_controller),
        size: Size.infinite,
        isComplex: true,
        willChange: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this._animation) : super(repaint: _animation);

  final Animation<double> _animation;

  static const double _tau = 2 * math.pi;

  // --- Karanlık ve Doygun Renk Paleti (Resimdeki Tonlar) ---
  static const Color _bgTop = Color(0xFF02040F); // Çok koyu gece mavisi
  static const Color _bgBottom = Color(0xFF000000); // Saf siyah/lacivert zemin

  static const Color _vividBlue = Color(0xFF2041F5); // Elektrik mavisi
  static const Color _deepBlue = Color(0xFF0D1B6E); // Derin lacivert
  static const Color _darkNavy = Color(0xFF050B24); // Gölgeli koyu lacivert
  static const Color _neonPurple = Color(0xFF6C33E8); // Parlak mor
  static const Color _richPurple = Color(0xFF2A106B); // Koyu mor

  // Parlama alanları (Beyaz veya pastel yerine kendi renklerinin parlak/transparan halleri)
  static const Color _bluePool = Color(0x662041F5);
  static const Color _bluePool0 = Color(0x002041F5);
  static const Color _violPool = Color(0x556C33E8);
  static const Color _violPool0 = Color(0x006C33E8);
  static const Color _centerGlow = Color(0x774F26B8); 
  static const Color _centerGlow0 = Color(0x004F26B8);

  // Dalga uçlarındaki keskin vuruşlar (Vivid/Doygun)
  static const Color _purpleRim = Color(0xAA8A52FF);
  static const Color _blueRim = Color(0x994D70FF);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double t = _animation.value;
    final double w = size.width;
    final double h = size.height;

    _paintBase(canvas, bounds);

    // Arkadaki derinlik yaratan renk havuzları
    _paintGlow(
      canvas,
      Offset(w * (0.30 + 0.05 * _sin(t)), h * (0.42 + 0.04 * _cos(t, 0.5))),
      math.max(w, h) * 0.62,
      _bluePool,
      _bluePool0,
    );
    _paintGlow(
      canvas,
      Offset(w * (0.84 + 0.04 * _cos(t, 1.5)), h * (0.16 + 0.05 * _sin(t, 2.0))),
      math.max(w, h) * 0.50,
      _violPool,
      _violPool0,
    );

    // 3 Ana Dalga Kütlesi (Soft renkler çıkarıldı, dark/vivid geçişler eklendi)
    _paintLiquidBand(
      canvas,
      bounds,
      _buildLeftMass(size, t),
      const <Color>[_vividBlue, _deepBlue, _darkNavy],
      const Alignment(-0.7, -0.6),
      const Alignment(0.6, 1.0),
      25,
    );
    _paintLiquidBand(
      canvas,
      bounds,
      _buildUpperRight(size, t),
      const <Color>[_neonPurple, _richPurple, _darkNavy],
      const Alignment(0.9, -0.7),
      const Alignment(-0.2, 0.9),
      28,
    );
    _paintLiquidBand(
      canvas,
      bounds,
      _buildBottomBlob(size, t),
      const <Color>[_richPurple, _vividBlue, _deepBlue],
      const Alignment(0.0, 1.0),
      const Alignment(0.3, -0.2),
      25,
    );

    // Dalga kenarlarındaki ince, doygun mor ve mavi parlamalar
    _paintHighlight(canvas, _buildLeftMass(size, t), _blueRim, 15);
    _paintHighlight(canvas, _buildBottomBlob(size, t), _purpleRim, 14);
    _paintHighlight(canvas, _buildUpperRight(size, t), _blueRim, 18);

    // Merkezdeki kesişim noktasındaki koyu mor parlama
    _paintGlow(
      canvas,
      Offset(w * (0.57 + 0.04 * _sin(t, 1.0)), h * (0.50 + 0.05 * _cos(t))),
      math.max(w, h) * 0.35,
      _centerGlow,
      _centerGlow0,
    );

    _paintVignette(canvas, bounds);
  }

  // --- Layers ---------------------------------------------------------------

  void _paintBase(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_bgTop, _bgBottom],
        ).createShader(bounds),
    );
  }

  void _paintGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color hot,
    Color cold,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..isAntiAlias = true
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: <Color>[hot, cold],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _paintLiquidBand(
    Canvas canvas,
    Rect bounds,
    Path path,
    List<Color> colors,
    Alignment begin,
    Alignment end,
    double blur,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(bounds),
    );
  }

  void _paintHighlight(Canvas canvas, Path path, Color color, double sigma) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = sigma * 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
        ..blendMode = BlendMode.screen,
    );
  }

  void _paintVignette(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..isAntiAlias = true
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: <Color>[Color(0x00000000), Color(0xCC000005)],
          stops: <double>[0.55, 1.0],
        ).createShader(bounds),
    );
  }

  // --- Liquid band paths (Kıvrımlar orijinal haliyle mükemmel olduğu için korundu) ---

  Path _buildLeftMass(Size size, double t) {
    final double w = size.width, h = size.height;
    final double a1 = _sin(t), a2 = _sin(t, 1.1, 2);
    final double b1 = _cos(t, 0.7), b2 = _cos(t, 2.0, 2);

    return Path()
      ..moveTo(-0.6 * w, -0.4 * h)
      ..cubicTo(
        -0.10 * w, -0.34 * h,
        0.24 * w + 0.03 * w * a2, -0.16 * h,
        0.46 * w + 0.03 * w * b1, 0.10 * h,
      )
      ..cubicTo(
        0.66 * w + 0.035 * w * a1, 0.30 * h + 0.03 * h * b2,
        0.70 * w + 0.030 * w * b1, 0.54 * h + 0.03 * h * a2,
        0.50 * w + 0.030 * w * a2, 0.72 * h + 0.025 * h * b1,
      )
      ..cubicTo(
        0.36 * w + 0.03 * w * b2, 0.86 * h,
        0.30 * w, 1.12 * h,
        0.08 * w, 1.40 * h,
      )
      ..lineTo(-0.6 * w, 1.40 * h)
      ..close();
  }

  Path _buildUpperRight(Size size, double t) {
    final double w = size.width, h = size.height;
    final double a1 = _sin(t, 1.8), a2 = _sin(t, 0.5, 2);
    final double b1 = _cos(t, 2.1), b2 = _cos(t, 0.9, 2);

    return Path()
      ..moveTo(1.4 * w, -0.4 * h)
      ..cubicTo(
        1.00 * w, -0.30 * h,
        0.78 * w + 0.03 * w * a1, -0.10 * h,
        0.66 * w + 0.03 * w * b2, 0.18 * h,
      )
      ..cubicTo(
        0.60 * w + 0.03 * w * b1, 0.32 * h,
        0.66 * w + 0.03 * w * a2, 0.46 * h,
        0.84 * w + 0.03 * w * a1, 0.52 * h,
      )
      ..cubicTo(
        1.04 * w, 0.58 * h,
        1.20 * w, 0.28 * h,
        1.40 * w, 0.0 * h,
      )
      ..lineTo(1.4 * w, -0.4 * h)
      ..close();
  }

  Path _buildBottomBlob(Size size, double t) {
    final double w = size.width, h = size.height;
    final double a1 = _sin(t, 3.9), a2 = _sin(t, 1.3, 2);
    final double b1 = _cos(t, 1.0), b2 = _cos(t, 2.3, 2);

    return Path()
      ..moveTo(-0.4 * w, 1.4 * h)
      ..cubicTo(
        0.0 * w, 1.06 * h,
        0.18 * w + 0.03 * w * a1, 0.86 * h,
        0.40 * w + 0.03 * w * b2, 0.80 * h,
      )
      ..cubicTo(
        0.55 * w + 0.03 * w * a2, 0.74 * h,
        0.60 * w + 0.03 * w * b1, 0.56 * h,
        0.78 * w + 0.03 * w * a1, 0.66 * h,
      )
      ..cubicTo(
        0.92 * w, 0.74 * h,
        1.12 * w, 0.92 * h,
        1.4 * w, 1.10 * h,
      )
      ..lineTo(1.4 * w, 1.4 * h)
      ..close();
  }

  double _sin(double t, [double phase = 0, int n = 1]) =>
      math.sin(_tau * n * t + phase);

  double _cos(double t, [double phase = 0, int n = 1]) =>
      math.cos(_tau * n * t + phase);

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}