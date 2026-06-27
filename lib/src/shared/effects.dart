import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Wraps [child] in a gaussian blur of the given [sigma].
///
/// Sigmas at or below ~0.2 are treated as "no blur" and the child is returned
/// untouched — this both avoids a needless layer and sidesteps the visual
/// artefacts `ImageFilter.blur` produces at a sigma of exactly 0.
Widget blurred(double sigma, Widget child) {
  if (sigma <= 0.2) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
