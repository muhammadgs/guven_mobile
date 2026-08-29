/// The Tapşırıqlar screen's own palette.
///
/// It borrows the signed-in app's ink and lift from `home_glass.dart` — the
/// two screens sit on the same background and must read as the same app — but
/// the surfaces here are different in kind. The cards are *not* lenses: the
/// design asks for a flat mint fill over a plain background blur, and only the
/// scope indicator and the two tool buttons are real glass.
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

import '../../../../shared/glass/app_glass.dart';

export '../../../home/presentation/widgets/home_glass.dart'
    show
        AppGlassBackend,
        AppGlassFlex,
        AppGlassStyle,
        AppGlassSurface,
        glassAtRadius,
        kGlassInk,
        kGlassInkMuted,
        kGlassLift,
        kNavIndicatorGlass,
        kNavIndicatorRestFill,
        lerpAppGlassStyle;

/// The card's fill: the design's `D5F3F2`, held back to a little over half
/// opacity so the blurred background still moves under it. At full opacity the
/// card is a flat mint rectangle and the blur below it is wasted.
const Color kTaskCardFill = Color(0x94D5F3F2);

/// Blur under a card.
///
/// The design says 15. Figma measures a background blur by its kernel and
/// Flutter by the gaussian's sigma, which is about half of it — this is that
/// 15 converted, and the knob to turn if the cards read too crisp or too soft.
const double kTaskCardBlurSigma = 7.5;

/// The card's corner, on the phone canvas.
const double kTaskCardRadius = 24;

/// The scope bar itself: flat grey, no glass. Only the marker travelling
/// across it is a lens.
const Color kScopeBarFill = Color(0xFFEDEFF0);

/// The hairline around that bar, so it still reads as a container on the
/// palest part of the background.
const Color kScopeBarBorder = Color(0x14202B3A);

/// An unselected cell's icon and label.
const Color kScopeInkMuted = Color(0x8C121A26);

/// The ink on a card's description — a step down from the headline without
/// going grey, which at this size would read as disabled.
const Color kTaskBodyInk = Color(0xCC0C1017);

/// Printed on the gradient buttons and the status chips. Both sit on
/// saturated colour, so this is the app's ink rather than white: the design's
/// buttons carry dark labels.
const Color kTaskButtonInk = Color(0xFF10151C);

/// Under a card. Barely there — the cards are close together and a deep
/// shadow on each one turns the list grey between them.
const List<BoxShadow> kTaskCardLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x142B4A7A),
    blurRadius: 18,
    spreadRadius: -8,
    offset: Offset(0, 8),
  ),
];

/// The filter and new-task buttons.
///
/// Small, round, and sitting on the bare background rather than on another
/// surface, so they carry more tint and a more solid rim than the wide
/// surfaces on the home screen do — at this size there is very little backdrop
/// inside the shape for the refraction to bend.
///
/// Drawn by `liquid_glass_easy`, like the two travelling indicators: its
/// optical border derives the rim from the shape's own SDF instead of tinting
/// it with the backdrop, and a 44pt circle on a pale background is the case
/// the renderer's backdrop-tinted highlight has least to work with.
const AppGlassStyle kTaskToolGlass = AppGlassStyle(
  cornerRadius: 22,
  settings: renderer.LiquidGlassSettings(
    thickness: 12,
    blur: 0,
    chromaticAberration: 0.30,
    lightIntensity: 1.20,
    ambientStrength: 0.50,
    refractiveIndex: 2.60,
    saturation: 1.05,
    glassColor: Color(0x1F000000),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.02,
    distortionWidth: 14,
    magnification: 1.18,
    chromaticAberration: 0.002,
    lightIntensity: 1.28,
    ambientIntensity: 1,
    borderSaturation: 1.35,
    borderSolidity: 0.5,
    lightDirection: 80,
  ),
);

/// The filter panel's glass — the design's Figma numbers, converted.
///
/// The Figma layer is a white fill at 79% under a Glass effect set to
/// Refraction 80, Depth 19, Dispersion 0, Frost 27, light at −45° and 80%.
/// `liquid_glass_renderer` publishes the mapping for exactly those five knobs
/// (`LiquidGlassSettings.figma`), so the numbers below are its arithmetic
/// written out as constants rather than a guess:
///
/// * refraction 80 → `refractiveIndex` 1 + 0.80 × 0.2 = 1.16
/// * depth 19     → `thickness` 19
/// * dispersion 0 → `chromaticAberration` 0
/// * frost 27     → `blur` 27
/// * light 80%    → `lightIntensity` 0.80, at −45° = −π/4
///
/// That `blur` is the loud one — 27 is a heavy frost and it is the single
/// knob to turn if the panel reads too soft over the task list. It is *not*
/// the same conversion as [kTaskCardBlurSigma]: that one comes from Figma's
/// plain background-blur effect, which is measured as a kernel and halves,
/// while Frost is the glass effect's own dial and maps across one to one.
///
/// Drawn by `liquid_glass_easy`, like the button it grows out of. A panel this
/// white on a background this pale has almost no backdrop left for the
/// renderer's edge highlight to tint, and a menu the eye cannot find the edge
/// of is not a menu — easy's optical border derives the rim from the shape
/// instead. Keeping both ends of the morph on one backend also means the
/// flight never swaps renderer mid-air.
const AppGlassStyle kTaskFilterGlass = AppGlassStyle(
  cornerRadius: 30,
  settings: renderer.LiquidGlassSettings(
    thickness: 19,
    blur: 27,
    chromaticAberration: 0,
    lightAngle: -0.7853981633974483,
    lightIntensity: 0.80,
    ambientStrength: 0.10,
    refractiveIndex: 1.16,
    saturation: 1.5,
    // FFFFFF at 79%.
    glassColor: Color(0xC9FFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    // A wide surface bends its backdrop over a wide edge band, so the
    // distortion is spread rather than deepened: the same optical strength as
    // the tool button would read as a fish-eye at this size.
    distortion: 0.05,
    distortionWidth: 26,
    magnification: 1.04,
    chromaticAberration: 0,
    lightIntensity: 1.05,
    ambientIntensity: 0.9,
    borderSaturation: 1.25,
    borderSolidity: 0.42,
    // −45° in easy's degrees-clockwise convention.
    lightDirection: 315,
  ),
);

/// Under the filter panel. Deeper than [kGlassLift]: this one floats over the
/// whole screen rather than sitting in the layout, and the shadow is most of
/// what says so.
const List<BoxShadow> kTaskFilterLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x2E1B3055),
    blurRadius: 40,
    spreadRadius: -12,
    offset: Offset(0, 18),
  ),
];

/// A filter row that is doing something — the selected column, and a value
/// that is ticked. Glass over glass would muddy both, so the marker is a plain
/// white capsule, the way the design draws it.
const Color kTaskFilterRowFill = Color(0x8FFFFFFF);

/// The ink on a filter row that is not selected.
const Color kTaskFilterRowInk = Color(0xD90C1017);

/// The count on a column that is narrowing the list, and on the filter button
/// itself. The site marks an active column in blue and so does this.
const Color kTaskFilterBadge = Color(0xFF4AB6FF);
