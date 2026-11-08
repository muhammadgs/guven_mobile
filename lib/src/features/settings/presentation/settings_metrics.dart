import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';

/// The width of the phone the `Tənzimləmələr` design is drawn on: an
/// iPhone 16 Pro, like `Baza`'s.
const double kSettingsFrame = 402;

/// Where everything on `Tənzimləmələr` sits, as arithmetic.
///
/// Every number is the design's, measured off its 402pt frame and multiplied
/// by [scale]. Each block is anchored to the measured bottom of the one above
/// it — the title's box grows with the text scale and everything under it
/// moves down with it — so nothing here is a guess at leftover space.
///
/// The design draws its pills and its nav bar 2.4pt right of the screen's
/// centre; that shift is taken out, so the pills are centred and the title
/// keeps its place relative to them.
@immutable
class SettingsMetrics {
  const SettingsMetrics._({
    required this.scale,
    required this.width,
    required this.safeTop,
    required this.textScaler,
  });

  factory SettingsMetrics.of(BuildContext context) {
    return SettingsMetrics._(
      scale: uiScaleForFrame(context, kSettingsFrame),
      width: MediaQuery.sizeOf(context).width,
      safeTop: MediaQuery.paddingOf(context).top,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  /// Builds the metrics without a context, for the device-matrix test.
  @visibleForTesting
  const SettingsMetrics.raw({
    required this.scale,
    required this.width,
    required this.safeTop,
    required this.textScaler,
  });

  final double scale;
  final double width;
  final double safeTop;
  final TextScaler textScaler;

  // ── type ────────────────────────────────────────────────────────────────

  /// `Tənzimləmələr`: CalSans 37 — its cap height and its width both say so.
  static const double titleSize = 37;
  static const double titleLineHeight = 1.08;

  /// The category under it: CalSans 25, `Baza`'s subtitle exactly.
  static const double subtitleSize = 25;
  static const double subtitleLineHeight = 1.1;

  /// A pill's label: Poppins 16, regular.
  static const double labelSize = 16;

  // ── horizontal ──────────────────────────────────────────────────────────

  /// A pill's distance from either edge.
  double get margin => 20.5 * scale;

  /// The title's box: the `T` has almost no side bearing, so its ink starts
  /// a hair inside the pills' edge.
  double get titleLeft => margin + 0.6 * scale;

  /// The design sets the category name a little in from the title.
  double get subtitleLeft => margin + 6 * scale;

  double get pillWidth => width - 2 * margin;

  // ── vertical ────────────────────────────────────────────────────────────

  /// The title's box: its cap line 101pt down a 402pt frame whose status
  /// bar is 62pt.
  double get titleTop => safeTop + 32.2 * scale;

  double get titleBottom =>
      titleTop + textScaler.scale(titleSize * scale) * titleLineHeight;

  /// The first level: the category pills, 28pt under the title's box.
  double get categoriesTop => titleBottom + 28 * scale;

  /// The second level: the category's name under the title …
  double get subtitleTop => titleBottom + 6.9 * scale;

  double get subtitleBottom =>
      subtitleTop +
      textScaler.scale(subtitleSize * scale) * subtitleLineHeight;

  /// … and its options under that.
  double get optionsTop => subtitleBottom + 15.6 * scale;

  /// A pill: 48pt tall, fully round.
  double get pillHeight => 48 * scale;

  /// Between two pills on the same level. The design has one pill a level,
  /// so this is the `Baza` rows' rhythm rather than a measured number.
  double get pillGap => 12 * scale;

  /// The top of pill [index] on a level whose first pill starts at [top].
  double pillTop(double top, int index) =>
      top + index * (pillHeight + pillGap);
}
