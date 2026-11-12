/// Colours and glass for Davamiyyət, sampled off the design's exports.
library;

import 'package:flutter/material.dart';

import '../../../shared/glass/app_glass.dart';
import '../domain/attendance.dart';

/// All text on the card and in the prompts is black in the design.
const Color kAttendanceInk = Color(0xFF000000);

/// The card is white and opaque — explicitly not glass.
const Color kAttendanceCard = Color(0xFFFFFFFF);

/// The avatar's disc.
const Color kAttendanceAvatar = Color(0xFFDDDDDD);

/// The card's buttons are flat fills.
const Color kEntryFill = Color(0xFFBEF3B6);
const Color kExitFill = Color(0xFFF2E0B6);
const Color kHistoryFill = Color(0xFFE0E0E0);

/// The history panel behind the rows.
const Color kHistoryPanel = Color(0xFFEFEFEF);

/// `Giriş edilməyib`.
const Color kStatusAbsent = Color(0xFFF70000);

/// `Giriş edilib`.
const Color kStatusPresent = Color(0xFF05C400);

/// `Giriş` in the history — a shade lighter than the status' green, as
/// drawn.
const Color kHistoryEntry = Color(0xFF36D507);

/// `Çıxış` in the history, and the status once the day is over. The user
/// asked for exits in yellow; a true yellow on `#EFEFEF` cannot be read, so
/// this is the darkest yellow that still reads as one.
const Color kHistoryExit = Color(0xFFE0A100);

/// Loading and failure in the status line.
const Color kStatusMuted = Color(0x99000000);

/// What is behind the card and the prompts: a heavy blur and a grey wash,
/// measured off the design's background (`#F7FBFF` → `#9EA0A4`).
const Color kAttendanceScrim = Color(0x5C000000);
const double kAttendanceBlur = 9;

/// The same, lighter, when a prompt opens over the card — the card is
/// already sitting on a wash and two of them read as night.
const Color kAttendanceScrimOverCard = Color(0x24000000);
const double kAttendanceBlurOverCard = 5;

Color fillFor(AttendanceKind kind) =>
    kind == AttendanceKind.entry ? kEntryFill : kExitFill;

/// The prompt's pane: a pale glass over the washed-out screen.
const AppGlassStyle kPromptGlass = AppGlassStyle(
  cornerRadius: 35,
  glassColor: Color(0x9EFFFFFF),
  blur: 6,
);

/// A capsule on the prompt, sitting on the pale pane.
AppGlassStyle promptButtonGlass(Color tint) =>
    AppGlassStyle(cornerRadius: 22, glassColor: tint, blur: 0);

/// `Sonra`, `İcazəli`, `Ləğv et`… — whiter than the pane under it.
const Color kPromptPlainTint = Color(0x73FFFFFF);

/// `Giriş`: green glass.
const Color kPromptEntryTint = Color(0x805CC65C);

/// `Çıxış`: the card's exit yellow, as glass.
const Color kPromptExitTint = Color(0x80FFC864);

/// The reason box — whiter than the pane, a touch less than a button.
const Color kPromptFieldTint = Color(0x59FFFFFF);

Color promptTintFor(AttendanceKind kind) =>
    kind == AttendanceKind.entry ? kPromptEntryTint : kPromptExitTint;

/// One text style for the whole feature: Poppins, black, even leading so a
/// box's cap line is where `AttendanceMetrics.capTop` says.
TextStyle attendanceText(
  double size, {
  double line = 1.4,
  Color color = kAttendanceInk,
  FontWeight weight = FontWeight.w400,
  FontStyle style = FontStyle.normal,
  double tracking = 0,
  String family = 'Poppins',
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: line,
  leadingDistribution: TextLeadingDistribution.even,
  color: color,
  fontWeight: weight,
  fontStyle: style,
  letterSpacing: tracking,
);
