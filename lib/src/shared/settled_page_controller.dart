import 'package:flutter/widgets.dart';

/// A [PageController] that remembers the last page it was able to measure.
///
/// [PageController.page] has no answer on any frame where the viewport has not
/// applied its dimensions — `position.haveDimensions` is false — and that is
/// not a rare edge. It happens on the first frame after the screen is rebuilt,
/// which the onboarding does every time a route is pushed over it and again
/// when that route pops back off.
///
/// Falling back to the initial page there is what makes every page-driven
/// widget — the brand lockup, the headline, the dots, the swipe arrow — snap
/// to its page-0 look for a frame or two on the way into the login screen and
/// on the way back out. Worse, nothing scrolls afterwards, so no listener ever
/// fires to correct it: a widget that reads the page only on that frame stays
/// wrong for good.
///
/// [settledPage] answers with the last measured page instead, which is the
/// truth of the matter — the controller has not moved, it has only lost its
/// ruler for a frame.
class SettledPageController extends PageController {
  SettledPageController({
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
  });

  double? _settled;

  /// The current page, or — while the viewport is unmeasured — the last one
  /// this controller could report.
  double get settledPage {
    if (hasClients && position.haveDimensions) {
      return _settled = page ?? _settled ?? initialPage.toDouble();
    }
    return _settled ?? initialPage.toDouble();
  }
}
