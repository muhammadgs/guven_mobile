import 'package:flutter/material.dart';

import '../../../shared/glass/app_glass.dart';

/// The passcode screens' glass and type.
///
/// Plain frosted glass like the rest of the app (`AppGlassSurface`); the
/// corner radius is set where each round key is laid out.

/// A key at rest: clear glass over the video, the backdrop lifted by about
/// 15% white.
const AppGlassStyle kPasscodeKeyGlass = AppGlassStyle(
  cornerRadius: 0,
  glassColor: Color(0x26FFFFFF),
);

/// An empty dot: the same clear glass.
const AppGlassStyle kPasscodeDotGlass = AppGlassStyle(
  cornerRadius: 0,
  glassColor: Color(0x1FFFFFFF),
);

/// A filled dot: plain white glass ("adi ağ rəngli glass").
const AppGlassStyle kPasscodeDotFilledGlass = AppGlassStyle(
  cornerRadius: 0,
  glassColor: Color(0xF2FFFFFF),
);

/// `Aktivləşdir` — the one solid call to action, white glass like a full dot.
const AppGlassStyle kPasscodeAcceptGlass = AppGlassStyle(
  cornerRadius: 0,
  glassColor: Color(0xE6FFFFFF),
);

/// Between [kPasscodeDotGlass] (0) and [kPasscodeDotFilledGlass] (1).
AppGlassStyle passcodeDotGlass(double fill) => lerpAppGlassStyle(
  kPasscodeDotGlass,
  kPasscodeDotFilledGlass,
  fill.clamp(0.0, 1.0),
);

/// The ripple on a key: bright enough to read over the dark video, not so
/// bright that the white digit drowns in it.
const Color kPasscodeKeySplash = Color(0x33FFFFFF);

/// Dark ink for text on white glass.
const Color kPasscodeInk = Color(0xFF0E3A52);

TextStyle passcodeTitleStyle(double size) => TextStyle(
  fontFamily: 'CalSans',
  fontSize: size,
  height: 1.2,
  color: Colors.white,
  letterSpacing: 0,
);

TextStyle passcodeSubtitleStyle(double size) => TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w400,
  fontSize: size,
  height: 1.3,
  color: Colors.white,
);

TextStyle passcodeDigitStyle(double size) => TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w300,
  fontSize: size,
  height: 1.0,
  color: Colors.white,
);

/// No colour: a text key sets it, so it can dim the label under the finger.
TextStyle passcodeSideLabelStyle(double size, double lineHeight) => TextStyle(
  fontFamily: 'Poppins',
  fontWeight: FontWeight.w400,
  fontSize: size,
  height: lineHeight,
);
