import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/glass/app_glass.dart';

import '../passcode_metrics.dart';
import '../passcode_style.dart';
import 'passcode_text.dart';

/// One digit on the keypad: a round glass button with Flutter's own ripple.
class PasscodeKey extends StatelessWidget {
  const PasscodeKey({
    super.key,
    required this.metrics,
    required this.digit,
    required this.rect,
    required this.onDigit,
    this.appear = 1,
  });

  final PasscodeMetrics metrics;
  final String digit;
  final Rect rect;
  final ValueChanged<String> onDigit;

  /// 0 hidden, 1 in place: the key blooms in (and out) by size, never by an
  /// opacity over its glass.
  ///
  /// There is deliberately no `enabled`: greying a key out with an
  /// `Opacity` over its glass would empty the blur. The screen ignores input
  /// instead.
  final double appear;

  @override
  Widget build(BuildContext context) {
    final double grow = Curves.easeOutBack.transform(appear.clamp(0.0, 1.0));
    final double ink = Curves.easeIn.transform(appear.clamp(0.0, 1.0));
    return Positioned.fromRect(
      rect: rect,
      child: grow <= 0.01
          ? const SizedBox.shrink()
          : Transform.scale(
              scale: grow,
              child: Semantics(
                button: true,
                label: digit,
                excludeSemantics: true,
                child: AppGlassButton(
                  style: kPasscodeKeyGlass,
                  cornerRadius: rect.shortestSide / 2,
                  splashColor: kPasscodeKeySplash,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDigit(digit);
                  },
                  child: Center(
                    child: CapCenteredText(
                      text: digit,
                      capRatio: PasscodeMetrics.poppinsFigure,
                      style: passcodeDigitStyle(
                        metrics.digitSize,
                      ).copyWith(color: Colors.white.withValues(alpha: ink)),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// A key with no glass — `Sil`, `Daxil ola bilmirəm`, `İndi yox`. It dims
/// under the finger the way iOS's text buttons do.
class PasscodeTextKey extends StatefulWidget {
  const PasscodeTextKey({
    super.key,
    required this.rect,
    required this.onTap,
    required this.child,
    this.visible = 1,
    this.semanticLabel,
  });

  final Rect rect;
  final VoidCallback? onTap;
  final Widget child;

  /// 0–1; the label's own alpha is scaled by it, and below a sliver it stops
  /// taking taps.
  final double visible;
  final String? semanticLabel;

  @override
  State<PasscodeTextKey> createState() => _PasscodeTextKeyState();
}

class _PasscodeTextKeyState extends State<PasscodeTextKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool live = widget.visible > 0.05 && widget.onTap != null;
    final double alpha = widget.visible.clamp(0.0, 1.0) * (_down ? 0.45 : 1);
    return Positioned.fromRect(
      rect: widget.rect,
      child: IgnorePointer(
        ignoring: !live,
        child: Semantics(
          button: true,
          enabled: live,
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: live ? (_) => setState(() => _down = true) : null,
            onTapCancel: live ? () => setState(() => _down = false) : null,
            onTapUp: live ? (_) => setState(() => _down = false) : null,
            onTap: live
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onTap!();
                  }
                : null,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: alpha),
                duration: const Duration(milliseconds: 120),
                builder: (BuildContext context, double a, Widget? child) {
                  // Alpha through the text colour, not an `Opacity`: these
                  // labels are plain text, but the habit is what keeps glass
                  // elsewhere from going black.
                  return DefaultTextStyle.merge(
                    style: TextStyle(color: Colors.white.withValues(alpha: a)),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: Colors.white.withValues(alpha: a),
                      ),
                      child: child!,
                    ),
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
