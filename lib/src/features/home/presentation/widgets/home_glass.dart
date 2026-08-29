/// The signed-in app's glass palette.
///
/// A separate set from `auth_glass.dart`, and not a tweak of it: those lenses
/// sit on a dark video and carry white text, these sit on a pale still
/// backdrop and carry black. On light ground a lens has almost no contrast to
/// work with, so the tint is stronger, the rim more solid and the refraction
/// band narrower — otherwise the surfaces read as slightly grubby rectangles
/// rather than glass.
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

import '../../../../shared/glass/app_glass.dart';

/// Every style below carries a nominal corner radius, and every surface that
/// wears one drives the real radius from its own measured geometry — so the
/// helper that swaps it in comes with the palette rather than being fetched
/// separately at each call site.
export '../../../../shared/glass/app_glass.dart'
    show
        AppGlassBackend,
        AppGlassFlex,
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
  settings: renderer.LiquidGlassSettings(
    // `thickness` widens the curved optical band at the edge; the higher
    // refractive index makes the backdrop visibly turn through that band.
    // Together these create the inward corner bend from the reference.
    thickness: 27,
    blur: 2,
    chromaticAberration: 0.16,
    lightIntensity: 1.25,
    ambientStrength: 0.52,
    refractiveIndex: 1.42,
    saturation: 1.12,
    glassColor: Color(0x0F000000),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.10,
    distortionWidth: 22,
    magnification: 1.03,
    chromaticAberration: 0.003,
    lightIntensity: 1.25,
    ambientIntensity: 0.52,
    borderSaturation: 1.05,
    borderSolidity: 0.55,
  ),
);

/// The tray the activity rows sit in.
///
/// Faint on purpose. It is a surface *under* other surfaces, and every point
/// of tint it adds is one the rows above have to out-shout to stay legible.
const AppGlassStyle kActivityTrayGlass = AppGlassStyle(
  cornerRadius: 38,
  settings: renderer.LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.14,
    lightIntensity: 1.10,
    ambientStrength: 0.42,
    refractiveIndex: 1.38,
    saturation: 1.08,
    glassColor: Color(0x0F000000),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.07,
    distortionWidth: 30,
    magnification: 1.02,
    chromaticAberration: 0.002,
    lightIntensity: 1.10,
    ambientIntensity: 0.42,
    borderSaturation: 1.02,
    borderSolidity: 0.34,
  ),
);

/// One activity inside that tray.
///
/// A lens over a lens: its refraction band is pulled in to 16pt so it bends
/// the tray's own rim rather than restating it, which is what keeps the two
/// layers from reading as one thick edge.
///
/// Drawn by `liquid_glass_easy`, for the same reason as
/// [kNavIndicatorGlass] — its optical border derives the rim from the shape's
/// own SDF instead of colouring it with the backdrop, and a row's backdrop is
/// the tray: pale glass on a pale background, which is the case the renderer's
/// backdrop-tinted highlight has least to work with. Six of these sit stacked
/// a few points apart, so the rim is what tells them apart at all.
///
/// The light comes in at 80°, the same near-vertical angle the nav indicator
/// uses — two surfaces on one screen lit from two directions read as a
/// mistake. The band stays at 16pt and the border a little softer than the
/// indicator's: the row is a resting surface, not a held one.
///
/// [settings] is read for the tint, blur and saturation the easy backend
/// shares; `thickness`, `refractiveIndex`, `lightIntensity`, `ambientStrength`
/// and its `chromaticAberration` are renderer-only and inert while the row
/// stays on this backend.
const AppGlassStyle kActivityRowGlass = AppGlassStyle(
  cornerRadius: 26,
  settings: renderer.LiquidGlassSettings(
    thickness: 20,
    blur: 0,
    chromaticAberration: 0.10,
    lightIntensity: 4.22,
    ambientStrength: 0.48,
    refractiveIndex: 15.04,
    saturation: 1.10,
    glassColor: Color(0x42FFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.07,
    distortionWidth: 26,
    magnification: 1.02,
    chromaticAberration: 0.002,
    lightIntensity: 1.22,
    ambientIntensity: 1,
    borderSaturation: 1.2,
    borderSolidity: 0.45,
    lightDirection: 80,
  ),
);

/// The bottom bar's capsule.
const AppGlassStyle kNavBarGlass = AppGlassStyle(
  cornerRadius: 34,
  settings: renderer.LiquidGlassSettings(
    thickness: 27,
    blur: 1.5,
    chromaticAberration: 0.16,
    lightIntensity: 1.28,
    ambientStrength: 0.55,
    refractiveIndex: 1.40,
    saturation: 1.14,
    glassColor: Color(0x80FFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.09,
    distortionWidth: 24,
    magnification: 1.03,
    chromaticAberration: 0.003,
    lightIntensity: 1.28,
    ambientIntensity: 0.55,
    borderSaturation: 1.06,
    borderSolidity: 0.52,
  ),
);

/// The small lens that travels between navigation cells.
///
/// It only exists while a finger is on the bar. Parked, the selected cell is
/// [kNavIndicatorRestFill] and nothing else — no shader, no rim, no cost. The
/// touch swells that flat marker into this lens and it stays one until the
/// finger lifts, which is the behaviour iOS's own tab bar has.
///
/// The one surface in the app pinned to `liquid_glass_easy` rather than the
/// renderer — see `AppGlassBackend.easy` at its call site. The values in
/// [legacy] are that package's own bottom-nav pill, taken as it ships them:
/// a narrow 10pt refraction band, a light coming in near-vertically at 80°,
/// and an optical border that derives its rim from the glass shape's own SDF
/// instead of tinting it with whatever is behind. That last part is why it is
/// here at all. The renderer scales its edge highlight by `40 / thickness`
/// and then colours it with the backdrop it bends, which over this app's pale
/// still background is white on white — the travelling capsule had no visible
/// border of its own and needed one painted over the top.
///
/// [settings] is read for the tint, blur and saturation the easy backend
/// shares; `thickness` and `refractiveIndex` are renderer-only and inert
/// while the indicator stays on this backend.
const AppGlassStyle kNavIndicatorGlass = AppGlassStyle(
  cornerRadius: 28,
  settings: renderer.LiquidGlassSettings(
    thickness: 10,
    blur: 0,
    chromaticAberration: 0.45,
    lightIntensity: 1.15,
    refractiveIndex: 3.62,
    ambientStrength: 0.45,
    saturation: 1,
    // Light. A tint is opacity, and opacity is exactly how much of the
    // refraction underneath gets thrown away — a near-solid fill here would
    // mask off most of what the shader draws and leave a flat shape with no
    // border. This is the knob for how glassy the held capsule reads.
    glassColor: Color(0x1CFFFFFF),
  ),
  legacy: AppGlassLegacyTuning(
    distortion: 0.01,
    distortionWidth: 15,
    magnification: 1.3,
    chromaticAberration: 0.002,
    lightIntensity: 1.3,
    ambientIntensity: 1,
    borderSaturation: 1.4,
    borderSolidity: 0.5,
    lightDirection: 80,
  ),
);

/// What marks the selected cell when nothing is being touched.
///
/// A plain fill, painted *under* the glyphs so they stay black on white, and
/// deliberately not glass: the effect is off until a finger asks for it. Fades
/// out as [kNavIndicatorGlass] swells in over the top.
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
