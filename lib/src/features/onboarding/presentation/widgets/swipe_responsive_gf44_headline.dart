import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/settled_page_controller.dart';
import '../onboarding_metrics.dart';
import 'swipe_responsive_brand_lockup.dart' show kOnboardingTextShadows;

/// The "GF44" headline and its subtitle, floating above pages two and three.
///
/// Like the brand lockup, it reads its position from [OnboardingMetrics] so
/// the paragraph and the icon grid underneath can anchor to its measured
/// bottom edge instead of guessing at it.
class SwipeResponsiveGf44Headline extends StatefulWidget {
  const SwipeResponsiveGf44Headline({super.key, required this.controller});

  final SettledPageController controller;

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
            final double page = _currentPage;
            final Gf44HeadlineGeometry geometry =
                OnboardingMetrics.of(context).headlineAt(page);

            final double enterOpacity =
                ((page - 0.78) / 0.22).clamp(0.0, 1.0).toDouble();
            final double exitOpacity =
                (1 - (page - 2).clamp(0.0, 1.0)).toDouble();
            final double opacity = enterOpacity * exitOpacity;
            final double subtitleOpacity =
                ((page - 1.62) / 0.38).clamp(0.0, 1.0).toDouble() * exitOpacity;

            const String text = 'GF44';
            final int count = (text.length * _textController.value)
                .ceil()
                .clamp(0, text.length)
                .toInt();

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: geometry.top,
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
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CalSans',
                              fontSize: geometry.headlineSize,
                              fontWeight: FontWeight.w400,
                              height: 1,
                              letterSpacing: 0.8,
                              shadows: kOnboardingTextShadows,
                            ),
                          ),
                        ),
                        SizedBox(height: geometry.gap),
                        Opacity(
                          opacity: subtitleOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - subtitleOpacity)),
                            child: blurred(
                              10 * (1 - subtitleOpacity),
                              Text(
                                _pageThreeSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: geometry.subtitleSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.18,
                                  letterSpacing: -0.2,
                                  shadows: kOnboardingTextShadows,
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

  double get _currentPage => widget.controller.settledPage;
}
