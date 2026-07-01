import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';

class SwipeResponsiveGf44Headline extends StatefulWidget {
  const SwipeResponsiveGf44Headline({super.key, required this.controller});

  final PageController controller;

  @override
  State<SwipeResponsiveGf44Headline> createState() =>
      _SwipeResponsiveGf44HeadlineState();
}

class _SwipeResponsiveGf44HeadlineState
    extends State<SwipeResponsiveGf44Headline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _textController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handlePageTick);
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didUpdateWidget(covariant SwipeResponsiveGf44Headline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePageTick);
      widget.controller.addListener(_handlePageTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePageTick);
    _textController.dispose();
    super.dispose();
  }

  void _handlePageTick() {
    final double page = _currentPage;
    if (page > 0.72 && _textController.value == 0) {
      _textController.forward();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _textController,
          builder: (context, _) {
            final Size screen = MediaQuery.sizeOf(context);
            final double page = _currentPage;
            final double enterOpacity = ((page - 0.78) / 0.22)
                .clamp(0.0, 1.0)
                .toDouble();
            final double exitOpacity =
                (1 - (page - 2).clamp(0.0, 1.0)).toDouble();
            final double opacity = enterOpacity * exitOpacity;
            final double moveT = Curves.easeInOutCubic.transform(
              (page - 1).clamp(0.0, 1.0).toDouble(),
            );

            final double top = _lerp(
              (screen.height * 0.395).clamp(310.0, 380.0).toDouble(),
              (screen.height * 0.330).clamp(246.0, 318.0).toDouble(),
              moveT,
            );
            final double size =
                (screen.width * 0.13).clamp(42.0, 58.0).toDouble();
            const String text = 'GF44';
            final int count = (text.length * _textController.value)
                .ceil()
                .clamp(0, text.length)
                .toInt();

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: opacity,
                    child: blurred(
                      16 * (1 - _textController.value),
                      Text(
                        text.substring(0, count),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'CalSans',
                          fontSize: size,
                          fontWeight: FontWeight.w400,
                          height: 1,
                          letterSpacing: 0.8,
                          shadows: _softBrandShadows,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double get _currentPage {
    if (widget.controller.hasClients &&
        widget.controller.position.haveDimensions) {
      return widget.controller.page ?? widget.controller.initialPage.toDouble();
    }
    return widget.controller.initialPage.toDouble();
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;
}

const List<Shadow> _softBrandShadows = <Shadow>[
  Shadow(
    color: Color(0x33000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];
