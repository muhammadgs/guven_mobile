/// Touch lighting and deformation for app-owned glass surfaces.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../glass/app_glass.dart';

/// One lap of the highlight.
const Duration kGlassShimmerDuration = Duration(milliseconds: 520);

/// How much brighter the rim gets at the peak of the flash.
const double _kFlash = 0.85;

/// How tight the travelling highlight pulls in at that peak.
const double _kTightSpread = 0.12;

/// Extra ambient glow carried along with the flash.
const double _kGlow = 0.45;

/// Applies the press shimmer to both the renderer and rollback settings.
///
/// [towards] is in degrees so existing pointer-bearing calculations and the
/// legacy backend agree; renderer settings are converted to radians here.
AppGlassStyle shimmerAppGlassStyle(
  AppGlassStyle style,
  double t, {
  double? towards,
}) {
  if (t <= 0 || t >= 1) return style;

  final double pulse = math.sin(math.pi * t);
  final double sweep = Curves.easeOutCubic.transform(t);
  final double rendererAngle = towards == null
      ? style.settings.lightAngle + math.pi * 2 * sweep
      : towards * math.pi / 180;

  return style.copyWith(
    settings: style.settings.copyWith(
      lightAngle: rendererAngle,
      lightIntensity: style.settings.lightIntensity * (1 + _kFlash * pulse),
      ambientStrength: style.settings.ambientStrength * (1 + _kGlow * pulse),
    ),
    legacy: style.legacy.copyWith(
      lightDirection: towards ?? style.legacy.lightDirection + 360 * sweep,
      lightIntensity: style.legacy.lightIntensity * (1 + _kFlash * pulse),
      ambientIntensity: style.legacy.ambientIntensity * (1 + _kGlow * pulse),
      lightSpread: _lerp(style.legacy.lightSpread, _kTightSpread, pulse),
    ),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Bearing from the centre of [size] towards [local], in degrees.
double lightAngleTowards(Offset local, Size size) {
  final double dx = local.dx - size.width / 2;
  final double dy = local.dy - size.height / 2;
  return math.atan2(-dy, dx) * 180 / math.pi;
}

/// A renderer-backed glass button that deforms and flashes on touch-down.
class GlassPressButton extends StatefulWidget {
  const GlassPressButton({
    super.key,
    required this.width,
    required this.height,
    required this.cornerRadius,
    required this.style,
    required this.onTap,
    required this.child,
    this.shadow = const <BoxShadow>[],
    this.flex = const AppGlassFlex.pronounced(),
  });

  final double width;
  final double height;
  final double cornerRadius;
  final AppGlassStyle style;
  final VoidCallback onTap;
  final Widget child;
  final List<BoxShadow> shadow;
  final AppGlassFlex flex;

  @override
  State<GlassPressButton> createState() => _GlassPressButtonState();
}

class _GlassPressButtonState extends State<GlassPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: kGlassShimmerDuration,
  );

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppGlassStyle resting = glassAtRadius(
      widget.style,
      widget.cornerRadius,
    );

    return GestureDetector(
      onTapDown: (_) => _shimmer.forward(from: 0),
      onTap: widget.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.cornerRadius),
          boxShadow: widget.shadow,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _shimmer,
            child: widget.child,
            builder: (BuildContext context, Widget? child) {
              return AppGlassSurface(
                style: shimmerAppGlassStyle(resting, _shimmer.value),
                cornerRadius: widget.cornerRadius,
                flex: widget.flex,
                child: Center(child: child),
              );
            },
          ),
        ),
      ),
    );
  }
}
