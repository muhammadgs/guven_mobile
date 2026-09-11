import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';

/// The one place that decides where the `Daha çox` fan's buttons sit.
///
/// The buttons stand on concentric arcs around a pivot below the bar, the way
/// the design draws them: the outer arc holds up to [kMaxPerRow], the rest go
/// on the inner one. Neighbours on *either* arc are the same distance apart
/// along it ([kSpacing]) — the design's rule, and the reason the inner arc
/// fans out wider than the outer one.
///
/// Everything is anchored to the bar's measured top edge and passed through
/// [uiScale], then shrunk as a whole — never squeezed — if a narrow screen
/// cannot hold the widest arc. No anchor is a fraction of the screen height,
/// so the fan sits on the bar the same way on every phone
/// (`layout-rules-are-binding`).
@immutable
class MoreMenuMetrics {
  const MoreMenuMetrics._({
    required this.bar,
    required this.band,
    required this.unit,
    required this.textScaler,
    required this.count,
  });

  /// Reads the device and returns the geometry for [count] buttons fanned
  /// out over [bar], the bar capsule's rect in the shell's coordinates.
  factory MoreMenuMetrics.of(
    BuildContext context, {
    required Rect bar,
    required int count,
  }) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double scale = uiScale(context);
    final double margin = kMargin * scale;
    final Rect band = Rect.fromLTRB(
      safe.left + margin,
      safe.top + margin,
      screen.width - safe.right - margin,
      bar.top,
    );

    // How wide and tall the fan is on the canvas, before any shrinking.
    double halfWidth = 0;
    for (int i = 0; i < count; i++) {
      halfWidth = math.max(halfWidth, _canvasCenter(i, count).dx.abs());
    }
    halfWidth += math.max(kLabelWidth, kBubble) / 2;
    final double height = kOuterRadius + kBubble / 2 - kPivotDrop;

    final double centerX = bar.center.dx;
    final double roomX = math.min(centerX - band.left, band.right - centerX);
    final double roomY = bar.top - band.top;
    final double fit = math.min(
      1.0,
      math.min(roomX / (halfWidth * scale), roomY / (height * scale)),
    );

    return MoreMenuMetrics._(
      bar: bar,
      band: band,
      unit: scale * fit,
      textScaler: MediaQuery.textScalerOf(context),
      count: count,
    );
  }

  /// Most buttons one arc may hold.
  static const int kMaxPerRow = 5;

  /// A button's white disc, and the glyph inside it.
  static const double kBubble = 48;
  static const double kIcon = 24;

  /// Distance along an arc between neighbouring buttons' centres.
  ///
  /// This, [kOuterRadius] and [kLabelSize] are one decision, not three. The
  /// outer arc has to put its end buttons' names on a 390pt screen, keep the
  /// second button's name clear of the end button's disc, and drop the second
  /// button far enough below the top one that two long names side by side —
  /// `Departamentlər` next to `Rəsmi Qurumlar` — do not touch. At 10pt no
  /// arc does all three; at 9.5pt this one does, with room to spare
  /// (`more_menu_metrics_test.dart` checks every pair of names in every pair
  /// of slots). The design's own names are smaller still.
  static const double kSpacing = 83.5;

  /// The outer arc's radius, and how much tighter each arc inside it is.
  static const double kOuterRadius = 218;
  static const double kRowGap = 80;

  /// How far below the bar's top edge the arcs are centred.
  static const double kPivotDrop = 61;

  /// A button's name, under its disc.
  static const double kLabelSize = 9.5;
  static const double kLabelLineHeight = 1.2;
  static const double kLabelGap = 4;

  /// The box a name is drawn in. Every page's name fits it on the canvas; a
  /// larger system font scales the name down into it rather than cutting it.
  static const double kLabelWidth = 78;

  /// Distance the fan keeps from the safe area's sides.
  static const double kMargin = 5;

  /// The bar capsule, in the same coordinates as everything returned here.
  final Rect bar;

  /// Where the fan may draw: inside the safe area, above the bar.
  final Rect band;

  /// Canvas points to logical pixels: [uiScale], times any shrink the screen
  /// forced on the whole fan.
  final double unit;
  final TextScaler textScaler;
  final int count;

  /// How [count] buttons split into arcs, outer first: 8 → 5, 3.
  static List<int> rowSizes(int count) => <int>[
    for (int left = count; left > 0; left -= kMaxPerRow)
      math.min(left, kMaxPerRow),
  ];

  double get bubble => kBubble * unit;
  double get icon => kIcon * unit;
  double get labelSize => kLabelSize * unit;
  double get labelGap => kLabelGap * unit;
  double get labelWidth => kLabelWidth * unit;
  double get labelHeight => textScaler.scale(labelSize) * kLabelLineHeight;

  /// The centre every arc is drawn around.
  Offset get pivot => Offset(bar.center.dx, bar.top + kPivotDrop * unit);

  /// Where the buttons fly out of: the middle of `Daha çox`'s cell.
  Offset get origin => bar.center;

  /// Centre of button [index]'s disc.
  Offset center(int index) => pivot + _canvasCenter(index, count) * unit;

  Rect bubbleRect(int index) =>
      Rect.fromCircle(center: center(index), radius: bubble / 2);

  /// The box button [index]'s name is drawn in.
  Rect labelRect(int index) {
    final Offset c = center(index);
    return Rect.fromLTWH(
      c.dx - labelWidth / 2,
      c.dy + bubble / 2 + labelGap,
      labelWidth,
      labelHeight,
    );
  }

  /// The slot nearest [point], if [point] is close enough to one to count as
  /// being over it. The catch radius is most of the way to the neighbours, so
  /// a finger crossing the fan never falls through a gap between two slots.
  int? slotAt(Offset point) {
    int? best;
    double bestDistance = kSpacing * unit * 0.7;
    for (int i = 0; i < count; i++) {
      final double distance = (center(i) - point).distance;
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Button [index]'s centre relative to the pivot, on the canvas.
  static Offset _canvasCenter(int index, int count) {
    final List<int> rows = rowSizes(count);
    int row = 0;
    int start = 0;
    while (index >= start + rows[row]) {
      start += rows[row];
      row++;
    }
    final int inRow = rows[row];
    final double radius = kOuterRadius - row * kRowGap;
    final double step = kSpacing / radius;
    final double angle = (index - start - (inRow - 1) / 2) * step;
    return Offset(radius * math.sin(angle), -radius * math.cos(angle));
  }
}
