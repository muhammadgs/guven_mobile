import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../../../shared/motion/glass_touch_surface.dart';
import 'home_glass.dart';

/// One of the three counts under the greeting: a label on the left, a number
/// on the right, a single pane of glass under both.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.height,
    this.pending = false,
  });

  final String label;

  /// The count. Ignored while [pending].
  final int value;

  final double height;

  /// True before the first load lands — the pill draws a dash rather than a
  /// zero, because "0 əməkdaş" and "not counted yet" are different claims and
  /// only one of them is true.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: kGlassLift,
      ),
      child: SizedBox(
        height: height,
        child: GlassTouchSurface(
          style: kStatPillGlass,
          cornerRadius: height / 2,
          flex: const AppGlassFlex.statPill(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scaled(context, 26)),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: kGlassInk,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      fontSize: responsive(
                        context,
                        factor: 0.058,
                        min: 19,
                        max: 24,
                      ),
                      height: 1.05,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                SizedBox(width: scaled(context, 12)),
                // Swapped rather than cross-faded: the number is the one
                // thing on this screen that must never be ambiguous, and a
                // half-faded digit is exactly that.
                Text(
                  pending ? '—' : '$value',
                  style: TextStyle(
                    color: pending ? kGlassInkMuted : kGlassInk,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: responsive(
                      context,
                      factor: 0.058,
                      min: 19,
                      max: 24,
                    ),
                    height: 1.05,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
