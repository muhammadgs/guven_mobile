
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/glass/app_glass.dart';
import '../settings_metrics.dart';

/// One row on `Tənzimləmələr`: a glyph and a label on a fully round pill.
///
/// Not glass, like `Baza`'s rows: a flat tint over a plain background blur,
/// which is what the design draws.
///
/// [presence] fades it in and out by its colours, never by an `Opacity`: an
/// opacity layer is a `saveLayer`, and a backdrop blur inside one has nothing
/// left to blur.
class SettingsPill extends StatefulWidget {
  const SettingsPill({
    super.key,
    required this.metrics,
    required this.label,
    required this.icon,
    required this.iconLeft,
    required this.iconSize,
    required this.labelLeft,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.presence = 1,
  });

  final SettingsMetrics metrics;
  final String label;
  final String icon;

  /// From the pill's left edge to the glyph's box, on the design frame.
  final double iconLeft;

  /// The glyph's box, on the design frame.
  final Size iconSize;

  /// From the pill's left edge to the label's box, on the design frame.
  final double labelLeft;

  final Color fill;
  final Color ink;

  final VoidCallback? onTap;

  /// 0 gone, 1 fully there.
  final double presence;

  @override
  State<SettingsPill> createState() => _SettingsPillState();
}

class _SettingsPillState extends State<SettingsPill> {
  bool _down = false;

  void _press(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsMetrics m = widget.metrics;
    final double s = m.scale;
    final double p = widget.presence.clamp(0.0, 1.0);
    final double height = m.pillHeight;

    // A press darkens the tint a shade, as `Baza`'s menu rows do.
    final Color fill = _down
        ? Color.alphaBlend(const Color(0x12000000), widget.fill)
        : widget.fill;
    final Color shownFill = fill.withValues(alpha: fill.a * p);
    final Color ink = widget.ink.withValues(alpha: widget.ink.a * p);

    Widget body = ColoredBox(
      color: shownFill,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: widget.iconLeft * s,
            top: 0,
            bottom: 0,
            child: Center(
              child: SvgPicture.asset(
                widget.icon,
                width: widget.iconSize.width * s,
                height: widget.iconSize.height * s,
                // Both glyphs wear the label's colour, so they fade with it.
                colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              ),
            ),
          ),
          Positioned(
            left: widget.labelLeft * s,
            right: 16 * s,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              // A long label on a narrow phone is set smaller, never cut.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: ink,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: SettingsMetrics.labelSize * s,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (p > 0) {
      body = AppBackdropBlur(
        sigma: kSettingsPillBlurSigma,
        amount: p,
        child: body,
      );
    }

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// Blur under a pill: `Baza`'s rows' (Figma's 15, halved into a sigma), so
/// the two pages read as one app.
const double kSettingsPillBlurSigma = 7.5;

/// `Hesab`'s tint: grey `A2A2A2` at 20%, which the design's pixels match to
/// within one level — the same as `Baza`'s rows.
const Color kSettingsPillFill = Color(0x33A2A2A2);

/// `Çıxış edin`'s tint. Figma calls it red at 20%; on its own export that
/// layer reads as pure red at 12% over the page (green and blue both fall by
/// exactly 12%), so this is the value that looks like the design.
const Color kSettingsExitFill = Color(0x1FFF0000);

/// `Çıxış edin`'s label: the same red as its glyph.
const Color kSettingsExitInk = Color(0xFFFF0000);
