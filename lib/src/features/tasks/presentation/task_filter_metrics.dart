import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';

/// The one place that decides where the filter panels sit.
///
/// The panel is not laid out by the widget tree — it cannot be. It grows out
/// of the filter button's rect in *global* coordinates, so its destination has
/// to be known in those same coordinates before a single frame is drawn, and
/// the sub-panel has to know where one row of the first panel landed in order
/// to grow out of that.
///
/// Everything below is therefore arithmetic over three measured things: the
/// button's rect, the safe area, and the text scale. No anchor is a fraction
/// of the screen height and no gap stands in for another widget's height, so
/// the two panels land in the same place, relative to the button, on every
/// phone — which is the rule this app is built to
/// (`layout-rules-are-binding`).
@immutable
class TaskFilterMetrics {
  const TaskFilterMetrics._({
    required this.button,
    required this.band,
    required this.scale,
    required this.textScaler,
    required this.columnCount,
  });

  /// Reads the device and returns the geometry for a panel of [columnCount]
  /// rows growing out of [button].
  factory TaskFilterMetrics.of(
    BuildContext context, {
    required Rect button,
    required int columnCount,
  }) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double scale = uiScale(context);
    final double margin = kMargin * scale;

    return TaskFilterMetrics._(
      button: button,
      // The strip the panels are allowed to occupy. Insets are folded in
      // here, once, so nothing downstream has to remember them.
      band: Rect.fromLTRB(
        safe.left + margin,
        safe.top + margin,
        screen.width - safe.right - margin,
        screen.height - safe.bottom - margin,
      ),
      scale: scale,
      textScaler: MediaQuery.textScalerOf(context),
      columnCount: columnCount,
    );
  }

  /// Distance the panels keep from the safe area, on the phone canvas.
  static const double kMargin = 20;

  /// Between the column panel and the values panel beside it.
  static const double kGap = 12;

  /// A panel's width on the canvas — two of them plus [kGap] span the content
  /// width of a 390pt phone, which is how the design draws them.
  static const double kPanelWidth = 168;

  /// One row of either panel.
  static const double kRowHeight = 38;

  /// The `Filter` title, and a column or value label.
  static const double kTitleSize = 26;
  static const double kLabelSize = 15;

  /// Inset from a panel's edge to its rows.
  static const double kPadH = 8;
  static const double kPadTop = 12;
  static const double kPadBottom = 14;

  /// The panels' corner. Matches `kTaskFilterGlass`.
  static const double kRadius = 30;

  /// Global rect of the button the panel grows out of.
  final Rect button;

  /// Where a panel may sit: the screen minus its insets and [kMargin].
  final Rect band;

  final double scale;
  final TextScaler textScaler;
  final int columnCount;

  double get gap => kGap * scale;
  double get radius => kRadius * scale;
  double get padH => kPadH * scale;
  double get padTop => kPadTop * scale;
  double get padBottom => kPadBottom * scale;
  double get titleSize => kTitleSize * scale;
  double get labelSize => kLabelSize * scale;

  /// A row is at least the canvas height, and taller when the system font is
  /// scaled up — text reserves its own space rather than overflowing a fixed
  /// box (`layout-rules-are-binding`, rule 4).
  double get rowHeight => math.max(
    kRowHeight * scale,
    textScaler.scale(labelSize) * 1.9,
  );

  /// The `Filter` title band above the columns, which also carries the
  /// `Sıfırla` control.
  ///
  /// The control lives up there rather than under the last column for a
  /// geometric reason: it appears the moment the first value is ticked, and a
  /// row appearing at the bottom would make the panel a row taller under the
  /// user's finger. The header is the same height whether it is there or not.
  double get headerHeight =>
      textScaler.scale(titleSize) * 1.2 + 14 * scale;

  /// Both panels are the same width, and two of them plus a gap must fit
  /// between the band's edges — otherwise the values panel would have to
  /// overlap the columns it came from to stay on screen.
  double get panelWidth =>
      math.min(kPanelWidth * scale, (band.width - gap) / 2);

  /// The column panel, at the button's top-left corner where there is room
  /// for it.
  ///
  /// It is clamped, not centred: the values panel needs the width to its
  /// right, so the left edge can never travel further right than the point
  /// where both panels still fit.
  Rect get columnPanel {
    final double height = math.min(
      padTop + headerHeight + columnCount * rowHeight + padBottom,
      band.height,
    );
    final double maxLeft = math.max(
      band.left,
      band.right - (2 * panelWidth + gap),
    );
    final double left = button.left.clamp(band.left, maxLeft);
    final double top = button.top.clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, panelWidth, height);
  }

  /// Where the columns start inside [columnPanel].
  double get columnsTop => columnPanel.top + padTop + headerHeight;

  /// Global rect of one column's row — the capsule the selected column wears,
  /// and the rect its values panel grows out of.
  Rect columnRow(int index) {
    final Rect panel = columnPanel;
    return Rect.fromLTWH(
      panel.left + padH,
      columnsTop + index * rowHeight,
      panel.width - 2 * padH,
      rowHeight,
    );
  }

  /// The values panel for the column at [index], holding [valueCount] rows —
  /// `Hamısı` included.
  ///
  /// It opens beside its column rather than under it, with its first row on
  /// the same line as the column it belongs to, so the eye can follow one to
  /// the other. A long list is capped to the band and scrolls inside.
  Rect valuePanel({required int index, required int valueCount}) {
    final double height = math.min(
      padTop + valueCount * rowHeight + padBottom,
      band.height,
    );
    final Rect panel = columnPanel;
    final double left = math.min(
      panel.right + gap,
      band.right - panelWidth,
    );
    final double top = (columnRow(index).top - padTop).clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, panelWidth, height);
  }
}
