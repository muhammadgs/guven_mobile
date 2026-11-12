import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../shared/layout.dart';
import '../domain/passcode_hash.dart';

/// Where everything on the passcode screens sits.
///
/// Measured off the two designs (402 × 874pt iPhone frame, 2× exports) on
/// 2026-11-12, every number below is in design points and is relative to one
/// origin: the centre of the keypad's first row. The whole composition — title
/// down to the `0` key — is one block, placed as a block in the usable band
/// (status bar → bottom inset) at the same fraction the design leaves above
/// it, so nothing in it can drift against anything else on another phone.
@immutable
class PasscodeMetrics {
  const PasscodeMetrics._({
    required this.screen,
    required this.scale,
    required this.origin,
    required this.textScale,
  });

  factory PasscodeMetrics.of(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return PasscodeMetrics.resolve(
      screen: MediaQuery.sizeOf(context),
      safe: MediaQuery.paddingOf(context),
      baseScale: uiScaleForFrame(context, frameWidth),
      // Only the ratio matters here; 16 is the subtitle size.
      textScale: scaler.scale(16) / 16,
    );
  }

  /// The pure arithmetic, so the device-matrix test can run it without a
  /// widget tree.
  factory PasscodeMetrics.resolve({
    required Size screen,
    required EdgeInsets safe,
    required double baseScale,
    double textScale = 1,
  }) {
    final double bandTop = safe.top;
    // Android hides its navigation bar (`MainActivity`), leaving no bottom
    // inset at all; a floor keeps the `0` key off the physical edge.
    final double bandBottom =
        screen.height - math.max(safe.bottom, _minBottomInset * baseScale);
    final double band = bandBottom - bandTop;

    final double above = _above(textScale);
    final double needed = above + _below;

    double scale = baseScale;
    final double minGaps = 2 * _minGap;
    if ((needed + minGaps) * scale > band) {
      scale = band / (needed + minGaps);
    }

    final double free = band - needed * scale;
    final double top = bandTop + free * _topShare;
    final double originY = top + above * scale;
    return PasscodeMetrics._(
      screen: screen,
      scale: scale,
      origin: Offset(screen.width / 2, originY),
      textScale: textScale,
    );
  }

  /// The design was drawn on an iPhone 16 Pro.
  static const double frameWidth = 402;

  // ── Design numbers (points on the 402 frame) ──────────────────────────────

  /// Key glass, rim to rim.
  static const double _keyDiameter = 70.5;

  /// Centre to centre across a row (22pt between keys) …
  static const double _columnPitch = 92.5;

  /// … and down a column (23.25pt between keys).
  static const double _rowPitch = 93.75;

  static const double _dotDiameter = 12;

  /// The export spaces the dots 19, 21, 19pt apart — a slip; this is their
  /// mean, which keeps the row centred where the design centres it.
  static const double _dotPitch = 19.75;

  /// Dots' centre line, above the first row's centre.
  static const double _dotsAbove = 62.5;

  /// Title baseline above the first row's centre — the same in both designs.
  static const double _titleBaselineAbove = 150.5;

  /// Subtitle baseline above the first row's centre.
  static const double _subtitleBaselineAbove = 120.25;

  /// CalSans cap height per point of size (measured `X`: 19.75pt at 28).
  static const double _calSansCap = 0.705;

  /// Poppins figure height per point of size (`1`, `2`: 26pt at 36).
  static const double poppinsFigure = 0.722;

  /// Poppins cap height per point of size (`T`: 11.2pt at 16).
  static const double poppinsCap = 0.70;

  /// Welcome title size (`Xoş Gəldiniz, …`) — the setup design sets it larger
  /// than the unlock greeting.
  static const double _welcomeSize = 28;

  /// Unlock greeting size (`Sabahınız xeyir, …`).
  static const double _greetingSize = 24;

  static const double _subtitleSize = 16;
  static const double _digitSize = 36;
  static const double _sideLabelSize = 17;

  /// `Daxil ola` / `bilmirəm`: baselines 19pt apart at 17pt.
  static const double sideLabelLineHeight = 19 / 17;

  /// Fraction of the band's free space that goes above the composition:
  /// 189pt above, 102.25pt below in the design.
  static const double _topShare = 189 / (189 + 102.25);

  static const double _minGap = 16;
  static const double _minBottomInset = 24;

  /// Side margin the title keeps from the screen edge before it shrinks.
  static const double _titleMargin = 22;

  static double _above(double textScale) =>
      _titleBaselineAbove + _welcomeSize * _calSansCap * textScale;

  /// Fourth row's centre plus half a key.
  static const double _below = 3 * _rowPitch + _keyDiameter / 2;

  // ── Resolved ──────────────────────────────────────────────────────────────

  final Size screen;

  /// Design points → logical pixels on this device.
  final double scale;

  /// Centre of the keypad's first row, in screen coordinates.
  final Offset origin;

  /// The system text scale, already clamped by the app.
  final double textScale;

  double get keyDiameter => _keyDiameter * scale;
  double get dotDiameter => _dotDiameter * scale;
  double get columnPitch => _columnPitch * scale;
  double get rowPitch => _rowPitch * scale;

  /// [row] 0–3 and [column] 0–2, as on the keypad.
  Offset keyCenter(int row, int column) => Offset(
    origin.dx + (column - 1) * columnPitch,
    origin.dy + row * rowPitch,
  );

  Rect keyRect(int row, int column) => Rect.fromCenter(
    center: keyCenter(row, column),
    width: keyDiameter,
    height: keyDiameter,
  );

  /// The cell a key's label may use — the key itself for a digit, the whole
  /// column pitch for `Daxil ola bilmirəm`, which has no glass.
  Rect cellRect(int row, int column) => Rect.fromCenter(
    center: keyCenter(row, column),
    width: columnPitch,
    height: rowPitch,
  );

  Rect get keypadRect =>
      keyRect(0, 0).expandToInclude(keyRect(3, 2));

  Offset get dotsCenter => Offset(origin.dx, origin.dy - _dotsAbove * scale);

  Offset dotCenter(int index) => Offset(
    dotsCenter.dx + (index - (kPasscodeLength - 1) / 2) * _dotPitch * scale,
    dotsCenter.dy,
  );

  Rect get dotsRect => Rect.fromCenter(
    center: dotsCenter,
    width: ((kPasscodeLength - 1) * _dotPitch + _dotDiameter) * scale,
    height: dotDiameter,
  );

  double get titleBaseline => origin.dy - _titleBaselineAbove * scale;
  double get subtitleBaseline => origin.dy - _subtitleBaselineAbove * scale;

  double get titleMaxWidth => screen.width - 2 * _titleMargin * scale;

  double get welcomeSize => _welcomeSize * scale;
  double get greetingSize => _greetingSize * scale;
  double get subtitleSize => _subtitleSize * scale;
  double get digitSize => _digitSize * scale;
  double get sideLabelSize => _sideLabelSize * scale;

  /// Top of the welcome title's capitals, with the system text scale — the
  /// highest ink on the screen.
  double get compositionTop =>
      titleBaseline - _welcomeSize * _calSansCap * textScale * scale;

  double get compositionBottom => keypadRect.bottom;

  // ── The biometric question (no design; built from the keypad's grid) ──────

  /// The glass disc with the fingerprint / face glyph, where rows one and two
  /// were.
  Rect get biometricDisc => Rect.fromCenter(
    center: Offset(origin.dx, origin.dy + rowPitch / 2),
    width: keyDiameter * 1.6,
    height: keyDiameter * 1.6,
  );

  /// `Aktivləşdir` — a capsule as wide as the keypad, on row three.
  Rect get biometricAccept => Rect.fromCenter(
    center: keyCenter(2, 1),
    width: keypadRect.width,
    height: 56 * scale,
  );

  /// `İndi yox` — plain text on row four, like `Sil`.
  Rect get biometricDecline => Rect.fromCenter(
    center: keyCenter(3, 1),
    width: keypadRect.width,
    height: rowPitch,
  );
}
