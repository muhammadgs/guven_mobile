/// A push in which a single pane of glass *is* both screens.
///
/// The surface the user taps (a pill button) and the surface that lands (a
/// card) are never on screen together: the destination draws **one** lens
/// that starts life at the source's rect and grows into its own, while the
/// two contents cross-fade inside it.
///
/// Keeping it to one lens is the whole point. Two stacked lenses refract
/// each other and read as a double image, and — because a
/// glass samples the live backdrop through a `BackdropFilter` — the usual
/// `FadeTransition` trick cannot be used to hide one of the surfaces:
/// an `Opacity` (or `ImageFiltered`) above a lens puts it inside a
/// `saveLayer`, the backdrop it samples becomes that empty layer, and the
/// glass turns black. Nothing here ever wraps the lens in either; only the
/// *contents* inside the glass fade.
///
/// The route carries state, not layout: [sourceRect], [sourceRadius] and
/// [progress]. The destination screen decides where it wants to land and
/// asks [resolveGlassMorph] for the frame in between.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// How long the surface takes to bloom from the source into the destination.
const Duration kGlassMorphDuration = Duration(milliseconds: 780);

/// The way back is shorter: a dismissal should not make the user wait.
const Duration kGlassMorphReverseDuration = Duration(milliseconds: 520);

/// The in-flight state of a [GlassMorphRoute], read by the screen that lands.
///
/// Absent (`maybeOf` returns null) when the screen was pushed some other
/// way, which is what lets the destination stay a normal screen — it simply
/// lays itself out at rest.
class GlassMorph extends InheritedWidget {
  const GlassMorph({
    super.key,
    required this.sourceRect,
    required this.sourceRadius,
    required this.progress,
    required super.child,
  });

  /// Global rect of the surface the morph grows out of.
  final Rect sourceRect;

  /// Corner radius of that surface, in logical pixels.
  final double sourceRadius;

  /// 0 = entirely the source, 1 = entirely the destination.
  final Animation<double> progress;

  static GlassMorph? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassMorph>();

  @override
  bool updateShouldNotify(GlassMorph oldWidget) =>
      oldWidget.sourceRect != sourceRect ||
      oldWidget.sourceRadius != sourceRadius ||
      oldWidget.progress != progress;
}

/// Pushes [builder]'s screen as a glass morph out of a source surface.
///
/// The route itself draws nothing extra — it only publishes a [GlassMorph]
/// above the incoming screen. Screens that ignore it are pushed normally.
class GlassMorphRoute<T> extends PageRouteBuilder<T> {
  GlassMorphRoute({
    required Rect sourceRect,
    required double sourceRadius,
    required WidgetBuilder builder,
  }) : super(
         transitionDuration: kGlassMorphDuration,
         reverseTransitionDuration: kGlassMorphReverseDuration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // Rebuilt every frame, but `updateShouldNotify` is false for the
           // whole flight (the rect and the Animation object are the same
           // ones), so the destination never rebuilds from here — it
           // subscribes to `progress` itself and rebuilds only the wrappers
           // that actually change.
           return GlassMorph(
             sourceRect: sourceRect,
             sourceRadius: sourceRadius,
             progress: animation,
             child: child,
           );
         },
       );
}

/// Everything the morphing surface needs to paint one frame.
@immutable
class GlassMorphFrame {
  const GlassMorphFrame({
    required this.rect,
    required this.radius,
    required this.blend,
    required this.shimmer,
    required this.sourceOpacity,
    required this.targetOpacity,
  });

  /// The surface at rest in its destination — used when there is no morph.
  const GlassMorphFrame.settled(this.rect, this.radius)
    : blend = 1,
      shimmer = 1,
      sourceOpacity = 0,
      targetOpacity = 1;

  /// Where the glass sits this frame, in global coordinates.
  final Rect rect;

  /// Corner radius for [rect], already clamped so it can never exceed a
  /// capsule at the current size.
  final double radius;

  /// How far the *look* has travelled: 0 = the source's glass, 1 = the
  /// destination's. Drives the style and the drop shadow, not the geometry.
  final double blend;

  /// One lap of the press shimmer, run over the opening of the bloom so the
  /// flash the finger started on the button carries into the surface it
  /// becomes. Feed it to `shimmerAppGlassStyle`; 1 means "no shimmer".
  final double shimmer;

  /// Opacity of the source's own content (the button's label).
  final double sourceOpacity;

  /// Opacity of the destination's content (the card's form).
  final double targetOpacity;

  /// Whether the flight is over and the surface is fully the destination.
  bool get isSettled => blend >= 1.0;
}

// ── Choreography ──────────────────────────────────────────────────────────
//
// The three axes are deliberately out of step. A pill is already wide, so
// width arrives first and the surface reads as *stretching*; height follows
// on a spring that overshoots ~1.7% and settles, which is what sells it as
// liquid rather than a resize; the centre glides on its own curve so the
// travel across the screen stays smooth while the edges are still moving.

/// Width leads — the pill stretches sideways before it unfolds.
const Curve _kWidthCurve = Curves.easeOutQuart;

/// Height follows, a beat later, on a spring.
const Curve _kHeightCurve = Interval(0.08, 1.0, curve: _SettleCurve());

/// The surface's travel across the screen — no wobble, just arrival.
const Curve _kCentreCurve = Curves.easeOutCubic;

/// Tint, rim and refraction, plus the drop shadow under the glass.
const Curve _kBlendCurve = Curves.easeOutCubic;

/// Coming back needs no theatre: everything runs plain and eager.
const Curve _kBackCurve = Curves.easeInCubic;

/// The label is gone by the time the surface has properly started moving.
const double _kLabelOut = 0.18;

/// …and on the way back it only reappears once the pill is nearly reformed.
const double _kLabelBack = 0.34;

/// The shimmer completes its lap in the opening stretch, while the surface is
/// still opening out — after that the rim is back to its resting light.
const double _kShimmerLap = 0.55;

/// The destination's content condenses in over the back half of the flight.
const double _kContentIn = 0.46;

/// On the way back it leaves first, so the glass collapses empty.
const double _kContentBack = 0.68;

/// Resolves [progress] into the geometry and cross-fade for this frame.
///
/// [from]/[fromRadius] is the surface being left, [to]/[toRadius] the one
/// being arrived at, both in the same (global) coordinate space.
GlassMorphFrame resolveGlassMorph({
  required Animation<double> progress,
  required Rect from,
  required double fromRadius,
  required Rect to,
  required double toRadius,
}) {
  final double raw = progress.value.clamp(0.0, 1.0);
  final bool back = progress.status == AnimationStatus.reverse;

  final double tw = back
      ? _kBackCurve.transform(raw)
      : _kWidthCurve.transform(raw);
  final double th = back
      ? _kBackCurve.transform(raw)
      : _kHeightCurve.transform(raw);
  final double tc = back
      ? _kBackCurve.transform(raw)
      : _kCentreCurve.transform(raw);
  final double blend = back
      ? _kBackCurve.transform(raw)
      : _kBlendCurve.transform(raw);

  final Rect rect = Rect.fromCenter(
    center: Offset.lerp(from.center, to.center, tc)!,
    // The height curve overshoots, so these extrapolate past `to` for a
    // moment. That is the settle, and it is why they are lerped as scalars
    // instead of going through Rect.lerp.
    width: lerpDouble(from.width, to.width, tw)!,
    height: lerpDouble(from.height, to.height, th)!,
  );

  return GlassMorphFrame(
    rect: rect,
    radius: math.min(
      lerpDouble(fromRadius, toRadius, blend)!,
      rect.shortestSide / 2,
    ),
    blend: blend,
    // Only on the way out. A dismissal is not a press, so nothing flashes.
    shimmer: back ? 1 : (raw / _kShimmerLap).clamp(0.0, 1.0),
    sourceOpacity: back
        ? Curves.easeOut.transform(1 - (raw / _kLabelBack).clamp(0.0, 1.0))
        : 1 - Curves.easeIn.transform((raw / _kLabelOut).clamp(0.0, 1.0)),
    targetOpacity: back
        ? Curves.easeIn.transform(
            ((raw - _kContentBack) / (1 - _kContentBack)).clamp(0.0, 1.0),
          )
        : Curves.easeOut.transform(
            ((raw - _kContentIn) / (1 - _kContentIn)).clamp(0.0, 1.0),
          ),
  );
}

/// A single underdamped bounce: fast rise, ~1.7% overshoot around the
/// half-way mark, settled well before the end.
///
/// The closed form of a spring rather than a bezier, because a bezier that
/// overshoots this little is impossible to tune by eye. [Curve.transform]
/// pins the endpoints to exactly 0 and 1, so the residual at t = 1 (~5e-4)
/// never reaches the screen.
class _SettleCurve extends Curve {
  const _SettleCurve();

  /// Undamped natural frequency — how fast it gets there.
  static const double omega = 9.0;

  /// Damping ratio. Below 1 is what buys the overshoot, and 0.78 puts it at
  /// about 1.7%: enough to feel like matter, not enough to look like a bug.
  static const double zeta = 0.78;

  @override
  double transformInternal(double t) {
    final double damped = omega * math.sqrt(1 - zeta * zeta);
    final double decay = math.exp(-zeta * omega * t);
    return 1 -
        decay *
            (math.cos(damped * t) +
                (zeta * omega / damped) * math.sin(damped * t));
  }
}
