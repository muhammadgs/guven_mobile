import 'package:flutter/widgets.dart';

/// Screen adaptation for a UI that was drawn against a phone canvas.
///
/// Every fixed dimension in this app — reserves, gaps, type sizes — was
/// calibrated on a ~390pt-wide phone in portrait. Rather than re-tuning those
/// numbers per breakpoint, they are passed through the helpers here so a
/// narrow phone shrinks the layout and a tablet grows it, instead of either
/// one wearing phone-sized content that no longer fits its screen.
///
/// Every helper keys off the *shortest* side, not the width: that keeps a
/// tablet in landscape from inflating values that were meant to track the
/// narrow axis.

/// Shortest side (logical px) at or above which a device is laid out as a
/// tablet. Matches Android's `sw600dp` bucket and covers every iPad.
const double kTabletBreakpoint = 600;

/// The canvas every fixed dimension in this app was measured against.
const double _phoneCanvas = 390;

/// How far below the canvas the layout is allowed to shrink.
///
/// A great many Android phones report 360pt — 8% narrower than the canvas —
/// and the smallest supported screens report ~320pt. Pinning those to 1.0
/// (which this helper used to do) left them wearing a layout drawn for a
/// wider screen: labels that fit the canvas ran out of room and ellipsised,
/// and fixed gaps ate space the screen did not have.
const double _minScale = 0.85;

/// How far above the canvas it may grow, so a 13" iPad gains a larger layout
/// without simply being a magnified phone.
const double _maxScale = 1.6;

/// Whether the current device should use tablet layout rules.
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

/// Multiplier mapping a phone-calibrated dimension onto the current device.
double uiScale(BuildContext context) =>
    (MediaQuery.sizeOf(context).shortestSide / _phoneCanvas)
        .clamp(_minScale, _maxScale)
        .toDouble();

/// Scales [phoneValue] — a spacing or size measured on the phone canvas — to
/// the current device.
double scaled(BuildContext context, double phoneValue) =>
    phoneValue * uiScale(context);

/// Resolves a proportional dimension the way this app writes them: a fraction
/// of the canvas, clamped to a phone-calibrated range.
///
/// Both ends of the range travel with [uiScale]. Only the ceiling used to,
/// which meant a narrow phone could shrink the proportional term while the
/// floor stayed at its canvas value — the element stopped tracking the screen
/// while everything around it kept going, and the two collided. On the 390pt
/// canvas the scale is 1 and the result is identical to the plain
/// `(shortestSide * factor).clamp(min, max)` this replaces.
double responsive(
  BuildContext context, {
  required double factor,
  required double min,
  required double max,
}) {
  final double basis = MediaQuery.sizeOf(context).shortestSide;
  final double scale = uiScale(context);
  return (basis * factor).clamp(min * scale, max * scale).toDouble();
}
