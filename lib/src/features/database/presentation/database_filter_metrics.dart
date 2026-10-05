import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'widgets/database_glass.dart' show databaseScale;

/// Where a `Baza` filter sits, as arithmetic.
///
/// The same rule as the task filter's and `Detallar`'s: the panel is not laid
/// out by the widget tree. It grows out of the funnel's rect in *global*
/// coordinates, and between its two pages — the columns, and one column's
/// values — the one pane of glass changes size, so both of its shapes have to
/// be known in those coordinates before a frame is drawn. Everything below is
/// derived from the button, the safe area, the keyboard and the text scale.
///
/// The constants are the design's, measured off its 402pt frame and scaled
/// from that frame ([databaseScale]):
///
/// * the columns: a 158pt panel with a 22pt corner, 37pt rows and 35.5pt
///   capsules — `Detallar`'s own geometry, which the design reuses;
/// * the values: a 293pt panel with a 30pt corner; a 37.5pt round back
///   button and a search field beside it, 5.5pt apart and 14.25pt in from
///   either edge; then `Hamısı` and the values, 15pt type on 21pt lines, a
///   row 33.5pt tall for every line it needs.
@immutable
class DatabaseFilterMetrics {
  DatabaseFilterMetrics._({
    required this.origin,
    required this.band,
    required this.scale,
    required this.textScaler,
    required this.columnCount,
  }) : lineHeight = _measureLine(scale, textScaler);

  /// [origin] is where the panel's top-left corner wants to be: the left edge
  /// of the page's buttons, at their top — the design draws the filter over
  /// both, the way `Detallar` is drawn over its one. [columnCount] is how
  /// many columns the page's filter lists.
  factory DatabaseFilterMetrics.of(
    BuildContext context, {
    required Offset origin,
    required int columnCount,
  }) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double scale = databaseScale(context);
    final double margin = kMargin * scale;

    return DatabaseFilterMetrics._(
      origin: origin,
      band: Rect.fromLTRB(
        safe.left + margin,
        safe.top + margin,
        screen.width - safe.right - margin,
        // Over the keyboard while it is up: the search field is typed into
        // with the panel still in view.
        screen.height - math.max(safe.bottom, keyboard) - margin,
      ),
      scale: scale,
      textScaler: MediaQuery.textScalerOf(context),
      columnCount: columnCount,
    );
  }

  /// Distance the panel keeps from the safe area, and from the keyboard.
  static const double kMargin = 20;

  static const double kColumnsWidth = 158;
  static const double kColumnsRadius = 22;
  static const double kRowHeight = 37;
  static const double kCapsuleHeight = 35.5;
  static const double kPadH = 6;
  static const double kTextInset = 18.5;
  static const double kColumnsTitleInset = 15;

  static const double kValuesWidth = 293;
  static const double kValuesRadius = 30;
  static const double kValuesTitleInset = 24;

  /// The back button's side, and the search field's height.
  static const double kControlSize = 37.5;
  static const double kControlInset = 14.25;
  static const double kControlSpacing = 5.5;

  /// From the title to the controls, and from the controls to `Hamısı`.
  static const double kControlGap = 6;
  static const double kListGap = 13.75;

  /// A value's line, and the room above and below its text.
  static const double kValueLine = 21;
  static const double kValuePadV = 6.25;

  /// From the panel's edge to a value's capsule, and from there to its text.
  static const double kValueCapsuleInset = 13;
  static const double kValueTextInset = 16;

  /// How many one-line values show at once before the list scrolls — the
  /// user's "five or six", and a half row that says there is more.
  static const double kVisibleRows = 5.5;

  static const double kTitleSize = 30;
  static const double kLabelSize = 15;
  static const double kPadTop = 12;
  static const double kColumnsPadBottom = 7.5;
  static const double kValuesPadBottom = 14;

  /// Where the panel's top-left corner wants to be.
  final Offset origin;

  /// Where the panel may sit: the screen minus its insets, the keyboard and
  /// [kMargin].
  final Rect band;

  final double scale;
  final TextScaler textScaler;

  /// How many columns the first page lists: nine on `Satışlar`, five on
  /// `Stok`. The panel is as tall as they are, and no taller.
  final int columnCount;

  double get padH => kPadH * scale;
  double get textInset => kTextInset * scale;
  double get padTop => kPadTop * scale;
  double get columnsPadBottom => kColumnsPadBottom * scale;
  double get valuesPadBottom => kValuesPadBottom * scale;
  double get columnsRadius => kColumnsRadius * scale;
  double get valuesRadius => kValuesRadius * scale;
  double get columnsTitleInset => kColumnsTitleInset * scale;
  double get valuesTitleInset => kValuesTitleInset * scale;
  double get titleSize => kTitleSize * scale;
  double get labelSize => kLabelSize * scale;
  double get controlInset => kControlInset * scale;
  double get controlSpacing => kControlSpacing * scale;
  double get controlGap => kControlGap * scale;
  double get listGap => kListGap * scale;
  double get valuePadV => kValuePadV * scale;
  double get valueCapsuleInset => kValueCapsuleInset * scale;
  double get valueTextInset => kValueTextInset * scale;

  double get titleHeight => textScaler.scale(titleSize) * 1.25;

  /// Rows reserve their own text's height, so a phone with the system font
  /// turned up gets a taller row instead of a clipped label.
  double get rowHeight =>
      math.max(kRowHeight * scale, textScaler.scale(labelSize) * 1.9);

  double get capsuleHeight => math.min(
    rowHeight,
    math.max(kCapsuleHeight * scale, textScaler.scale(labelSize) * 1.8),
  );

  double get controlSize =>
      math.max(kControlSize * scale, textScaler.scale(labelSize) * 2.1);

  /// A value's line height, as a multiple of its type size — the design's
  /// 21pt over 15pt.
  static const double valueLineHeight = kValueLine / kLabelSize;

  /// What every row's label is set in — here rather than in the row,
  /// because the values panel is sized by measuring its labels in exactly
  /// this.
  TextStyle get labelStyle => _labelStyle(scale);

  static TextStyle _labelStyle(double scale) => TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w400,
    fontSize: kLabelSize * scale,
    height: valueLineHeight,
    letterSpacing: 0,
  );

  /// One line of a value, as the text engine lays it out — measured rather
  /// than multiplied out, because the face's own metrics round it a fraction
  /// of a point away from 21, and a row reserved a fraction short overflows.
  final double lineHeight;

  static double _measureLine(double scale, TextScaler textScaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: 'Hamısı', style: _labelStyle(scale)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return height;
  }

  /// A one-line value's row: `Hamısı`, and most of them.
  double get valueRowMin => lineHeight + 2 * valuePadV;

  /// How wide a value's text may run before it wraps.
  double get valueTextWidth =>
      valuesWidth - 2 * (valueCapsuleInset + valueTextInset);

  /// The height of a value's row: every line its label needs.
  double valueRowHeight(String label) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: kValueMaxLines,
    )..layout(maxWidth: valueTextWidth);
    final double height = painter.height;
    painter.dispose();
    return math.max(valueRowMin, height + 2 * valuePadV);
  }

  /// A name longer than this many lines is cut; none in the data comes
  /// close.
  static const int kValueMaxLines = 4;

  /// How tall [labels] stand in the list, measured only as far as the list
  /// can show — a column of a thousand values costs a handful of
  /// measurements, not a thousand.
  double valuesContentHeight(List<String> labels) {
    final double cap = kVisibleRows * valueRowMin;
    double height = 0;
    for (final String label in labels) {
      height += valueRowHeight(label);
      if (height >= cap) return height;
    }
    return height;
  }

  /// Both panels share [band] with nothing else, so each is held to it.
  double get columnsWidth => math.min(kColumnsWidth * scale, band.width);
  double get valuesWidth => math.min(kValuesWidth * scale, band.width);

  /// The column list, with its top-left corner at [origin] where there is
  /// room for it.
  Rect get columnsPanel {
    final double height = math.min(
      padTop + titleHeight + columnCount * rowHeight + columnsPadBottom,
      band.height,
    );
    return _placed(columnsWidth, height);
  }

  /// `Sıfırla`, in the title's line: small, so that `Filter` keeps its size
  /// beside it on a 158pt panel.
  TextStyle get resetStyle => TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w500,
    fontSize: 11.5 * scale,
    height: 1,
    letterSpacing: 0,
  );

  double get resetHeight => textScaler.scale(11.5 * scale) * 2.1;
  double get resetPadH => 9 * scale;

  /// From the row's edge to the chip's.
  double get resetRight => 4 * scale;

  double get resetWidth {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: 'Sıfırla', style: resetStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width + 2 * resetPadH;
  }

  /// What the chip takes from the title's line: itself, its margin, and a
  /// gap before the title.
  double get resetRoom => resetWidth + resetRight + 8 * scale;

  /// Where the column rows begin inside [columnsPanel].
  double get columnsTop => padTop + titleHeight;

  /// What sits above the values list, measured from the panel's top:
  /// title, controls, and `Hamısı`.
  double get valuesListTop =>
      padTop + titleHeight + controlGap + controlSize + listGap + valueRowMin;

  /// The values panel, for a list [contentHeight] tall.
  ///
  /// The list shows [kVisibleRows] at most and scrolls past that. While the
  /// keyboard is up the panel keeps its place if it can, climbs if it must,
  /// and only then lets the list shrink — never under the keyboard.
  Rect valuesPanel(double contentHeight) {
    final double fixed = valuesListTop + valuesPadBottom;
    final double wanted = math.min(contentHeight, kVisibleRows * valueRowMin);
    double height = fixed + wanted;
    if (height > band.height) height = math.max(fixed, band.height);
    return _placed(valuesWidth, height);
  }

  /// How tall the values list is inside a panel of [panel]'s height.
  double valuesListHeight(Rect panel) =>
      math.max(0, panel.height - valuesListTop - valuesPadBottom);

  /// What sits above a span column's values, measured from the panel's top:
  /// the title, the minimum's field beside the back button, the maximum's
  /// under it — as far below as the back button is from the first — and
  /// `Hamısı`.
  double get rangeListTop => valuesListTop + controlSize + controlSpacing;

  /// The panel of a column narrowed by a span, with [contentHeight] of
  /// values under `Hamısı` — `ƏDV yoxdur`, or nothing. There is no list to
  /// scroll, so it is as tall as what it holds; only a keyboard on a short
  /// phone holds it to less, and then what is under the fields scrolls.
  Rect rangePanel(double contentHeight) {
    final double height = math.min(
      rangeListTop + contentHeight + valuesPadBottom,
      band.height,
    );
    return _placed(valuesWidth, height);
  }

  Rect _placed(double width, double height) {
    final double left = origin.dx.clamp(
      band.left,
      math.max(band.left, band.right - width),
    );
    final double top = origin.dy.clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, width, height);
  }
}
