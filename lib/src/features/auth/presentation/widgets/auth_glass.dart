import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

import '../../../../shared/glass/app_glass.dart';
import '../../../../shared/layout.dart';

/// The two ends of the auth morph.
///
/// The start button and the login card are one surface at two moments, so
/// their looks are defined here together rather than next to the widgets
/// that draw them — the morph interpolates between these two constants and
/// they have to stay comparable for that to mean anything.
///
/// Both use the renderer's rounded superellipse, so the flight stays on one
/// shape path from end to end.

/// The pill the user taps. `cornerRadius` here is nominal — both the button
/// and the morph drive it from the live geometry (a capsule is always half
/// the height).
const AppGlassStyle kStartCtaGlass = AppGlassStyle(
  cornerRadius: 40,
  settings: renderer.LiquidGlassSettings(
    thickness: 34,
    blur: 0,
    chromaticAberration: 0.4,
    lightIntensity: 1.45,
    ambientStrength: 0.60,
    refractiveIndex: 1.42,
    saturation: 1.25,
    glassColor: Color(0x00FFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.14,
    distortionWidth: 30,
    magnification: 1.04,
    chromaticAberration: 0.004,
    lightIntensity: 1.45,
    ambientIntensity: 0.60,
    borderSaturation: 1.15,
    borderSolidity: 0.45,
  ),
);

/// The card it becomes: thicker glass, a wider bevel, a calmer rim.
const AppGlassStyle kLoginCardGlass = AppGlassStyle(
  cornerRadius: 56,
  settings: renderer.LiquidGlassSettings(
    thickness: 48,
    blur: 0,
    chromaticAberration: 0.6,
    lightIntensity: 1.35,
    ambientStrength: 0.55,
    refractiveIndex: 1.50,
    saturation: 1.20,
    glassColor: Color(0x0DFFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.12,
    distortionWidth: 45,
    magnification: 1.05,
    chromaticAberration: 0.006,
    lightIntensity: 1.35,
    ambientIntensity: 0.55,
    borderSaturation: 1.10,
    borderSolidity: 0.40,
    refractionIndex: 1.45,
    refractionDepth: 0.16,
  ),
);

/// The small round back button beside the card.
///
/// Its own style rather than the pill's: at 46pt across, the pill's 30pt
/// distortion band would swallow the whole surface, so the band is pulled in
/// and the rim brightened to compensate for how little glass there is to light.
const AppGlassStyle kAuthBackGlass = AppGlassStyle(
  cornerRadius: 23,
  settings: renderer.LiquidGlassSettings(
    thickness: 16,
    blur: 0,
    chromaticAberration: 0.5,
    lightIntensity: 1.50,
    ambientStrength: 0.62,
    refractiveIndex: 1.45,
    saturation: 1.25,
    glassColor: Color(0x0AFFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.16,
    distortionWidth: 13,
    magnification: 1.06,
    chromaticAberration: 0.005,
    lightIntensity: 1.50,
    ambientIntensity: 0.62,
    borderSaturation: 1.15,
    borderSolidity: 0.45,
  ),
);

/// Drop shadow under the pill.
const List<BoxShadow> kStartCtaShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x36000000),
    blurRadius: 28,
    spreadRadius: -8,
    offset: Offset(0, 16),
  ),
];

/// Drop shadow under the card — deeper, because the card sits higher off the
/// backdrop. Lerped from [kStartCtaShadow] across the flight.
const List<BoxShadow> kLoginCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x52000000),
    blurRadius: 42,
    spreadRadius: -12,
    offset: Offset(0, 26),
  ),
];

/// Shallower than the card's — a 46pt control does not sit that far off the
/// backdrop.
const List<BoxShadow> kAuthBackShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x30000000),
    blurRadius: 18,
    spreadRadius: -6,
    offset: Offset(0, 8),
  ),
];

/// Type size of the start button's label.
///
/// Lives here because the morph re-draws that label inside the card's glass
/// and the two have to be the same size to the pixel, or the hand-off shows.
double startCtaFontSize(BuildContext context) =>
    responsive(context, factor: 0.075, min: 28, max: 40);

/// The start button's label, wherever it is being drawn.
class StartCtaLabel extends StatelessWidget {
  const StartCtaLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Başlayın',
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'CalSans',
        fontSize: startCtaFontSize(context),
        fontWeight: FontWeight.w400,
        height: 1,
        letterSpacing: -0.7,
      ),
    );
  }
}
