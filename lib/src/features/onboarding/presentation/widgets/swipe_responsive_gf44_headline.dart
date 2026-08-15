import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/layout.dart';

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
  static const String _pageThreeSubtitle =
      'GF44 ilə məlumatlarınızı\nmərkəzləşdirilmiş şəkildə idarə edin.';

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
            final double pageThreeSubtitleOpacity =
                ((page - 1.62) / 0.38).clamp(0.0, 1.0).toDouble() *
                    exitOpacity;

            final double top = _lerp(
              (screen.height * 0.395).clamp(310.0, scaled(context, 380)).toDouble(),
              (screen.height * 0.330).clamp(246.0, scaled(context, 318)).toDouble(),
              moveT,
            );
            final double headlineSize =
                responsive(context, factor: 0.13, min: 42, max: 58);
            final double subtitleSize =
                responsive(context, factor: 0.047, min: 16, max: 21);
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        blurred(
                          16 * (1 - _textController.value),
                          Text(
                            text.substring(0, count),
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CalSans',
                              fontSize: headlineSize,
                              fontWeight: FontWeight.w400,
                              height: 1,
                              letterSpacing: 0.8,
                              shadows: _softBrandShadows,
                            ),
                          ),
                        ),
                        SizedBox(height: scaled(context, 10)),
                        Opacity(
                          opacity: pageThreeSubtitleOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - pageThreeSubtitleOpacity)),
                            child: blurred(
                              10 * (1 - pageThreeSubtitleOpacity),
                              Text(
                                _pageThreeSubtitle,
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.18,
                                  letterSpacing: -0.2,
                                  shadows: _softBrandShadows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
