import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart' as easy;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

/// The renderer used by the app-owned glass widgets.
///
/// Renderer is the default. The old implementation remains available while
/// the new package is being evaluated:
///
/// `flutter run --dart-define=GUVEN_GLASS_BACKEND=easy`
const bool kUseLegacyEasyGlass =
    String.fromEnvironment('GUVEN_GLASS_BACKEND', defaultValue: 'renderer') ==
    'easy';

/// Which package draws a glass surface.
enum AppGlassBackend {
  /// `liquid_glass_renderer` — the app default.
  renderer,

  /// `liquid_glass_easy`. Chosen app-wide by the rollback build flag, and
  /// per-surface wherever its optical border reads better than the
  /// renderer's — see [AppGlassSurface.backend].
  easy,
}

/// What a surface draws with unless it names a [AppGlassSurface.backend].
const AppGlassBackend kDefaultGlassBackend = kUseLegacyEasyGlass
    ? AppGlassBackend.easy
    : AppGlassBackend.renderer;

/// Compiles `liquid_glass_easy`'s shaders.
///
/// Always, not only under the rollback flag: the nav bar's travelling
/// indicator is pinned to that backend, so its shaders are needed on every
/// run. A lens loads them itself on first build, but that first build is a
/// touch response — warming them at startup keeps the capsule from appearing
/// frosted for the frame or two the compile takes.
///
/// `liquid_glass_renderer` owns shader loading through its `ShaderBuilder`, so
/// it needs no eager startup work.
Future<void> warmUpAppGlassShaders() async {
  try {
    await easy.LiquidGlassShaders.ensureLoaded();
  } catch (_) {
    // The package already falls back when its shaders are unavailable.
  }
}

/// Legacy-only values that do not map one-to-one to renderer settings.
///
/// Keeping these beside the renderer style makes rollback a build flag rather
/// than a source-code revert, without leaking `liquid_glass_easy` types into
/// features.
@immutable
class AppGlassLegacyTuning {
  const AppGlassLegacyTuning({
    required this.distortion,
    required this.distortionWidth,
    required this.magnification,
    required this.chromaticAberration,
    required this.lightIntensity,
    required this.ambientIntensity,
    required this.borderSaturation,
    required this.borderSolidity,
    this.lightSpread = 0.5,
    this.lightDirection = 45,
    this.refractionIndex,
    this.refractionDepth,
  });

  final double distortion;
  final double distortionWidth;
  final double magnification;
  final double chromaticAberration;
  final double lightIntensity;
  final double ambientIntensity;
  final double borderSaturation;
  final double borderSolidity;
  final double lightSpread;

  /// Degrees, matching `liquid_glass_easy`'s light-direction convention.
  final double lightDirection;

  /// When present, the legacy backend uses its optical refraction model.
  final double? refractionIndex;
  final double? refractionDepth;

  AppGlassLegacyTuning copyWith({
    double? distortion,
    double? distortionWidth,
    double? magnification,
    double? chromaticAberration,
    double? lightIntensity,
    double? ambientIntensity,
    double? borderSaturation,
    double? borderSolidity,
    double? lightSpread,
    double? lightDirection,
    double? refractionIndex,
    double? refractionDepth,
  }) {
    return AppGlassLegacyTuning(
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      magnification: magnification ?? this.magnification,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      lightIntensity: lightIntensity ?? this.lightIntensity,
      ambientIntensity: ambientIntensity ?? this.ambientIntensity,
      borderSaturation: borderSaturation ?? this.borderSaturation,
      borderSolidity: borderSolidity ?? this.borderSolidity,
      lightSpread: lightSpread ?? this.lightSpread,
      lightDirection: lightDirection ?? this.lightDirection,
      refractionIndex: refractionIndex ?? this.refractionIndex,
      refractionDepth: refractionDepth ?? this.refractionDepth,
    );
  }
}

/// A package-neutral glass style owned by the app.
///
/// New rendering uses [settings]. [legacy] exists only so the old backend can
/// be selected with `GUVEN_GLASS_BACKEND=easy` during the trial.
@immutable
class AppGlassStyle {
  const AppGlassStyle({
    required this.cornerRadius,
    required this.settings,
    required this.legacy,
  });

  final double cornerRadius;
  final renderer.LiquidGlassSettings settings;
  final AppGlassLegacyTuning legacy;

  AppGlassStyle copyWith({
    double? cornerRadius,
    renderer.LiquidGlassSettings? settings,
    AppGlassLegacyTuning? legacy,
  }) {
    return AppGlassStyle(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      settings: settings ?? this.settings,
      legacy: legacy ?? this.legacy,
    );
  }
}

/// Interaction tuning for both renderers.
@immutable
class AppGlassFlex {
  const AppGlassFlex._({
    required this.interactionScale,
    required this.stretch,
    required this.resistance,
    required this.legacy,
  });

  const AppGlassFlex.pronounced()
    : this._(
        interactionScale: 1.05,
        stretch: 0.5,
        resistance: 0.08,
        legacy: const easy.LiquidGlassFlex.pronounced(),
      );

  const AppGlassFlex.statPill()
    : this._(
        interactionScale: 1.022,
        stretch: 0.32,
        resistance: 0.1,
        legacy: const easy.LiquidGlassFlex(
          stretch: 30,
          squeeze: 0.8,
          grip: 0.72,
          lean: 0.35,
          holdScale: 0.03,
          tapScale: 0.022,
          maxPull: 90,
          lockAxis: Axis.horizontal,
          advanced: easy.LiquidGlassFlexAdvanced(
            refractionBoost: 0.1,
            stiffness: 340,
            damping: 26,
            releaseDamping: 20,
          ),
        ),
      );

  final double interactionScale;
  final double stretch;
  final double resistance;
  final easy.LiquidGlassFlex legacy;
}

/// A shared renderer layer for multiple surfaces with identical settings.
///
/// It is intentionally transparent under the legacy backend: each old lens
/// already owns its rendering path.
class AppGlassLayer extends StatelessWidget {
  const AppGlassLayer({
    super.key,
    required this.style,
    required this.child,
    this.fake = false,
  });

  final AppGlassStyle style;
  final Widget child;
  final bool fake;

  @override
  Widget build(BuildContext context) {
    if (kUseLegacyEasyGlass) return child;
    return renderer.LiquidGlassLayer(
      settings: style.settings,
      fake: fake,
      useBackdropGroup: true,
      child: child,
    );
  }
}

/// The only raw glass primitive feature code should use.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.style,
    required this.child,
    this.cornerRadius,
    this.flex,
    this.glowColor,
    this.glowRadius = 1,
    this.useOwnLayer = true,
    this.glassContainsChild = false,
    this.fake = false,
    this.backend,
    this.fade = 1,
  });

  final AppGlassStyle style;
  final Widget child;
  final double? cornerRadius;
  final AppGlassFlex? flex;
  final Color? glowColor;
  final double glowRadius;

  /// Overrides [kDefaultGlassBackend] for this one surface.
  ///
  /// Set it only where the two packages differ in a way that matters to the
  /// design, not as a preference — every surface that leaves it null follows
  /// the build flag together.
  final AppGlassBackend? backend;

  /// How much of the style is drawn: 0 nothing, 1 all of it.
  ///
  /// Each backend fades in its own terms. Never with an `Opacity` above the
  /// lens — a layer opened over one renders it black.
  final double fade;

  /// False when an [AppGlassLayer] above this widget owns the renderer layer.
  final bool useOwnLayer;
  final bool glassContainsChild;

  /// Uses renderer's lightweight frosted implementation for low-impact or
  /// scrollable surfaces. On a shared layer, set this on [AppGlassLayer].
  final bool fake;

  double get _radius => cornerRadius ?? style.cornerRadius;

  double get _fade => fade.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    if ((backend ?? kDefaultGlassBackend) == AppGlassBackend.easy) {
      return _buildEasy();
    }

    Widget content = child;
    if (glowColor != null) {
      content = renderer.GlassGlow(
        glowColor: glowColor!,
        glowRadius: glowRadius,
        hitTestBehavior: HitTestBehavior.translucent,
        child: content,
      );
    }

    // The renderer has one knob for exactly this: it scales every optical
    // property at once, and at 0 the geometry shader returns early.
    final renderer.LiquidGlassSettings settings = _fade >= 1
        ? style.settings
        : style.settings.copyWith(
            visibility: style.settings.visibility * _fade,
          );

    final renderer.LiquidShape shape = renderer.LiquidRoundedSuperellipse(
      borderRadius: _radius,
    );
    Widget glass = useOwnLayer
        ? renderer.LiquidGlass.withOwnLayer(
            settings: settings,
            fake: fake,
            shape: shape,
            glassContainsChild: glassContainsChild,
            child: content,
          )
        : renderer.LiquidGlass(
            shape: shape,
            glassContainsChild: glassContainsChild,
            child: content,
          );

    final AppGlassFlex? flex = this.flex;
    if (flex != null) {
      glass = renderer.LiquidStretch(
        interactionScale: flex.interactionScale,
        stretch: flex.stretch,
        resistance: flex.resistance,
        hitTestBehavior: HitTestBehavior.translucent,
        child: glass,
      );
    }
    return glass;
  }

  Widget _buildEasy() {
    Widget lens = easy.LiquidGlassLens(
      style: _legacyStyle(_faded(style.copyWith(cornerRadius: _radius))),
      // `visibility` here is a switch, not a dial: false disables the glass
      // and drops the child, so a surface faded to nothing costs no backdrop.
      visibility: _fade > 0,
      touch: flex == null ? null : easy.LiquidGlassTouch(flex: flex!.legacy),
      child: child,
    );
    if (glowColor == null) return lens;

    lens = renderer.GlassGlowLayer(
      child: renderer.GlassGlow(
        glowColor: glowColor!,
        glowRadius: glowRadius,
        hitTestBehavior: HitTestBehavior.translucent,
        child: lens,
      ),
    );
    return ClipRRect(borderRadius: BorderRadius.circular(_radius), child: lens);
  }

  /// [style] with its whole optical response scaled by [fade].
  ///
  /// `liquid_glass_easy` has no single visibility dial, so the fade has to be
  /// spread across every property that carries the effect: the strengths are
  /// scaled towards zero and the multipliers towards 1, which is their own
  /// "does nothing" value.
  AppGlassStyle _faded(AppGlassStyle style) {
    final double t = _fade;
    if (t >= 1) return style;

    final renderer.LiquidGlassSettings settings = style.settings;
    final AppGlassLegacyTuning legacy = style.legacy;
    return style.copyWith(
      settings: settings.copyWith(
        glassColor: settings.glassColor.withValues(
          alpha: settings.glassColor.a * t,
        ),
        blur: settings.blur * t,
        saturation: lerpDouble(1, settings.saturation, t)!,
      ),
      legacy: legacy.copyWith(
        distortion: legacy.distortion * t,
        chromaticAberration: legacy.chromaticAberration * t,
        magnification: lerpDouble(1, legacy.magnification, t)!,
        lightIntensity: legacy.lightIntensity * t,
        ambientIntensity: legacy.ambientIntensity * t,
        borderSaturation: lerpDouble(1, legacy.borderSaturation, t)!,
        borderSolidity: legacy.borderSolidity * t,
        refractionDepth: legacy.refractionDepth == null
            ? null
            : legacy.refractionDepth! * t,
      ),
    );
  }
}

/// Returns [style] with its geometry-driven radius replaced.
AppGlassStyle glassAtRadius(AppGlassStyle style, double cornerRadius) =>
    style.copyWith(cornerRadius: cornerRadius);

/// Interpolates renderer and rollback settings in lockstep.
AppGlassStyle lerpAppGlassStyle(
  AppGlassStyle a,
  AppGlassStyle b,
  double t, {
  double? cornerRadius,
}) {
  return AppGlassStyle(
    cornerRadius:
        cornerRadius ?? lerpDouble(a.cornerRadius, b.cornerRadius, t)!,
    settings: _lerpSettings(a.settings, b.settings, t),
    legacy: _lerpLegacy(a.legacy, b.legacy, t),
  );
}

renderer.LiquidGlassSettings _lerpSettings(
  renderer.LiquidGlassSettings a,
  renderer.LiquidGlassSettings b,
  double t,
) {
  return renderer.LiquidGlassSettings(
    visibility: lerpDouble(a.visibility, b.visibility, t)!,
    glassColor: Color.lerp(a.glassColor, b.glassColor, t)!,
    thickness: lerpDouble(a.thickness, b.thickness, t)!,
    blur: lerpDouble(a.blur, b.blur, t)!,
    chromaticAberration: lerpDouble(
      a.chromaticAberration,
      b.chromaticAberration,
      t,
    )!,
    lightAngle: lerpDouble(a.lightAngle, b.lightAngle, t)!,
    lightIntensity: lerpDouble(a.lightIntensity, b.lightIntensity, t)!,
    ambientStrength: lerpDouble(a.ambientStrength, b.ambientStrength, t)!,
    refractiveIndex: lerpDouble(a.refractiveIndex, b.refractiveIndex, t)!,
    saturation: lerpDouble(a.saturation, b.saturation, t)!,
  );
}

AppGlassLegacyTuning _lerpLegacy(
  AppGlassLegacyTuning a,
  AppGlassLegacyTuning b,
  double t,
) {
  final bool handsToOptical =
      a.refractionIndex == null && b.refractionIndex != null;
  const double handover = 0.10;
  final double afterHandover = ((t - handover) / (1 - handover)).clamp(
    0.0,
    1.0,
  );

  return AppGlassLegacyTuning(
    distortion: lerpDouble(a.distortion, b.distortion, t)!,
    distortionWidth: lerpDouble(a.distortionWidth, b.distortionWidth, t)!,
    magnification: lerpDouble(a.magnification, b.magnification, t)!,
    chromaticAberration: lerpDouble(
      a.chromaticAberration,
      b.chromaticAberration,
      t,
    )!,
    lightIntensity: lerpDouble(a.lightIntensity, b.lightIntensity, t)!,
    ambientIntensity: lerpDouble(a.ambientIntensity, b.ambientIntensity, t)!,
    borderSaturation: lerpDouble(a.borderSaturation, b.borderSaturation, t)!,
    borderSolidity: lerpDouble(a.borderSolidity, b.borderSolidity, t)!,
    lightSpread: lerpDouble(a.lightSpread, b.lightSpread, t)!,
    lightDirection: lerpDouble(a.lightDirection, b.lightDirection, t)!,
    refractionIndex: handsToOptical
        ? (t < handover
              ? null
              : lerpDouble(1.25, b.refractionIndex, afterHandover))
        : _lerpNullable(a.refractionIndex, b.refractionIndex, t),
    refractionDepth: handsToOptical
        ? (t < handover
              ? null
              : lerpDouble(
                  a.distortion,
                  b.refractionDepth ?? b.distortion,
                  afterHandover,
                ))
        : _lerpNullable(a.refractionDepth, b.refractionDepth, t),
  );
}

double? _lerpNullable(double? a, double? b, double t) {
  if (a == null && b == null) return null;
  return lerpDouble(a ?? b!, b ?? a!, t);
}

easy.LiquidGlassStyle _legacyStyle(AppGlassStyle style) {
  final AppGlassLegacyTuning legacy = style.legacy;
  final easy.LiquidGlassRefractionType? optical = legacy.refractionIndex == null
      ? null
      : easy.OpticalRefraction(
          refraction: legacy.refractionIndex!,
          refractionWidth: legacy.distortionWidth,
          depth: legacy.refractionDepth ?? legacy.distortion,
        );

  return easy.LiquidGlassStyle(
    shape: easy.LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: style.cornerRadius,
      lightIntensity: legacy.lightIntensity,
      lightDirection: legacy.lightDirection,
      borderType: easy.OpticalBorder(
        ambientIntensity: legacy.ambientIntensity,
        borderSaturation: legacy.borderSaturation,
        borderSolidity: legacy.borderSolidity,
        lightSpread: legacy.lightSpread,
      ),
    ),
    appearance: easy.LiquidGlassAppearance(
      color: style.settings.glassColor,
      saturation: style.settings.saturation,
      blur: easy.LiquidGlassBlur(
        sigmaX: style.settings.blur,
        sigmaY: style.settings.blur,
      ),
    ),
    refraction: easy.LiquidGlassRefraction(
      distortion: legacy.distortion,
      distortionWidth: legacy.distortionWidth,
      magnification: legacy.magnification,
      chromaticAberration: legacy.chromaticAberration,
      refractionType: optical,
    ),
  );
}
