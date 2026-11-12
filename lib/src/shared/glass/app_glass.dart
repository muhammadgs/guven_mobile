import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// The app's glass, drawn with plain Flutter — no glass package.
///
/// Since 2026-11-12 every glass surface is the same simple frosted panel the
/// task cards are: a `BackdropFilter` blur under a tint, and nothing else —
/// no rim, no swell, no touch light, no shimmer. The liquid-glass packages,
/// and then their imitations, were removed because their per-frame work made
/// even mid-range phones (HONOR X9b, 120 Hz) drop frames everywhere.
///
/// Every surface still goes through this one file, so the look of all of
/// them changes here and nowhere else.

/// The least blur a surface gets, as a Gaussian sigma — the task cards' own.
const double kGlassMinBlur = 7.5;

/// A glass surface's look, owned by the app.
@immutable
class AppGlassStyle {
  const AppGlassStyle({
    required this.cornerRadius,
    this.glassColor = const Color(0x00FFFFFF),
    this.blur = 0,
  });

  final double cornerRadius;

  /// The tint laid over the blur.
  final Color glassColor;

  /// Blur sigma; never less than [kGlassMinBlur] when drawn.
  final double blur;

  AppGlassStyle copyWith({
    double? cornerRadius,
    Color? glassColor,
    double? blur,
  }) {
    return AppGlassStyle(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      glassColor: glassColor ?? this.glassColor,
      blur: blur ?? this.blur,
    );
  }
}

/// One backdrop read shared by every surface beneath it.
///
/// A Flutter `BackdropGroup`: the surfaces inside it blur one shared copy of
/// what is behind them instead of each copying it again. Surfaces under it
/// should not overlap each other.
class AppGlassLayer extends StatelessWidget {
  const AppGlassLayer({super.key, required this.style, required this.child});

  /// Kept for call sites; the look comes from each surface's own style.
  final AppGlassStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => BackdropGroup(child: child);
}

/// The only raw glass primitive feature code should use: a blur under a
/// tint, clipped to a rounded rectangle.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.style,
    required this.child,
    this.cornerRadius,
    this.fade = 1,
  });

  final AppGlassStyle style;
  final Widget child;
  final double? cornerRadius;

  /// How much of the glass is drawn: 0 nothing, 1 all of it. The child is
  /// not faded. Never fade glass with an `Opacity` above it — a blur inside a
  /// translucent layer reads only that layer.
  final double fade;

  @override
  Widget build(BuildContext context) {
    final double fade = this.fade.clamp(0.0, 1.0);
    final BorderRadius borderRadius = BorderRadius.circular(
      cornerRadius ?? style.cornerRadius,
    );
    final Color tint = style.glassColor;
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: tint.a * fade),
        borderRadius: borderRadius,
      ),
      child: child,
    );
    if (fade <= 0) return surface;

    final double sigma = math.max(style.blur, kGlassMinBlur) * fade;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}

/// A tappable [AppGlassSurface]: Flutter's own ink ripple, nothing else.
class AppGlassButton extends StatelessWidget {
  const AppGlassButton({
    super.key,
    required this.style,
    required this.onTap,
    required this.child,
    this.cornerRadius,
    this.splashColor,
  });

  final AppGlassStyle style;
  final VoidCallback? onTap;
  final Widget child;
  final double? cornerRadius;

  /// The ripple's colour; the theme's when null.
  final Color? splashColor;

  @override
  Widget build(BuildContext context) {
    final double radius = cornerRadius ?? style.cornerRadius;
    final Color? splash = splashColor;
    return AppGlassSurface(
      style: style,
      cornerRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        // Material would otherwise reset the text under it to the theme's
        // body style.
        textStyle: DefaultTextStyle.of(context).style,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: splash,
          highlightColor: splash?.withValues(alpha: splash.a / 2),
          child: child,
        ),
      ),
    );
  }
}

/// Returns [style] with its geometry-driven radius replaced.
AppGlassStyle glassAtRadius(AppGlassStyle style, double cornerRadius) =>
    style.copyWith(cornerRadius: cornerRadius);

/// Interpolates two styles.
AppGlassStyle lerpAppGlassStyle(
  AppGlassStyle a,
  AppGlassStyle b,
  double t, {
  double? cornerRadius,
}) {
  return AppGlassStyle(
    cornerRadius:
        cornerRadius ?? lerpDouble(a.cornerRadius, b.cornerRadius, t)!,
    glassColor: Color.lerp(a.glassColor, b.glassColor, t)!,
    blur: lerpDouble(a.blur, b.blur, t)!,
  );
}
