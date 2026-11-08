import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';

/// The phone the Davamiyyət design is drawn on: an iPhone 16 Pro, 402pt.
const double kAttendanceFrame = 402;

/// Every number on the profile button, the profile card and the prompts,
/// measured off the design's 2× exports and multiplied by [scale].
///
/// Vertical positions are anchored to measured edges — the card to the
/// button it grows out of, its rows to the card's top, the prompt to the
/// screen's centre — never to space that happens to be left over
/// (`layout-rules-are-binding`). Text boxes are placed by their *cap line*,
/// which is what the design measures, through [capTop].
@immutable
class AttendanceMetrics {
  const AttendanceMetrics._({
    required this.scale,
    required this.screen,
    required this.padding,
    required this.keyboard,
    required this.textScaler,
  });

  factory AttendanceMetrics.of(BuildContext context) {
    return AttendanceMetrics._(
      scale: uiScaleForFrame(context, kAttendanceFrame),
      screen: MediaQuery.sizeOf(context),
      padding: MediaQuery.paddingOf(context),
      keyboard: MediaQuery.viewInsetsOf(context).bottom,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @visibleForTesting
  const AttendanceMetrics.raw({
    required this.scale,
    required this.screen,
    required this.padding,
    this.keyboard = 0,
    this.textScaler = TextScaler.noScaling,
  });

  final double scale;
  final Size screen;
  final EdgeInsets padding;

  /// The software keyboard's height, 0 when it is down.
  final double keyboard;
  final TextScaler textScaler;

  double _s(double designPt) => designPt * scale;

  /// A font size for a `TextStyle`: scaled to the phone, *not* through the
  /// user's text size — the `Text` applies that itself.
  double type(double designPt) => designPt * scale;

  /// A font size on the design frame, scaled to this phone *and* through the
  /// user's text size — the one number every text box below is built from.
  double font(double designPt) => textScaler.scale(_s(designPt));

  // ── type ────────────────────────────────────────────────────────────────
  //
  // Sizes come from the widths of the design's words, which agree with
  // their cap heights to within a pixel at 2×.

  /// `Məhəmməd Qasımov` — CalSans 22, the face's own spacing, as on the
  /// Baza cards. The design's −1.1 (−5%) ran the letters into each other.
  static const double nameSize = 22;
  static const double nameTracking = 0;

  /// `Güvən Finans MMC`. Poppins' own spacing: −0.9 (−6%) crowded it too.
  static const double companySize = 15;
  static const double companyTracking = 0;

  /// `Dəvamiyyət: …`, the buttons' labels, a history row's kind and time.
  static const double bodySize = 15;

  /// A history row's note.
  static const double noteSize = 13;

  /// The initials in the avatar.
  static const double initialsSize = 18;

  /// Every prompt's text, title and buttons.
  static const double promptSize = 17.5;

  /// The placeholder and the typing in `Yazılı bildir`'s box.
  static const double fieldSize = 15;

  /// Line boxes. Poppins' natural line is 1.4em; CalSans' 1.3em.
  static const double bodyLine = 1.4;
  static const double nameLine = 1.3;
  static const double promptLine = 1.3;

  /// From a text box's top to its cap line, with even leading — the
  /// distance the design's measurements are taken to.
  ///
  /// [ascent]/[descent] are the face's hhea values: Poppins 1.05/0.35,
  /// CalSans 1.0/0.3. [cap] is its cap height: 0.698 / 0.70.
  static double capOffset({
    required double size,
    required double line,
    double ascent = 1.05,
    double descent = 0.35,
    double cap = 0.698,
  }) => (line * size - (ascent + descent) * size) / 2 + (ascent - cap) * size;

  /// Where a text box goes so its cap line lands [capLine] below its parent's
  /// top. The cap line is the design's; the offset grows with the text.
  double capTop(
    double capLine, {
    required double size,
    required double line,
    bool calSans = false,
  }) =>
      _s(capLine) -
      capOffset(
        size: font(size),
        line: line,
        ascent: calSans ? 1.0 : 1.05,
        descent: calSans ? 0.3 : 0.35,
        cap: calSans ? 0.70 : 0.698,
      );

  // ── the profile button, beside the greeting ─────────────────────────────

  /// A 43pt disc whose left edge is the card's.
  double get profileDiameter => _s(43);
  double get profileLeft => _s(11.5);

  /// From the disc's right edge to the greeting's first letter.
  double get greetingGap => _s(26.5);

  /// The person glyph inside it.
  double get profileIcon => _s(19);

  // ── the card ────────────────────────────────────────────────────────────

  /// White, fully opaque — not glass.
  double get cardWidth => math.min(_s(324.5), screen.width - 2 * profileLeft);
  double get cardRadius => _s(32);

  /// The card's top sits 4.5pt above the disc's, its left on the disc's.
  Rect cardRectFor(Rect button, double height) =>
      Rect.fromLTWH(button.left, button.top - _s(4.5), cardWidth, height);

  double get avatarLeft => _s(9.5);
  double get avatarTop => _s(9);
  double get avatarDiameter => _s(60);

  /// Name and company start 1.5pt in from where their ink does.
  double get nameLeft => _s(83);
  double get nameTop =>
      capTop(20.5, size: nameSize, line: nameLine, calSans: true);
  double get companyTop => capTop(46.5, size: companySize, line: bodyLine);

  /// Name and company stop short of the card's right edge by this much.
  double get textRight => _s(16);

  double get statusLeft => _s(17.3);
  double get statusTop => capTop(88.5, size: bodySize, line: bodyLine);

  /// The row of buttons, and the line under the status that it starts on.
  /// The status is one line, so the row moves down with the text size by
  /// exactly the amount the status line grew.
  double get buttonsTop =>
      _s(110.5) + (font(bodySize) - _s(bodySize)) * bodyLine;
  double get actionLeft => _s(20);
  double get buttonWidth => _s(92);
  double get buttonHeight => _s(34);
  double get buttonGap => _s(4.5);

  /// `Tarixçə`'s left edge beside the action button — and alone, when the
  /// day is finished and there is no action left.
  double historyButtonLeft({required bool withAction}) =>
      withAction ? actionLeft + buttonWidth + buttonGap : actionLeft;

  double get cardBottomPad => _s(14);

  /// The card shut: buttons plus the pad under them.
  double get cardClosedHeight => buttonsTop + buttonHeight + cardBottomPad;

  // ── the history panel ───────────────────────────────────────────────────

  /// `#EFEFEF`, 230pt wide, its top on the buttons' row.
  double get panelLeft => _s(17.5);
  double get panelWidth => _s(230);
  double get panelRadius => _s(16);

  /// `Tarixçəni gizlət` at its widest — the label plus 21pt either side.
  double get hideButtonPad => _s(21);

  /// From the panel's top to the first row's box: the button, then the gap
  /// that puts the first cap line 50pt down.
  double get rowsTop => buttonHeight + _s(11.85);

  /// A row: the kind and the time on one line, the note under it.
  static const double rowLabelLine = 1.25;
  static const double rowNoteLine = 1.2;
  double get rowLabelHeight => font(bodySize) * rowLabelLine;
  double get rowNoteHeight => font(noteSize) * rowNoteLine;

  /// The hairline between two rows, with its gaps.
  double get dividerGapAbove => _s(2.2);
  double get dividerThickness => _s(1);
  double get dividerGapBelow => _s(2.35);
  double get dividerInsetLeft => _s(14);
  double get dividerInsetRight => _s(13);

  double get rowInsetLeft => _s(12.2);
  double get rowInsetRight => _s(14.5);

  /// Under the last row.
  double get rowsBottomPad => _s(10.2);

  double rowHeight({required bool hasNote}) =>
      rowLabelHeight + (hasNote ? rowNoteHeight : 0);

  double get dividerHeight =>
      dividerGapAbove + dividerThickness + dividerGapBelow;

  /// The rows' total height, before any cap.
  double rowsHeight(Iterable<bool> notes) {
    double sum = 0;
    int count = 0;
    for (final bool hasNote in notes) {
      sum += rowHeight(hasNote: hasNote);
      count++;
    }
    if (count == 0) return _s(40);
    return sum + (count - 1) * dividerHeight;
  }

  /// The lowest the card may reach: clear of the nav bar by a margin.
  double cardFloor(double bottomReserve) =>
      screen.height - bottomReserve - _s(12);

  /// The panel's height for [notes], capped so the card stays above
  /// [floor]; the rows scroll inside it past that.
  double panelHeight(
    Iterable<bool> notes, {
    required double cardTop,
    required double floor,
  }) {
    final double natural = rowsTop + rowsHeight(notes) + rowsBottomPad;
    final double room = floor - cardTop - buttonsTop - cardBottomPad;
    final double least = rowsTop + rowHeight(hasNote: true) + rowsBottomPad;
    return math.max(least, math.min(natural, room));
  }

  double cardOpenHeight(double panelHeight) =>
      buttonsTop + panelHeight + cardBottomPad;

  // ── the prompts (liquid glass) ──────────────────────────────────────────

  double get promptWidth => math.min(_s(296), screen.width - 2 * _s(20));
  double get promptRadius => _s(35);
  double get promptPadTop => _s(16.7);
  double get promptPadBottom => _s(17);
  double get promptSidePad => _s(16);
  double get promptLineHeight => font(promptSize) * promptLine;
  double get promptGapToButtons => _s(13.55);

  /// The two capsules under a message: 115 × 43, 13 apart, centred.
  double get promptButtonWidth => _s(115);
  double get promptButtonHeight => _s(43);
  double get promptButtonGap => _s(13);

  /// `Yazılı bildir`: the box, and the two smaller capsules right-aligned
  /// under it.
  double get fieldGapAbove => _s(6);
  double get fieldHeight => _s(103.5);
  double get fieldRadius => _s(20);
  double get fieldGapBelow => _s(6.5);
  double get fieldPadH => _s(12);
  double get fieldPadV => _s(11);
  double get smallButtonWidth => _s(92.5);
  double get smallButtonGap => _s(9.5);
  double get smallButtonRight => _s(14.5);

  double get promptTextWidth => promptWidth - 2 * promptSidePad;

  /// A message of [lines] lines over a row of buttons.
  double messagePromptHeight(int lines) =>
      promptPadTop +
      lines * promptLineHeight +
      promptGapToButtons +
      promptButtonHeight +
      promptPadBottom;

  /// The title, the box and the buttons — for a one-line title.
  double get writtenPromptHeight => writtenPromptHeightFor(promptLineHeight);

  /// The same, for a title measured at [title] tall.
  double writtenPromptHeightFor(double title) =>
      promptPadTop +
      title +
      fieldGapAbove +
      fieldHeight +
      fieldGapBelow +
      promptButtonHeight +
      promptPadBottom;

  /// Every prompt shares one top edge — the shortest one centred on the
  /// screen — so a prompt that turns into a taller one grows downwards and
  /// its title never jumps. Lifted, never lowered, when the keyboard would
  /// cover its bottom.
  double promptTop(double height) {
    final double centred = (screen.height - messagePromptHeight(1)) / 2;
    final double lowest = screen.height - keyboard - _s(16) - height;
    final double highest = padding.top + _s(8);
    return math.max(highest, math.min(centred, lowest));
  }

  Rect promptRect(double height) => Rect.fromLTWH(
    (screen.width - promptWidth) / 2,
    promptTop(height),
    promptWidth,
    height,
  );
}
