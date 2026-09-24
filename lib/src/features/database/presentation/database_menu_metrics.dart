import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/database_section.dart';
import 'widgets/database_glass.dart' show databaseScale;

/// Where the `Detallar` panels sit, as arithmetic.
///
/// The same rule as the task filter's (`TaskFilterMetrics`), for the same
/// reason: neither panel is laid out by the widget tree. The menu grows out of
/// the button's rect in *global* coordinates, and a heading's panel grows out
/// of that heading's row, so every destination has to be known in those
/// coordinates before the first frame is drawn. Everything below is derived
/// from the button's rect, the safe area and the text scale.
///
/// The constants are the design's, measured off its 402pt frame and scaled
/// from that frame ([databaseScale]): a 158pt menu of 36pt rows with 35.5pt
/// capsules, and beside it, 6pt away, a panel of 42pt rows centred on the
/// heading it belongs to.
@immutable
class DatabaseMenuMetrics {
  const DatabaseMenuMetrics._({
    required this.button,
    required this.band,
    required this.scale,
    required this.textScaler,
  });

  factory DatabaseMenuMetrics.of(BuildContext context, {required Rect button}) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double scale = databaseScale(context);
    final double margin = kMargin * scale;

    return DatabaseMenuMetrics._(
      button: button,
      band: Rect.fromLTRB(
        safe.left + margin,
        safe.top + margin,
        screen.width - safe.right - margin,
        screen.height - safe.bottom - margin,
      ),
      scale: scale,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  /// Distance the panels keep from the safe area.
  static const double kMargin = 20;

  /// Between the menu and a heading's panel.
  static const double kGap = 6;

  static const double kPanelWidth = 158;

  /// A heading's panel is as wide as its longest name needs, and never
  /// narrower than the design draws the `Əməliyyatlar` one.
  static const double kGroupPanelMinWidth = 157;

  /// A row of the menu, and a row of a heading's panel — the second is looser,
  /// as the design spaces it.
  static const double kRowHeight = 36;
  static const double kGroupRowHeight = 42;

  /// The grey capsule a row wears when it is marked.
  static const double kCapsuleHeight = 35.5;

  /// `Detallar`, and every row's label.
  static const double kTitleSize = 30;
  static const double kLabelSize = 15;

  /// From a panel's edge to a row's capsule, and from the capsule's end to its
  /// label.
  static const double kPadH = 6;
  static const double kTextInset = 18.5;

  /// From the menu's edge to the `Detallar` title.
  static const double kTitleInset = 18.5;

  static const double kPadTop = 12;
  static const double kPadBottom = 7.5;
  static const double kGroupPadV = 4;

  static const double kRadius = 22;

  /// `Əsas panel`, then one row per heading.
  static int get entryCount => 1 + DatabaseGroup.values.length;

  /// Global rect of the button the menu grows out of.
  final Rect button;

  /// Where a panel may sit: the screen minus its insets and [kMargin].
  final Rect band;

  final double scale;
  final TextScaler textScaler;

  double get gap => kGap * scale;
  double get radius => kRadius * scale;
  double get padH => kPadH * scale;
  double get textInset => kTextInset * scale;
  double get titleInset => kTitleInset * scale;
  double get padTop => kPadTop * scale;
  double get padBottom => kPadBottom * scale;
  double get groupPadV => kGroupPadV * scale;
  double get titleSize => kTitleSize * scale;
  double get labelSize => kLabelSize * scale;

  /// What a row's label is set in — here rather than in the row, because a
  /// heading's panel is sized by measuring its labels in exactly this.
  TextStyle get labelStyle => TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w400,
    fontSize: labelSize,
    height: 1.15,
    letterSpacing: 0,
  );

  /// Rows reserve their own text's height, so a phone with the system font
  /// turned up gets a taller row instead of a clipped label.
  double get rowHeight =>
      math.max(kRowHeight * scale, textScaler.scale(labelSize) * 1.9);

  double get groupRowHeight =>
      math.max(kGroupRowHeight * scale, textScaler.scale(labelSize) * 2.2);

  /// The capsule inside a row [row] tall: the design's, grown with the text,
  /// never taller than the row.
  double capsuleHeight(double row) => math.min(
    row,
    math.max(kCapsuleHeight * scale, textScaler.scale(labelSize) * 1.8),
  );

  double get titleHeight => textScaler.scale(titleSize) * 1.25;

  /// Both panels share the band, so each is held to half of it — otherwise
  /// the second would have to sit on the first to stay on screen.
  double get panelWidth =>
      math.min(kPanelWidth * scale, (band.width - gap) / 2);

  double get groupPanelMinWidth =>
      math.min(kGroupPanelMinWidth * scale, (band.width - gap) / 2);

  /// The menu, at the button's top-left corner where there is room for it.
  ///
  /// Clamped, not centred: a heading's panel opens to its right, so the menu
  /// can never travel further right than the point where both still fit.
  Rect get mainPanel {
    final double height = math.min(
      padTop + titleHeight + entryCount * rowHeight + padBottom,
      band.height,
    );
    final double maxLeft = math.max(
      band.left,
      band.right - (panelWidth + gap + groupPanelMinWidth),
    );
    final double left = button.left.clamp(band.left, maxLeft);
    final double top = button.top.clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, panelWidth, height);
  }

  /// Where the rows start inside [mainPanel].
  double get entriesTop => mainPanel.top + padTop + titleHeight;

  /// Global rect of the menu's row [index] — 0 is `Əsas panel`, and heading
  /// `g` is row `1 + g.index`.
  Rect entryRow(int index) {
    final Rect panel = mainPanel;
    return Rect.fromLTWH(
      panel.left + padH,
      entriesTop + index * rowHeight,
      panel.width - 2 * padH,
      rowHeight,
    );
  }

  /// The capsule inside [entryRow] — what a heading's panel grows out of,
  /// since it is the part of the row that is drawn.
  Rect entryCapsule(int index) {
    final Rect row = entryRow(index);
    return Rect.fromCenter(
      center: row.center,
      width: row.width,
      height: capsuleHeight(row.height),
    );
  }

  /// How wide [text] sets in [labelStyle] at the current text scale.
  double labelWidth(String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  /// [group]'s panel: beside the menu, as wide as its longest name, and
  /// centred on the heading's own row — which is where the design puts it, and
  /// keeps the eye on the line it was already reading.
  ///
  /// A name longer than the room left beside the menu is set smaller by the
  /// row rather than letting this panel reach back over the menu.
  Rect groupPanel(DatabaseGroup group) {
    final List<DatabaseSection> sections = group.sections;
    final Rect menu = mainPanel;
    final double left = menu.right + gap;

    double widest = 0;
    for (final DatabaseSection section in sections) {
      widest = math.max(widest, labelWidth(section.title));
    }
    final double width = math.min(
      math.max(widest + 2 * (padH + textInset), groupPanelMinWidth),
      math.max(groupPanelMinWidth, band.right - left),
    );

    final double height = math.min(
      2 * groupPadV + sections.length * groupRowHeight,
      band.height,
    );
    final double top = (entryRow(1 + group.index).center.dy - height / 2).clamp(
      band.top,
      math.max(band.top, band.bottom - height),
    );
    return Rect.fromLTWH(left, top, width, height);
  }
}
