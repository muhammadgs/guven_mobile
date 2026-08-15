import 'package:flutter/widgets.dart';

/// Screen adaptation for a UI that was drawn against a phone canvas.
///
/// Every fixed dimension in this app — reserves, gaps, type sizes — was
/// calibrated on a ~390pt-wide phone in portrait. Rather than re-tuning those
/// numbers per breakpoint, they are passed through the helpers here so a tablet
/// grows the layout proportionally instead of stranding phone-sized content in
/// the middle of a large screen.
///
/// Every helper keys off the *shortest* side, not the width: that keeps a
/// tablet in landscape from inflating values that were meant to track the
/// narrow axis.

/// Shortest side (logical px) at or above which a device is laid out as a
/// tablet. Matches Android's `sw600dp` bucket and covers every iPad.
const double kTabletBreakpoint = 600;

/// The canvas every fixed dimension in this app was measured against.
const double _phoneCanvas = 390;

/// Whether the current device should use tablet layout rules.
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

/// Multiplier mapping a phone-calibrated dimension onto the current device.
///
/// Never shrinks below 1 (small phones keep the designed sizes) and stops at
/// 1.6 so a 13" iPad grows the layout without simply magnifying it.
double uiScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).shortestSide / _phoneCanvas)
        .clamp(1.0, 1.6)
        .toDouble();

/// Scales [phoneValue] — a spacing or size measured on the phone canvas — to
/// the current device.
double scaled(BuildContext context, double phoneValue) =>
    phoneValue * uiScale(context);

/// Resolves a proportional dimension the way this app writes them: a fraction
/// of the canvas, clamped to a phone-calibrated range.
///
/// The [max] ceiling is lifted by [uiScale] so tablets are not pinned to the
/// phone maximum — on a phone the result is identical to the original
/// `(width * factor).clamp(min, max)` it replaces.
double responsive(
  BuildContext context, {
  required double factor,
  required double min,
  required double max,
}) {
  final double basis = MediaQuery.sizeOf(context).shortestSide;
  return (basis * factor).clamp(min, max * uiScale(context)).toDouble();
}
