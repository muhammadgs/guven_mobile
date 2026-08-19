import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';
import 'widgets/animated_logo.dart';

/// The one place that decides where anything on the onboarding sits.
///
/// The brand lockup and the "GF44" headline float *above* the `PageView` —
/// they have to, because they travel between pages while the pages themselves
/// slide past underneath. What broke was not that arrangement but that the two
/// layers each ran their own arithmetic: the floating layer anchored off
/// `screen.height` fractions, while every page body centred itself in the
/// space left after subtracting a hand-tuned "reserve" that stood in for the
/// logo's height.
///
/// Those two formulas answer to the device differently. Differentiate them and
/// a page body moves by ½ px per px of screen height and by a whole px per px
/// of bottom inset, while the floating layer moves by 0.305 px and by nothing
/// at all. So a phone 20pt shorter than the canvas, or one drawing a 48pt
/// three-button navigation bar where the canvas had a 34pt home indicator,
/// pulled the layers through each other — the subtitle landing on the
/// wordmark, the paragraph on the headline, the start button on the logo.
///
/// Now there is one coordinate system. Every anchor is a fraction of the
/// *usable band* — the strip between the status bar and the page indicator —
/// so system insets move the whole composition as one piece; and every page
/// body is positioned below a **measured** bottom edge
/// ([BrandLockupGeometry.bottom], [Gf44HeadlineGeometry.bottom]) rather than
/// below a guess at one. A body can no longer overlap what sits above it, at
/// any screen size or font scale, because it is laid out from that thing's
/// real edge.
@immutable
class OnboardingMetrics {
  const OnboardingMetrics._({
    required this.safeTop,
    required this.floor,
    required this.scale,
    required this.textScaler,
    required this.startLogoWidth,
    required this.compactLogoWidth,
    required this.finalLogoWidth,
    required this.startBrandSize,
    required this.compactBrandSize,
    required this.headlineSize,
    required this.headlineSubtitleSize,
  });

  factory OnboardingMetrics.of(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double scale = uiScale(context);

    return OnboardingMetrics._(
      safeTop: padding.top,
      floor: size.height - kBottomReserve * scale - padding.bottom,
      scale: scale,
      textScaler: MediaQuery.textScalerOf(context),
      startLogoWidth: responsive(context, factor: 0.58, min: 190, max: 270),
      compactLogoWidth: responsive(context, factor: 0.33, min: 116, max: 158),
      finalLogoWidth: responsive(context, factor: 0.48, min: 176, max: 232),
      startBrandSize: responsive(context, factor: 0.092, min: 30, max: 42),
      compactBrandSize: responsive(context, factor: 0.064, min: 22, max: 30),
      headlineSize: responsive(context, factor: 0.13, min: 42, max: 58),
      headlineSubtitleSize: responsive(context, factor: 0.047, min: 16, max: 21),
    );
  }

  /// Vertical space the page indicator and swipe arrow own at the bottom, on
  /// the phone canvas. That stack is 36 + ~78 tall; the rest is clearance, so
  /// a body reaching [floor] still does not crowd the dots.
  static const double kBottomReserve = 132;

  /// Top of the usable band — below the status bar.
  final double safeTop;

  /// Bottom of the usable band — above the page indicator.
  final double floor;

  final double scale;
  final TextScaler textScaler;

  final double startLogoWidth;
  final double compactLogoWidth;
  final double finalLogoWidth;
  final double startBrandSize;
  final double compactBrandSize;
  final double headlineSize;
  final double headlineSubtitleSize;

  /// Height of the strip every anchor below is a fraction of.
  ///
  /// Because both ends are inset-aware, a taller status bar or a three-button
  /// navigation bar shortens the band and shifts *every* anchor by the same
  /// proportion, rather than moving the page bodies while the floating layer
  /// stands still.
  double get band => floor - safeTop;

  /// Resolves a phone-canvas spacing without needing a `BuildContext`.
  double px(double phoneValue) => phoneValue * scale;

  /// Height one line of [fontSize] actually occupies, including the system
  /// font scale. Reserving unscaled heights is what let a phone set to large
  /// type push a paragraph out from under its own anchor.
  double lineHeight(double fontSize, double heightFactor) =>
      textScaler.scale(fontSize) * heightFactor;

  /// Where the logo and wordmark sit at a (possibly fractional) [page].
  BrandLockupGeometry lockupAt(double page) {
    final double toCompact =
        Curves.easeInOutCubic.transform(page.clamp(0.0, 1.0).toDouble());
    final double toFinal =
        Curves.easeInOutCubic.transform((page - 2).clamp(0.0, 1.0).toDouble());

    final double logoWidth = _lerp(
      _lerp(startLogoWidth, compactLogoWidth, toCompact),
      finalLogoWidth,
      toFinal,
    );

    return BrandLockupGeometry(
      top: _lerp(
        _lerp(_anchor(_kLockupStart), _anchor(_kLockupCompact), toCompact),
        _anchor(_kLockupFinal),
        toFinal,
      ),
      logoWidth: logoWidth,
      logoHeight: logoWidth / AnimatedGuvenLogo.aspectRatio,
      gap: px(_lerp(14, 6, toCompact)),
      brandSize: _lerp(startBrandSize, compactBrandSize, toCompact),
      // The wordmark fades out over the last swipe, so its slot has to leave
      // the layout at the same rate — otherwise the start button would anchor
      // below a line that is no longer being drawn.
      brandSlot: 1 - toFinal,
      brandLetterSpacing: _lerp(-0.7, -0.45, toCompact),
      metrics: this,
    );
  }

  /// Where the "GF44" headline and its subtitle sit at a [page].
  Gf44HeadlineGeometry headlineAt(double page) {
    final double toDataHub =
        Curves.easeInOutCubic.transform((page - 1).clamp(0.0, 1.0).toDouble());

    return Gf44HeadlineGeometry(
      top: _lerp(
        _anchor(_kHeadlineOverview),
        _anchor(_kHeadlineDataHub),
        toDataHub,
      ),
      headlineSize: headlineSize,
      subtitleSize: headlineSubtitleSize,
      gap: px(10),
      // The two-line subtitle only joins the layout on the data-hub page.
      subtitleSlot: toDataHub,
      metrics: this,
    );
  }

  /// Top edge of each page's body, measured from the floating layer above it.
  ///
  /// These live here, next to the geometry they are derived from, so the
  /// invariant that matters — *a body starts below the thing it sits under* —
  /// is one comparison on one object rather than a coincidence between two
  /// files. `test/onboarding_metrics_test.dart` asserts it across a matrix of
  /// screen sizes, insets and font scales.
  double get welcomeBodyTop => lockupAt(0).bottom + px(10);

  double get overviewBodyTop => headlineAt(1).bottom + px(20);

  double get dataHubBodyTop => headlineAt(2).bottom + px(28);

  double get startCtaTop => lockupAt(3).bottom + px(40);

  /// Fractions of [band], not of the raw screen height.
  ///
  /// The values reproduce the phone-canvas composition — they were solved from
  /// the anchors this screen already shipped — but unlike those anchors they
  /// carry no absolute pixel clamps, so nothing saturates and stops tracking
  /// the screen while its neighbours keep moving.
  static const double _kLockupStart = 0.333;
  static const double _kLockupCompact = 0.094;
  static const double _kLockupFinal = 0.401;
  static const double _kHeadlineOverview = 0.454;
  static const double _kHeadlineDataHub = 0.367;

  double _anchor(double fraction) => safeTop + band * fraction;
}

/// The measured box the logo and wordmark occupy.
@immutable
class BrandLockupGeometry {
  const BrandLockupGeometry({
    required this.top,
    required this.logoWidth,
    required this.logoHeight,
    required this.gap,
    required this.brandSize,
    required this.brandSlot,
    required this.brandLetterSpacing,
    required this.metrics,
  });

  final double top;
  final double logoWidth;
  final double logoHeight;

  /// Space between the logo and the wordmark.
  final double gap;
  final double brandSize;

  /// How much of the wordmark's line is still part of the layout: 1 while it
  /// is shown, easing to 0 as it fades out on the final page.
  final double brandSlot;
  final double brandLetterSpacing;
  final OnboardingMetrics metrics;

  static const double _lineFactor = 1.05;

  double get logoBottom => top + logoHeight;

  /// The edge a page body anchors below.
  double get bottom =>
      logoBottom + gap + metrics.lineHeight(brandSize, _lineFactor) * brandSlot;
}

/// The measured box the "GF44" headline and its subtitle occupy.
@immutable
class Gf44HeadlineGeometry {
  const Gf44HeadlineGeometry({
    required this.top,
    required this.headlineSize,
    required this.subtitleSize,
    required this.gap,
    required this.subtitleSlot,
    required this.metrics,
  });

  final double top;
  final double headlineSize;
  final double subtitleSize;
  final double gap;

  /// 0 on the overview page, 1 on the data-hub page.
  final double subtitleSlot;
  final OnboardingMetrics metrics;

  /// The subtitle is written with an explicit newline.
  static const int _subtitleLines = 2;
  static const double _subtitleLineFactor = 1.18;

  /// The headline is set at `height: 1`, so its line box is its font size.
  double get headlineBottom => top + metrics.lineHeight(headlineSize, 1);

  /// The edge a page body anchors below.
  double get bottom =>
      headlineBottom +
      (gap +
              metrics.lineHeight(subtitleSize, _subtitleLineFactor) *
                  _subtitleLines) *
          subtitleSlot;
}

double _lerp(double start, double end, double t) => start + (end - start) * t;
