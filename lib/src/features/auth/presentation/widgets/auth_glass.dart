import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../../../shared/layout.dart';

/// The two ends of the auth morph.
///
/// The start button and the login card are one surface at two moments, so
/// their looks are defined here together rather than next to the widgets
/// that draw them — the morph interpolates between these two constants and
/// they have to stay comparable for that to mean anything.
///
/// Both use the same corner curve. The card was a
/// [LiquidGlassCornerStyle.squircle] before the morph existed; a corner
/// *curve* cannot be interpolated, only swapped, so it now shares the
/// button's Apple-capsule curve and the flight runs on one shader path from
/// end to end. At a 56pt radius the two are near-indistinguishable.

/// The pill the user taps. `cornerRadius` here is nominal — both the button
/// and the morph drive it from the live geometry (a capsule is always half
/// the height).
const LiquidGlassStyle kStartCtaGlass = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 40,
    lightIntensity: 1.45,
    borderType: OpticalBorder(
      // Stands in for the old `ambientStrength`; solidity lets the high light
      // intensity brighten the rim the way the previous renderer did instead
      // of capping it at translucent.
      ambientIntensity: 0.60,
      borderSaturation: 1.15,
      borderSolidity: 0.45,
    ),
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x00FFFFFF),
    saturation: 1.25,
  ),
  refraction: LiquidGlassRefraction(
    distortion: 0.14,
    // Matches the old `thickness: 30` band around the perimeter.
    distortionWidth: 30,
    magnification: 1.04,
    chromaticAberration: 0.004,
  ),
);

/// The card it becomes: thicker glass, a wider bevel, a calmer rim.
const LiquidGlassStyle kLoginCardGlass = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 56,
    lightIntensity: 1.35,
    borderType: OpticalBorder(
      ambientIntensity: 0.55,
      borderSaturation: 1.10,
      borderSolidity: 0.40,
    ),
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x0DFFFFFF),
    saturation: 1.20,
  ),
  refraction: LiquidGlassRefraction(
    distortion: 0.12,
    magnification: 1.05,
    chromaticAberration: 0.006,
    // With a `refractionType` set, the optical band width wins and the legacy
    // `distortionWidth` is dead config — so it is not carried here.
    refractionType: OpticalRefraction(
      refraction: 1.45,
      refractionWidth: 45,
      depth: 0.16,
    ),
  ),
);

/// The small round back button beside the card.
///
/// Its own style rather than the pill's: at 46pt across, the pill's 30pt
/// distortion band would swallow the whole surface, so the band is pulled in
/// and the rim brightened to compensate for how little glass there is to light.
const LiquidGlassStyle kAuthBackGlass = LiquidGlassStyle(
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 23,
    lightIntensity: 1.50,
    borderType: OpticalBorder(
      ambientIntensity: 0.62,
      borderSaturation: 1.15,
      borderSolidity: 0.45,
    ),
  ),
  appearance: LiquidGlassAppearance(
    color: Color(0x0AFFFFFF),
    saturation: 1.25,
  ),
  refraction: LiquidGlassRefraction(
    distortion: 0.16,
    distortionWidth: 13,
    magnification: 1.06,
    chromaticAberration: 0.005,
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
