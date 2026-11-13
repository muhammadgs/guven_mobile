/// Liquid glass drawn by the app's own shader, over the backdrop picture
/// that was blurred once (`glass_backdrop.dart`).
///
/// The optics — the bevel lens that bends the backdrop at the edge, the
/// glint, the dark contour and the inner bevel shadow — are ported from
/// `liquid_glass_renderer`; see `shaders/liquid_glass.frag`. Per frame a
/// surface costs one shader draw over its own pixels: no backdrop copy, no
/// blur, no offscreen layer.
///
/// One switch rolls the whole app back to the plain frosted glass:
///
/// `flutter build apk --dart-define=GUVEN_GLASS=frost`
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How glass surfaces look.
enum AppGlassLook {
  /// The default: the baked blur bent by the liquid shader at the edges.
  liquid,

  /// The plain frosted panel — the baked blur under a tint, nothing else.
  frost,
}

const String _kGlassName = String.fromEnvironment(
  'GUVEN_GLASS',
  defaultValue: 'liquid',
);

/// The look the build was made with. Unknown names mean [AppGlassLook.liquid].
const AppGlassLook kGlassLook = _kGlassName == 'frost'
    ? AppGlassLook.frost
    : AppGlassLook.liquid;

/// The optical settings of one liquid surface. Defaults are
/// `liquid_glass_renderer` 1.0's iOS 27 regular glass.
@immutable
class LiquidGlassOptics {
  const LiquidGlassOptics({
    this.refractionHeight = 20,
    this.refractionAmount = 60,
    this.dispersion = 0,
    this.highlight = 1,
    this.highlightOpposite = 0.8,
    this.contourStrength = 0.43,
    this.contourDirectionality = 0.77,
    this.bevelShadowStrength = 0.036,
    this.rimSharpness = 0.5,
    this.saturation = 1,
    this.magnification = 1,
    this.fitsShape = true,
  });

  /// How far in from the edge the glass bends the backdrop. Never more than
  /// a quarter of the surface's shorter side.
  final double refractionHeight;

  /// How far, at the very edge, the backdrop is pulled in from. Never more
  /// than half the surface's shorter side.
  final double refractionAmount;

  /// Splits red from blue at the bent edge; 0 none.
  final double dispersion;

  /// The glint's strength along the top and bottom edges; 0 none.
  final double highlight;

  /// The glint on the edge facing away from the light, against the one
  /// facing it.
  final double highlightOpposite;

  /// The dark hairline just outside the edge: its opacity.
  final double contourStrength;

  /// 0: the hairline is even all round; 1: only on the side walls.
  final double contourDirectionality;

  /// The soft shade inside the top edge.
  final double bevelShadowStrength;

  /// How much of the bent rim shows the UNBLURRED backdrop: 0 all blurred,
  /// 1 sharp at the very edge. Ours, not the renderer's — the renderer bends
  /// a lightly frosted backdrop; ours is blurred harder.
  final double rimSharpness;

  /// 1 leaves colours as they are.
  final double saturation;

  /// How much bigger the surface shows what is under it; 1 not at all. Only
  /// worth more than 1 over a picture taken that much sharper.
  final double magnification;

  /// True: regular glass — the bevel is at most a quarter of the shorter side.
  /// False: a clear lens — the bevel keeps its height and the whole lens
  /// scales down only on a surface too small for it (the renderer's
  /// `refractionFitsShape`).
  final bool fitsShape;

  static LiquidGlassOptics lerp(
    LiquidGlassOptics a,
    LiquidGlassOptics b,
    double t,
  ) {
    if (identical(a, b) || a == b) return a;
    return LiquidGlassOptics(
      refractionHeight: ui.lerpDouble(
        a.refractionHeight,
        b.refractionHeight,
        t,
      )!,
      refractionAmount: ui.lerpDouble(
        a.refractionAmount,
        b.refractionAmount,
        t,
      )!,
      dispersion: ui.lerpDouble(a.dispersion, b.dispersion, t)!,
      highlight: ui.lerpDouble(a.highlight, b.highlight, t)!,
      highlightOpposite: ui.lerpDouble(
        a.highlightOpposite,
        b.highlightOpposite,
        t,
      )!,
      contourStrength: ui.lerpDouble(a.contourStrength, b.contourStrength, t)!,
      contourDirectionality: ui.lerpDouble(
        a.contourDirectionality,
        b.contourDirectionality,
        t,
      )!,
      bevelShadowStrength: ui.lerpDouble(
        a.bevelShadowStrength,
        b.bevelShadowStrength,
        t,
      )!,
      rimSharpness: ui.lerpDouble(a.rimSharpness, b.rimSharpness, t)!,
      saturation: ui.lerpDouble(a.saturation, b.saturation, t)!,
      magnification: ui.lerpDouble(a.magnification, b.magnification, t)!,
      fitsShape: t < 0.5 ? a.fitsShape : b.fitsShape,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassOptics &&
      other.refractionHeight == refractionHeight &&
      other.refractionAmount == refractionAmount &&
      other.dispersion == dispersion &&
      other.highlight == highlight &&
      other.highlightOpposite == highlightOpposite &&
      other.contourStrength == contourStrength &&
      other.contourDirectionality == contourDirectionality &&
      other.bevelShadowStrength == bevelShadowStrength &&
      other.rimSharpness == rimSharpness &&
      other.saturation == saturation &&
      other.magnification == magnification &&
      other.fitsShape == fitsShape;

  @override
  int get hashCode => Object.hash(
    refractionHeight,
    refractionAmount,
    dispersion,
    highlight,
    highlightOpposite,
    contourStrength,
    contourDirectionality,
    bevelShadowStrength,
    rimSharpness,
    saturation,
    magnification,
    fitsShape,
  );
}

/// Everything one liquid surface needs to be drawn, besides its backdrop.
@immutable
class LiquidGlassSpec {
  const LiquidGlassSpec({
    required this.cornerRadius,
    required this.tint,
    this.fade = 1,
    this.optics = const LiquidGlassOptics(),
  });

  final double cornerRadius;

  /// Laid over the bent backdrop, inside the shader.
  final Color tint;

  /// 0 nothing drawn, 1 all of it — tint, bend and rim together.
  final double fade;

  final LiquidGlassOptics optics;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSpec &&
      other.cornerRadius == cornerRadius &&
      other.tint == tint &&
      other.fade == fade &&
      other.optics == optics;

  @override
  int get hashCode => Object.hash(cornerRadius, tint, fade, optics);
}

/// The compiled shader, loaded once at startup.
abstract final class LiquidGlassShader {
  static const String _asset = 'shaders/liquid_glass.frag';

  static ui.FragmentProgram? _program;

  /// Bound to a sampler the shader is told not to read.
  static ui.Image? _blank;

  /// Whether liquid glass can be drawn. False in a frost build, before
  /// [load] has finished, and if the shader failed to load — every surface
  /// then draws the plain frosted glass.
  static bool get ready =>
      kGlassLook == AppGlassLook.liquid && _program != null && _blank != null;

  /// Loads the shader. Safe to call more than once; never throws.
  static Future<void> load() async {
    if (kGlassLook != AppGlassLook.liquid || _program != null) return;
    try {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        _asset,
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = const Color(0x00000000),
      );
      final ui.Picture picture = recorder.endRecording();
      _blank = picture.toImageSync(1, 1);
      picture.dispose();
      _program = program;
    } catch (error) {
      debugPrint('Liquid glass shader failed to load, using frost: $error');
    }
  }

  /// A shader for one surface to keep and reuse; null when not [ready].
  static ui.FragmentShader? create() =>
      ready ? _program!.fragmentShader() : null;

  /// Draws a liquid surface of [size] at [offset] on [canvas].
  ///
  /// [picture] is the backdrop, [pictureRect] this surface's rect in it, in
  /// the picture's logical coordinates; without them the surface is its tint
  /// and rim alone. [pxPerUnit] is how many physical pixels one unit of
  /// [size] covers — it keeps the edge and the hairline one pixel crisp.
  static void paint(
    ui.Canvas canvas,
    ui.FragmentShader shader, {
    required Offset offset,
    required Size size,
    required double pxPerUnit,
    required LiquidGlassSpec spec,
    ui.Image? picture,
    ui.Image? sharp,
    Size? pictureSize,
    Rect? pictureRect,
  }) {
    final ui.Image blank = _blank!;
    final bool hasBackdrop =
        picture != null &&
        pictureSize != null &&
        pictureRect != null &&
        !pictureSize.isEmpty;
    final List<double> floats = liquidGlassUniforms(
      offset: offset,
      size: size,
      pxPerUnit: pxPerUnit,
      spec: spec,
      pictureSize: hasBackdrop ? pictureSize : null,
      pictureRect: hasBackdrop ? pictureRect : null,
      hasSharp: hasBackdrop && sharp != null,
    );
    for (int i = 0; i < floats.length; i++) {
      shader.setFloat(i, floats[i]);
    }
    shader
      ..setImageSampler(
        0,
        hasBackdrop ? picture : blank,
        filterQuality: FilterQuality.low,
      )
      ..setImageSampler(
        1,
        hasBackdrop && sharp != null ? sharp : blank,
        filterQuality: FilterQuality.low,
      );
    // Out past the edge by the contour hairline and a pixel of antialiasing.
    final double bleed = 1.5;
    canvas.drawRect((offset & size).inflate(bleed), Paint()..shader = shader);
  }
}

/// The shader's float uniforms, in its declaration order. Pulled out so the
/// mapping can be tested without a GPU.
@visibleForTesting
List<double> liquidGlassUniforms({
  required Offset offset,
  required Size size,
  required double pxPerUnit,
  required LiquidGlassSpec spec,
  Size? pictureSize,
  Rect? pictureRect,
  bool hasSharp = false,
}) {
  final bool hasBackdrop = pictureSize != null && pictureRect != null;
  final Rect uv = hasBackdrop
      ? Rect.fromLTRB(
          pictureRect.left / pictureSize.width,
          pictureRect.top / pictureSize.height,
          pictureRect.right / pictureSize.width,
          pictureRect.bottom / pictureSize.height,
        )
      : const Rect.fromLTRB(0, 0, 1, 1);
  final LiquidGlassOptics o = spec.optics;
  final Color tint = spec.tint;
  return <double>[
    // uShape
    offset.dx, offset.dy, size.width, size.height,
    // uFrame
    spec.cornerRadius, pxPerUnit, spec.fade.clamp(0.0, 1.0),
    if (hasBackdrop) 1 else 0,
    // uPicture
    uv.left, uv.top, uv.right, uv.bottom,
    // uTint
    tint.r, tint.g, tint.b, tint.a,
    // uOptics
    o.refractionHeight, o.refractionAmount, o.dispersion, o.highlight,
    // uRim
    o.contourStrength, o.contourDirectionality, o.bevelShadowStrength,
    o.rimSharpness,
    // uExtra
    o.saturation, if (hasSharp) 1 else 0, o.highlightOpposite, 0,
    // uLens
    o.magnification, if (o.fitsShape) 1 else 0, 0, 0,
  ];
}
