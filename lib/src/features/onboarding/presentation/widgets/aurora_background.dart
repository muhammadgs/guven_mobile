import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen, slowly drifting "liquid aurora" backdrop.
///
/// A premium deep-navy field with large, soft blue / indigo / violet / lavender
/// glow blobs that drift, breathe and gently morph on a seamless loop. The bright
/// glows are composited with [BlendMode.screen] over the dark base, so where they
/// overlap they fold into brighter lavender ridges — the calm, Apple-like fluid
/// wallpaper look — without ever blowing out to harsh neon.
///
/// Everything is painted natively with a single [CustomPainter] driven by one
/// [AnimationController]: no images, video, Lottie, WebView, shaders or extra
/// packages, and no [BackdropFilter]. That keeps it cheap enough to sit behind
/// the splash / onboarding content on both Android and iOS.
///
/// Drop it at the bottom of a [Stack] (e.g. inside a `Positioned.fill`) and lay
/// your content on top; a built-in vignette settles the edges and keeps that
/// content readable.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// One slow master clock. Every motion frequency in [_AuroraPainter] is a
  /// whole number of cycles per loop, so the whole scene returns exactly to its
  /// start when the controller wraps — the loop is seamless.
  static const Duration _loop = Duration(seconds: 48);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _loop)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Isolate the forever-animating paint so it never marks siblings dirty.
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

/// Immutable description of one glowing blob in the aurora field.
///
/// All positions and sizes are fractions of the canvas, so the scene scales to
/// any phone size. Motion uses whole-number cycle counts to stay loop-safe.
class _Blob {
  const _Blob({
    required this.color,
    required this.center,
    required this.radius,
    required this.drift,
    required this.driftCycles,
    required this.phase,
    required this.breathe,
    required this.breatheCycles,
    required this.squash,
    required this.tilt,
  });

  /// Glow colour at the core; its alpha sets the glow strength. Fades to fully
  /// transparent at the rim.
  final Color color;

  /// Resting centre, in fractions of the canvas (0..1, 0..1).
  final Offset center;

  /// Core radius, as a fraction of the canvas' longest side.
  final double radius;

  /// Drift travel along an elliptical path, as a fraction of the canvas.
  final Offset drift;

  /// Whole-number drift laps per loop (keeps the loop seamless).
  final double driftCycles;

  /// Phase offset (radians) so blobs never move in lockstep.
  final double phase;

  /// Radius "breathing" amount, as a fraction of [radius].
  final double breathe;

  /// Whole-number breaths per loop.
  final double breatheCycles;

  /// Vertical squash (1 = circle, < 1 = wide ellipse) for an organic shape.
  final double squash;

  /// Ellipse tilt, in radians.
  final double tilt;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.animation) : super(repaint: animation);

  /// Loop progress, 0..1.
  final Animation<double> animation;

  // --- Palette -------------------------------------------------------------
  // Deep, almost-black navy base with a faint violet tint.
  static const Color _baseTop = Color(0xFF04030C);
  static const Color _baseBottom = Color(0xFF080A1E);
  // Glow colours carry their strength in the alpha channel (composited with
  // BlendMode.screen, so on the dark base the visible brightness ≈ colour×alpha).
  static const Color _electricBlue = Color(0xC22A66FF);
  static const Color _royalBlue = Color(0xB81C3AD8);
  static const Color _indigo = Color(0x9A2422A0);
  static const Color _violet = Color(0xAA6A34E6);
  static const Color _lavender = Color(0x8FB8A7FF);
  static const Color _violetWash = Color(0x55402AB0);

  /// The drifting glows, painted back-to-front. Roughly echoes the reference:
  /// electric blue weight upper-left, violet through the centre, deeper blues
  /// low, lavender highlights riding the folds — dark negative space elsewhere.
  static const List<_Blob> _blobs = <_Blob>[
    // Soft wide violet wash for overall cohesion.
    _Blob(
      color: _violetWash,
      center: Offset(0.50, 0.58),
      radius: 0.72,
      drift: Offset(0.04, 0.05),
      driftCycles: 1,
      phase: 0.6,
      breathe: 0.10,
      breatheCycles: 1,
      squash: 0.9,
      tilt: -0.35,
    ),
    // Electric-blue mass, upper-left.
    _Blob(
      color: _electricBlue,
      center: Offset(0.30, 0.30),
      radius: 0.58,
      drift: Offset(0.06, 0.05),
      driftCycles: 1,
      phase: 0.0,
      breathe: 0.13,
      breatheCycles: 2,
      squash: 0.82,
      tilt: -0.5,
    ),
    // Royal blue sweeping the lower-left.
    _Blob(
      color: _royalBlue,
      center: Offset(0.26, 0.78),
      radius: 0.55,
      drift: Offset(0.05, 0.06),
      driftCycles: 1,
      phase: 2.1,
      breathe: 0.14,
      breatheCycles: 1,
      squash: 0.85,
      tilt: 0.4,
    ),
    // Violet body through the centre-right.
    _Blob(
      color: _violet,
      center: Offset(0.70, 0.55),
      radius: 0.50,
      drift: Offset(0.06, 0.05),
      driftCycles: 2,
      phase: 1.2,
      breathe: 0.15,
      breatheCycles: 1,
      squash: 0.9,
      tilt: 0.6,
    ),
    // Deep indigo settling the lower-right.
    _Blob(
      color: _indigo,
      center: Offset(0.82, 0.84),
      radius: 0.46,
      drift: Offset(0.05, 0.05),
      driftCycles: 1,
      phase: 3.4,
      breathe: 0.12,
      breatheCycles: 2,
      squash: 0.88,
      tilt: -0.3,
    ),
    // Bright lavender highlight riding the central fold.
    _Blob(
      color: _lavender,
      center: Offset(0.44, 0.50),
      radius: 0.30,
      drift: Offset(0.07, 0.06),
      driftCycles: 2,
      phase: 1.9,
      breathe: 0.18,
      breatheCycles: 3,
      squash: 0.8,
      tilt: -0.8,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    _paintBase(canvas, bounds);

    final double t = animation.value;
    final double longest = math.max(size.width, size.height);
    for (final _Blob blob in _blobs) {
      _paintBlob(canvas, size, longest, blob, t);
    }

    _paintVignette(canvas, bounds);
  }

  /// Very dark navy fill so the glows always read against deep negative space.
  void _paintBase(Canvas canvas, Rect bounds) {
    const LinearGradient gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[_baseTop, _baseBottom],
    );
    canvas.drawRect(bounds, Paint()..shader = gradient.createShader(bounds));
  }

  /// Draws one drifting, breathing, squashed glow.
  void _paintBlob(
    Canvas canvas,
    Size size,
    double longest,
    _Blob blob,
    double t,
  ) {
    final double driftAngle = 2 * math.pi * blob.driftCycles * t + blob.phase;
    final double breath =
        math.sin(2 * math.pi * blob.breatheCycles * t + blob.phase);

    final double cx =
        blob.center.dx * size.width + blob.drift.dx * size.width * math.cos(driftAngle);
    final double cy =
        blob.center.dy * size.height + blob.drift.dy * size.height * math.sin(driftAngle);
    final double radius = blob.radius * longest * (1 + blob.breathe * breath);

    final Rect rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final Paint paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: <Color>[blob.color, blob.color.withAlpha(0)],
        stops: const <double>[0.0, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(blob.tilt);
    canvas.scale(1, blob.squash); // turn the circle into a soft ellipse
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  /// Gentle darkening of the corners — settles the edges and keeps foreground
  /// content readable.
  void _paintVignette(Canvas canvas, Rect bounds) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const <Color>[Color(0x00000000), Color(0x73020208)],
        stops: const <double>[0.55, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}
