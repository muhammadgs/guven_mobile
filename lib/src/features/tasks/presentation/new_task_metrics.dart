import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';

/// Where the `Yeni tapşırıq` surfaces sit, as arithmetic.
///
/// Same rule as the filter's ([TaskFilterMetrics]): none of these panels is
/// laid out by the widget tree, because each one grows out of a *global* rect —
/// the `+` button's, then the sheet's, then one field row's — and a
/// destination has to be known in those coordinates before the first frame is
/// drawn. Everything below is therefore derived from four measured things: the
/// button's rect, the safe area, the keyboard, and the text scale. No anchor is
/// a guessed reserve, so the sheet lands in the same place, relative to the
/// screen, on every phone (`layout-rules-are-binding`).
@immutable
class NewTaskMetrics {
  const NewTaskMetrics._({
    required this.button,
    required this.band,
    required this.keyboardTop,
    required this.scale,
    required this.textScaler,
    required this.menuRows,
  });

  factory NewTaskMetrics.of(
    BuildContext context, {
    required Rect button,
    required int menuRows,
  }) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final double scale = uiScale(context);
    final double margin = kMargin * scale;

    return NewTaskMetrics._(
      button: button,
      band: Rect.fromLTRB(
        safe.left + margin,
        safe.top + margin,
        screen.width - safe.right - margin,
        screen.height - safe.bottom - margin,
      ),
      // The keyboard raises the sheet's foot and leaves its head where it was.
      // Folding it into the band instead would shrink the sheet from both ends
      // at once, and the title would walk down the screen every time the
      // description field was tapped.
      keyboardTop: keyboard <= 0
          ? double.infinity
          : screen.height - keyboard - margin,
      scale: scale,
      textScaler: MediaQuery.textScalerOf(context),
      menuRows: menuRows,
    );
  }

  /// Distance every surface keeps from the safe area, on the phone canvas.
  static const double kMargin = 20;

  // ── The chooser ─────────────────────────────────────────────────────────

  static const double kMenuWidth = 210;
  static const double kMenuRowHeight = 46;
  static const double kMenuTitleSize = 30;
  static const double kMenuPadH = 12;
  static const double kMenuPadTop = 14;
  static const double kMenuPadBottom = 16;
  static const double kMenuRadius = 30;

  // ── The sheet ───────────────────────────────────────────────────────────

  static const double kSheetRadius = 36;
  static const double kSheetPadH = 22;
  static const double kSheetPadTop = 20;
  static const double kSheetPadBottom = 20;
  static const double kSheetTitleSize = 30;

  /// How much of the band the sheet leaves above and below itself.
  ///
  /// A fraction rather than a fixed inset, because what it buys is *seeing the
  /// dimmed screen behind* — the design's whole way of saying the sheet floats
  /// — and that has to read the same on a short phone and a tall one. Clamped
  /// so it never becomes a hairline or half the screen.
  static const double kSheetInsetFraction = 0.11;

  // ── A field, and the panel that grows out of it ─────────────────────────

  static const double kLabelSize = 16.5;
  static const double kValueSize = 14.5;
  static const double kFieldHeight = 46;
  static const double kFieldGap = 8;
  static const double kBetweenFields = 18;
  static const double kPickerRowHeight = 42;
  static const double kPickerRadius = 26;
  static const double kPickerPadH = 10;
  static const double kPickerPadV = 10;

  /// Global rect of the `+` button the whole thing grows out of.
  final Rect button;

  /// Where a surface may sit: the screen minus its insets and [kMargin]. The
  /// keyboard is *not* in it — see [keyboardTop].
  final Rect band;

  /// The line the keyboard's top edge draws, already inset by [kMargin], or
  /// infinity when there is no keyboard. Only the sheet is held above it.
  final double keyboardTop;

  final double scale;
  final TextScaler textScaler;

  /// How many kinds the chooser offers.
  final int menuRows;

  double get menuRadius => kMenuRadius * scale;
  double get menuPadH => kMenuPadH * scale;
  double get sheetRadius => kSheetRadius * scale;
  double get sheetPadH => kSheetPadH * scale;
  double get sheetPadTop => kSheetPadTop * scale;
  double get sheetPadBottom => kSheetPadBottom * scale;
  double get menuTitleSize => kMenuTitleSize * scale;
  double get sheetTitleSize => kSheetTitleSize * scale;
  double get labelSize => kLabelSize * scale;
  double get valueSize => kValueSize * scale;
  double get fieldGap => kFieldGap * scale;
  double get betweenFields => kBetweenFields * scale;
  double get pickerRadius => kPickerRadius * scale;
  double get pickerPadH => kPickerPadH * scale;
  double get pickerPadV => kPickerPadV * scale;

  /// Rows reserve their own text's height, so a phone with the system font
  /// turned up gets a taller row instead of a clipped label.
  double get menuRowHeight =>
      math.max(kMenuRowHeight * scale, textScaler.scale(labelSize) * 2.1);

  double get pickerRowHeight =>
      math.max(kPickerRowHeight * scale, textScaler.scale(valueSize) * 2.1);

  double get fieldHeight =>
      math.max(kFieldHeight * scale, textScaler.scale(valueSize) * 2.3);

  double get menuTitleHeight => textScaler.scale(menuTitleSize) * 1.25;
  double get sheetTitleHeight => textScaler.scale(sheetTitleSize) * 1.25;

  /// The chooser, at the `+` button's top-left corner where there is room.
  ///
  /// Clamped rather than centred: it grows out of the button, so the corner it
  /// starts from has to stay on screen whichever way the phone is held.
  Rect get menuPanel {
    final double width = math.min(kMenuWidth * scale, band.width);
    final double height = math.min(
      kMenuPadTop * scale +
          menuTitleHeight +
          menuRows * menuRowHeight +
          kMenuPadBottom * scale,
      band.height,
    );
    final double left = button.left.clamp(
      band.left,
      math.max(band.left, band.right - width),
    );
    final double top = button.top.clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Global rect of one chooser row.
  Rect menuRow(int index) {
    final Rect panel = menuPanel;
    return Rect.fromLTWH(
      panel.left + menuPadH,
      panel.top + kMenuPadTop * scale + menuTitleHeight + index * menuRowHeight,
      panel.width - 2 * menuPadH,
      menuRowHeight,
    );
  }

  /// The form. As tall as the band allows, less the fraction that keeps the
  /// dimmed screen visible behind it, and never reaching under the keyboard.
  Rect get sheet {
    final double inset = (band.height * kSheetInsetFraction).clamp(
      28 * scale,
      120 * scale,
    );
    final double top = band.top + inset;
    final double bottom = math.max(
      math.min(band.bottom - inset, keyboardTop),
      // Even a keyboard that takes most of the screen leaves a sheet worth
      // scrolling rather than a sliver.
      math.min(top + 160 * scale, band.bottom),
    );
    return Rect.fromLTRB(band.left, top, band.right, bottom);
  }

  /// A field's option list, grown out of [anchor] — the field row's own global
  /// rect, read from its render object at the moment it was tapped, so a field
  /// the form has been scrolled past is still anchored to where it actually is.
  ///
  /// It opens *over* the row rather than beside it: unlike the filter, a field
  /// here is as wide as the sheet, so there is no column of screen left to put
  /// a second panel in.
  Rect pickerPanel({required Rect anchor, required int rowCount}) => panelAt(
    anchor: anchor,
    height: 2 * pickerPadV + rowCount * pickerRowHeight,
  );

  /// The same placement for a panel whose height is not a count of rows — the
  /// date wheel, which is as tall as it is whatever the month holds.
  Rect panelAt({required Rect anchor, required double height}) {
    final double width = math.min(anchor.width, band.width);
    height = math.min(height, band.height);
    final double left = anchor.left.clamp(
      band.left,
      math.max(band.left, band.right - width),
    );
    // Anchored to the row's own top, then pulled back onto the band — a list
    // long enough to run off the bottom rides up instead of being cut.
    final double top = anchor.top.clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, width, height);
  }
}
