import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The backdrop every signed-in screen sits on.
///
/// A pale wash with a few soft aurora shapes drifting through it, drawn from
/// the design's own vector so the blobs land where they were composed rather
/// than approximated in code.
///
/// It is deliberately quiet: everything above it is glass, and glass has
/// nothing to refract if the backdrop is flat — but anything busier and the
/// text on those surfaces stops being readable. It also never moves, which is
/// what lets a dozen lenses sample it without the whole screen repainting.
///
/// The counterpart to the pre-login [AuthBackground], which is a video and
/// dark; this one is still and light.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  static const String _asset = 'assets/images/background/home_aurora.svg';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Painted under the vector as well as around it: the artwork is a fixed
      // 463×874 portrait, and `cover` on a wider or taller device would
      // otherwise show through at the edges before the SVG has decoded.
      color: const Color(0xFFF2F7FE),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: SvgPicture.asset(
                _asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
