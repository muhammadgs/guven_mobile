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

// ── Yeni tapşırıq ─────────────────────────────────────────────────────────
//
// The chooser and the sheet are deliberately *not* given a glass of their own:
// they are one surface growing out of the `+` button, and the user asked for
// the filter's glass exactly — so [kTaskFilterGlass] is what they wear, and
// there is one set of Figma numbers on this screen rather than two that drift.

/// How dark the screen goes behind the open sheet, and how far it is blurred.
///
/// The chooser barely shades anything (it is a menu, and the list behind it is
/// still the subject); the sheet is a page in its own right and the design
/// pushes the task list well back behind it.
const Color kNewTaskMenuScrim = Color(0x14101826);
const Color kNewTaskSheetScrim = Color(0x66070C14);
const double kNewTaskSheetBlur = 14;

/// A field's box inside the sheet — a real lens, drawn by `liquid_glass_easy`.
///
/// It is a *small* lens sitting on a big one, so almost every number here is
/// held back from what the sheet itself wears: the sheet has already bent the
/// screen once and a second refraction at full strength on top of it reads as
/// a smear rather than as glass. What is left at full strength is easy's
/// optical border, which is the only thing that says "this is a box you can
/// press" on a surface with no fill of its own.
///
/// The light comes from −45°, the same corner as the sheet's, so the boxes and
/// the panel they sit in are lit by one source rather than two.
const AppGlassStyle kNewTaskFieldGlass = AppGlassStyle(
  cornerRadius: 23,
  settings: renderer.LiquidGlassSettings(
    thickness: 10,
    blur: 6,
    chromaticAberration: 0,
    lightAngle: -0.7853981633974483,
    lightIntensity: 1.0,
    ambientStrength: 0.28,
    refractiveIndex: 1.30,
    saturation: 1.05,
    // 101826 at 8%: barely a tint, enough that the box reads as a recess in
    // the sheet rather than a hole in it.
    glassColor: Color(0x14101826),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.03,
    distortionWidth: 14,
    magnification: 1.06,
    chromaticAberration: 0.0015,
    lightIntensity: 1.15,
    ambientIntensity: 0.9,
    borderSaturation: 1.2,
    borderSolidity: 0.45,
    // −45° in easy's degrees-clockwise convention.
    lightDirection: 315,
  ),
);

/// What a box is drawn as while the sheet is still flying.
///
/// Not a preference — a necessity. The sheet's contents cross-fade inside the
/// glass, and a fade is an `Opacity`, which opens a `saveLayer`. A lens under
/// one samples that empty layer and renders **black**
/// ([backdrop-filter-black-flash]). So for the few hundred milliseconds the
/// form is fading in, the boxes are this flat fill instead, and they become
/// lenses on the frame the flight lands. It is the same colour as
/// [kNewTaskFieldGlass]'s tint, so the swap is a rim appearing, not a colour
/// changing.
const Color kNewTaskFieldFill = Color(0x14101826);

/// What a field says once it has been answered.
const Color kNewTaskValueInk = Color(0xE6070C14);

/// …and while it has not.
const Color kNewTaskHintInk = Color(0x73101826);

/// The option list that grows out of a field.
///
/// Dark, per the design: it opens *over* the sheet rather than beside it, and
/// a pale panel on a pale panel leaves the eye nothing to separate them by.
/// The darkness is also what stops the two lenses reading as a double image —
/// this one keeps very little of the sheet's own refraction.
const AppGlassStyle kNewTaskPickerGlass = AppGlassStyle(
  cornerRadius: 26,
  settings: renderer.LiquidGlassSettings(
    thickness: 16,
    blur: 22,
    chromaticAberration: 0,
    lightAngle: -0.7853981633974483,
    lightIntensity: 1.15,
    ambientStrength: 0.18,
    refractiveIndex: 1.20,
    saturation: 1.1,
    // 141A24 at 84%: dark enough for white type, open enough that the sheet
    // behind it still moves.
    glassColor: Color(0xA0CACACA),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.04,
    distortionWidth: 22,
    magnification: 1.03,
    chromaticAberration: 0,
    lightIntensity: 1.3,
    ambientIntensity: 0.8,
    borderSaturation: 1.1,
    borderSolidity: 0.55,
    lightDirection: 315,
  ),
);

/// Type on the dark picker.
const Color kNewTaskPickerInk = Color(0xFF000000);
const Color kNewTaskPickerInkMuted = Color(0xFF000000);

/// The capsule under the option that is already chosen.
const Color kNewTaskPickerRowFill = Color(0x1FFFFFFF);

/// The two buttons at the foot of the sheet, in the design's own stops.
const List<Color> kNewTaskCancelGradient = <Color>[
  Color(0xFFFE8750),
  Color(0xFFFF0048),
];
const List<Color> kNewTaskSubmitGradient = <Color>[
  Color(0xFF2BF07E),
  Color(0xFF00E0EB),
];

/// The waveform of a voice note: the part already played, and the part not.
const Color kVoiceWaveLive = Color(0xFF2E9BF0);
const Color kVoiceWaveRest = Color(0x662E9BF0);

/// The recorder's own controls — delete, pause, send, microphone.
const Color kVoiceControlInk = Color(0xFF2E9BF0);
const Color kVoiceDeleteInk = Color(0xFF6B7684);
