import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';

/// Apple-style "liquid glass" page dots.
///
/// Inactive dots are translucent glass (a real backdrop blur of the aurora
/// behind them with a bright rim and top highlight). The active dot morphs to
/// solid white and, per the design, sits a touch *smaller* than the rest. The
/// active state is driven continuously by [page] so it glides while swiping.
class GlassPageIndicator extends StatelessWidget {
  const GlassPageIndicator({
    super.key,
    required this.page,
    required this.count,
  });

  /// Current (possibly fractional) page from the [PageController].
  final double page;
  final int count;

  static const double _spacing = 9;
  static const double _glassSize = 10;
  static const double _activeSize = 7;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: scaled(context, _spacing) / 2,
            ),
            child: _Dot(
              selected: (1 - (page - i).abs()).clamp(0.0, 1.0),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.selected});

  /// 0 = fully glass/inactive, 1 = fully white/active.
  final double selected;

  @override
  Widget build(BuildContext context) {
    final double size = scaled(
      context,
      lerpDouble(
        GlassPageIndicator._glassSize,
        GlassPageIndicator._activeSize,
        selected,
      )!,
    );
    final double fillAlpha = lerpDouble(0.16, 1.0, selected)!;
    final double borderAlpha = lerpDouble(0.45, 1.0, selected)!;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: fillAlpha),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
              width: 0.8,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.5 * (1 - selected)),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35 * selected),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
