/// The signed-in app's glass palette.
///
/// A separate set from `auth_glass.dart`, and not a tweak of it: those
/// surfaces sit on a dark video and carry white text, these sit on a pale
/// still backdrop and carry black.
library;

import 'package:flutter/material.dart';

import '../../../../shared/glass/app_glass.dart';

/// Every style below carries a nominal corner radius, and every surface that
/// wears one drives the real radius from its own measured geometry — so the
/// helper that swaps it in comes with the palette rather than being fetched
/// separately at each call site.
export '../../../../shared/glass/app_glass.dart'
    show
        AppGlassButton,
        AppGlassLayer,
        AppGlassStyle,
        AppGlassSurface,
        glassAtRadius,
        lerpAppGlassStyle;

/// Everything printed on this app's glass.
///
/// One near-black rather than pure black: at these type sizes pure black on a
/// bright translucent surface vibrates.
const Color kGlassInk = Color(0xFF0C1017);

/// The second line of an activity row, and any other supporting text.
const Color kGlassInkMuted = Color(0xB2121A26);

/// A stat row — `Əməkdaşlarım · 12`.
///
/// The widest surfaces on the screen and the ones the eye lands on first, so
/// they carry the most tint and the brightest rim of anything here.
const AppGlassStyle kStatPillGlass = AppGlassStyle(
  cornerRadius: 30,
  glassColor: Color(0x0F000000),
  blur: 2,
);

/// The tray the activity rows sit in.
///
/// Faint on purpose. It is a surface *under* other surfaces, and every point
/// of tint it adds is one the rows above have to out-shout to stay legible.
const AppGlassStyle kActivityTrayGlass = AppGlassStyle(
  cornerRadius: 38,
  glassColor: Color(0x0F000000),
  blur: 3,
);

/// One activity inside that tray.
///
/// Frosted glass over frosted glass. Six of these sit stacked a few points
/// apart, so the rim is what tells them apart at all.
const AppGlassStyle kActivityRowGlass = AppGlassStyle(
  cornerRadius: 26,
  glassColor: Color(0x42FFFFFF),
  blur: 0,
);

/// The bottom bar's capsule: see-through glass with the activity rows' tint.
/// Until 2026-11-13 it was 56% white, which read as a solid white bar.
const AppGlassStyle kNavBarGlass = AppGlassStyle(
  cornerRadius: 34,
  glassColor: Color(0x42FFFFFF),
  blur: 1.5,
);

/// The lens a touch turns the selection marker into: clear glass — nothing
/// frosts it — that magnifies the bar under it and bends it at its rim, the
/// colours splitting there. It shows a photograph of the bar taken as the
/// touch lands, so no frame reads the live screen.
///
/// After `liquid_glass_renderer`'s iOS 27 loupe tab bar (refraction 15, clear,
/// dispersion −0.3, contour 0.3), magnified like iOS 26's. Bent 18 with the
/// full −0.3 on the emulator, the rim folded the names into rainbow blots;
/// 11 and −0.2 keep the fold and the fringe, thin.
const LiquidGlassOptics kNavLensOptics = LiquidGlassOptics(
  refractionHeight: 15,
  refractionAmount: 11,
  fitsShape: false,
  dispersion: -0.2,
  highlight: 1,
  contourStrength: 0.3,
  bevelShadowStrength: 0,
  rimSharpness: 0,
  magnification: 1.18,
);

/// Barely there: the lens is clear.
const Color kNavLensTint = Color(0x0AFFFFFF);

/// What marks the selected cell when nothing is being touched.
///
/// A plain fill, painted *under* the glyphs so they stay black on white.
const Color kNavIndicatorRestFill = Color(0xFFD3D3D3);

/// Cast by the stat rows and the nav bar.
///
/// Short and tight rather than deep: these surfaces lie *on* the background,
/// unlike the login card, which floats well above it.
const List<BoxShadow> kGlassLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x1A2B4A7A),
    blurRadius: 22,
    spreadRadius: -10,
    offset: Offset(0, 10),
  ),
];

/// Under the activity tray — wider and softer, because it is a bigger object.
const List<BoxShadow> kTrayLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x14264872),
    blurRadius: 34,
    spreadRadius: -16,
    offset: Offset(0, 16),
  ),
];
