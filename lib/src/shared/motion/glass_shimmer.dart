/// A press that runs light around the rim of a glass surface.
///
/// The lens already answers a finger with a squash ([LiquidGlassTouch]); this
/// adds the optical half of the same gesture — a specular highlight that
/// travels once around the perimeter and fades, the way Apple's glass answers
/// a tap.
///
/// It is pure lighting: [LiquidGlassShape.lightDirection] sweeps a full lap,
/// [LiquidGlassShape.lightIntensity] pulses, and the optical rim's
/// [OpticalBorder.lightSpread] tightens so the highlight reads as *travelling*
/// rather than washing over the whole rim at once. Nothing about the geometry,
/// the tint or the refraction moves, and — importantly — no layer is added
/// above the lens, so the glass never blacks out.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'glass_morph.dart';

/// One lap of the highlight.
const Duration kGlassShimmerDuration = Duration(milliseconds: 520);

/// How much brighter the rim gets at the peak of the flash.
const double _kFlash = 0.85;

/// How tight the travelling highlight pulls in at that peak. The rim's resting
/// spread is around 0.5 — broad enough that a moving light would not read.
const double _kTightSpread = 0.12;

/// Extra ambient glow carried along with the flash.
const double _kGlow = 0.45;

/// [style] with the shimmer at [t] applied, where `t` runs 0 → 1 over one lap.
///
/// Returns [style] untouched outside that range, and lands back on it exactly
/// at `t = 1`: the pulse closes on zero and a full 360° sweep is the same
/// angle it started from.
LiquidGlassStyle shimmerLiquidGlassStyle(LiquidGlassStyle style, double t) {
  if (t <= 0 || t >= 1) return style;

  final LiquidGlassShape shape = style.shape ?? const LiquidGlassShape();
  final double pulse = math.sin(math.pi * t); // 0 → 1 → 0
  final double sweep = Curves.easeOutCubic.transform(t); // whips, then settles

  return LiquidGlassStyle(
    shape: LiquidGlassShape(
      cornerStyle: shape.cornerStyle,
      cornerRadius: shape.cornerRadius,
      clipQuality: shape.clipQuality,
      borderWidth: shape.borderWidth,
      borderColor: shape.borderColor,
      lightIntensity: shape.lightIntensity * (1 + _kFlash * pulse),
      lightColor: shape.lightColor,
      lightDirection: shape.lightDirection + 360 * sweep,
      lightMode: shape.lightMode,
      borderType: _shimmerBorder(shape.borderType, pulse),
    ),
    appearance: style.appearance,
    refraction: style.refraction,
  );
}

LiquidGlassBorderType _shimmerBorder(LiquidGlassBorderType border, double pulse) {
  if (border is! OpticalBorder) return border;
  return OpticalBorder(
    borderSaturation: border.borderSaturation,
    ambientIntensity: border.ambientIntensity * (1 + _kGlow * pulse),
    borderSolidity: border.borderSolidity,
    lightSpread: lerpDouble(border.lightSpread, _kTightSpread, pulse)!,
  );
}

/// A glass surface that flashes when pressed.
///
/// Squash and shimmer fire together on touch-down, so the surface answers the
/// finger before it lifts — which matters for the start button, where lifting
/// pushes a route.
class GlassPressButton extends StatefulWidget {
  const GlassPressButton({
    super.key,
    required this.width,
    required this.height,
    required this.cornerRadius,
    required this.style,
    required this.onTap,
    required this.child,
    this.shadow = const <BoxShadow>[],
    this.flex = const LiquidGlassFlex.pronounced(),
  });

  final double width;
  final double height;

  /// Drives the lens's corner as geometry rather than taking [style]'s own
  /// nominal radius — see [glassAtRadius].
  final double cornerRadius;

  final LiquidGlassStyle style;
  final VoidCallback onTap;

  /// Rides on top of the glass; it is not refracted.
  final Widget child;

  final List<BoxShadow> shadow;
  final LiquidGlassFlex flex;

  @override
  State<GlassPressButton> createState() => _GlassPressButtonState();
}

class _GlassPressButtonState extends State<GlassPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: kGlassShimmerDuration,
  );

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resting =
        glassAtRadius(widget.style, widget.cornerRadius);

    return GestureDetector(
      onTapDown: (_) => _shimmer.forward(from: 0),
      onTap: widget.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.cornerRadius),
          boxShadow: widget.shadow,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _shimmer,
            child: widget.child,
            builder: (context, child) {
              return LiquidGlassLens(
                style: shimmerLiquidGlassStyle(resting, _shimmer.value),
                // The lens squashes under the finger and springs back.
                // `Listener`-based, so the GestureDetector still wins the tap.
                touch: LiquidGlassTouch(flex: widget.flex),
                child: Center(child: child),
              );
            },
          ),
        ),
      ),
    );
  }
}
