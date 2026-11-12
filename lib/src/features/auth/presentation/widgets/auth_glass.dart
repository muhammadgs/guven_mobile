import 'package:flutter/material.dart';

import '../../../../shared/glass/app_glass.dart';
import '../../../../shared/layout.dart';

/// The two ends of the auth morph.
///
/// The start button and the login card are one surface at two moments, so
/// their looks are defined here together rather than next to the widgets
/// that draw them — the morph interpolates between these two constants and
/// they have to stay comparable for that to mean anything.

/// The pill the user taps. `cornerRadius` here is nominal — both the button
/// and the morph drive it from the live geometry (a capsule is always half
/// the height).
///
/// With no rim to outline it, the tint is what tells the button apart from
/// the video: the same ~15% white as the passcode keys on the same video.
const AppGlassStyle kStartCtaGlass = AppGlassStyle(
  cornerRadius: 40,
  glassColor: Color(0x26FFFFFF),
);

/// The card it becomes: a little clearer, so the form reads over it.
const AppGlassStyle kLoginCardGlass = AppGlassStyle(
  cornerRadius: 56,
  glassColor: Color(0x1FFFFFFF),
);

/// The small round back button beside the card.
const AppGlassStyle kAuthBackGlass = AppGlassStyle(
  cornerRadius: 23,
  glassColor: Color(0x26FFFFFF),
);

/// The ripple on the auth buttons: white, since they sit on a dark video.
const Color kAuthSplash = Color(0x33FFFFFF);

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
