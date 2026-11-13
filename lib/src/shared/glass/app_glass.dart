import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import 'glass_backdrop.dart';
import 'liquid_glass.dart';

export 'glass_backdrop.dart'
    show FrozenGlassBackdrop, GlassBackdropScope, GlassScreenBoundary;
export 'liquid_glass.dart'
    show AppGlassLook, LiquidGlassOptics, LiquidGlassShader, kGlassLook;

/// The app's glass, drawn with plain Flutter — no glass package.
///
/// Every glass surface is the same simple frosted panel the task cards are:
/// a blur under a tint, and nothing else — no rim, no swell, no touch light,
/// no shimmer. The liquid-glass packages, and then their imitations, were
/// removed on 2026-11-12 because their per-frame work made a mid-range phone
/// (HONOR X9b, 120 Hz) drop frames everywhere. Then the live blur itself
/// turned out to be what still did it, so by default the blur is done once
/// and reused — see [AppBlurMode.baked] and `glass_backdrop.dart`.
///
/// On 2026-11-13 the liquid look came back as the app's own shader over that
/// baked picture — `liquid_glass.dart`. `GUVEN_GLASS=frost` turns it off.
///
/// Every surface still goes through this one file, so the look of all of
/// them changes here and nowhere else.

/// The least blur a surface gets, as a Gaussian sigma — the task cards' own.
const double kGlassMinBlur = 7.5;

/// How the app blurs. One switch for every blur, glass or not:
///
/// `flutter build apk --dart-define=GUVEN_BLUR=live`
enum AppBlurMode {
  /// The default. What is behind the glass is blurred once — the background
  /// when it is laid out, the screen when a panel opens over it — and each
  /// surface paints its piece of that picture. No per-frame blur anywhere
  /// but the login video.
  baked,

  /// A `BackdropFilter` per surface and an `ImageFiltered` per blurred
  /// transition, every frame. Exact, and too heavy for a mid-range phone.
  live,

  /// Nothing is blurred at all: every surface is its tint alone.
  off,
}

const String _kBlurName = String.fromEnvironment(
  'GUVEN_BLUR',
  defaultValue: 'baked',
);

/// The mode the build was made with. Unknown names mean [AppBlurMode.baked].
const AppBlurMode kBlurMode = _kBlurName == 'live'
    ? AppBlurMode.live
    : (_kBlurName == 'off' || _kBlurName == 'false')
    ? AppBlurMode.off
    : AppBlurMode.baked;

/// A blur of whatever is behind [child], in the build's [kBlurMode]. Feature
/// code uses this instead of [BackdropFilter].
///
/// [amount] scales it: 0 none, 1 all of [sigma]. A live blur scales its
/// sigma; a baked one fades its picture in, which reads the same.
class AppBackdropBlur extends StatelessWidget {
  const AppBackdropBlur({
    super.key,
    required this.sigma,
    this.amount = 1,
    this.grouped = false,
    this.child,
  });

  final double sigma;
  final double amount;

  /// Live only: share the backdrop read of the nearest [BackdropGroup].
  final bool grouped;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double t = amount.clamp(0.0, 1.0);
    switch (kBlurMode) {
      case AppBlurMode.off:
        return child ?? const SizedBox.shrink();
      case AppBlurMode.baked:
        return GlassBackdropPaint(amount: t, child: child);
      case AppBlurMode.live:
        final ImageFilter filter = ImageFilter.blur(
          sigmaX: sigma * t,
          sigmaY: sigma * t,
        );
        return grouped
            ? BackdropFilter.grouped(filter: filter, child: child)
            : BackdropFilter(filter: filter, child: child);
    }
  }
}

/// An [ImageFiltered] in the build's [kBlurMode]. Feature code uses this
/// instead of [ImageFiltered].
///
/// Only a live build blurs content in transitions — a text that blurs in
/// and out is a per-frame blur, and fading it reads almost the same. [always]
/// keeps the filter in a baked build too: the login video, which moves, so
/// cannot be blurred once, and is the one blur still worth its cost.
class AppImageFiltered extends StatelessWidget {
  const AppImageFiltered({
    super.key,
    required this.imageFilter,
    this.always = false,
    this.child,
  });

  final ImageFilter imageFilter;
  final bool always;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool on =
        kBlurMode == AppBlurMode.live ||
        (always && kBlurMode == AppBlurMode.baked);
    if (!on) return child ?? const SizedBox.shrink();
    return ImageFiltered(imageFilter: imageFilter, child: child);
  }
}

/// A glass surface's look, owned by the app.
@immutable
class AppGlassStyle {
  const AppGlassStyle({
    required this.cornerRadius,
    this.glassColor = const Color(0x00FFFFFF),
    this.blur = 0,
    this.optics = const LiquidGlassOptics(),
  });

  final double cornerRadius;

  /// The tint laid over the blur.
  final Color glassColor;

  /// Blur sigma; never less than [kGlassMinBlur] when drawn.
  final double blur;

  /// How the surface bends and lights its edge, in a liquid build.
  final LiquidGlassOptics optics;

  AppGlassStyle copyWith({
    double? cornerRadius,
    Color? glassColor,
    double? blur,
    LiquidGlassOptics? optics,
  }) {
    return AppGlassStyle(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      glassColor: glassColor ?? this.glassColor,
      blur: blur ?? this.blur,
      optics: optics ?? this.optics,
    );
  }
}

/// One backdrop read shared by every surface beneath it, in a live build.
///
/// A Flutter `BackdropGroup`: the surfaces inside it blur one shared copy of
/// what is behind them instead of each copying it again. Surfaces under it
/// should not overlap each other. A baked build reads no backdrop at all.
class AppGlassLayer extends StatelessWidget {
  const AppGlassLayer({super.key, required this.style, required this.child});

  /// Kept for call sites; the look comes from each surface's own style.
  final AppGlassStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      kBlurMode == AppBlurMode.live ? BackdropGroup(child: child) : child;
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

    // Liquid: the shader draws the bent backdrop, the tint and the rim in one
    // pass, and paints its contour hairline just outside the edge — so it
    // stands outside the clip, and only the child is clipped.
    if (fade > 0 &&
        kBlurMode == AppBlurMode.baked &&
        LiquidGlassShader.ready) {
      return GlassBackdropPaint(
        liquid: LiquidGlassSpec(
          cornerRadius: cornerRadius ?? style.cornerRadius,
          tint: tint,
          fade: fade,
          optics: style.optics,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      );
    }

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: tint.a * fade),
        borderRadius: borderRadius,
      ),
      child: child,
    );
    if (fade <= 0) return surface;

    return ClipRRect(
      borderRadius: borderRadius,
      child: AppBackdropBlur(
        sigma: math.max(style.blur, kGlassMinBlur),
        amount: fade,
        grouped: true,
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
    optics: LiquidGlassOptics.lerp(a.optics, b.optics, t),
  );
}
