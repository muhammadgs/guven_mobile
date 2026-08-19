import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/settled_page_controller.dart';
import '../onboarding_metrics.dart';
import 'animated_logo.dart';

/// The logo and wordmark, floating above the pages and travelling between
/// them as the user swipes.
///
/// It no longer computes where it sits — [OnboardingMetrics.lockupAt] does,
/// and the page bodies read the very same geometry to place themselves
/// underneath it. This widget owns only the intro animation.
class SwipeResponsiveBrandLockup extends StatefulWidget {
  const SwipeResponsiveBrandLockup({super.key, required this.controller});

  final SettledPageController controller;

  @override
  State<SwipeResponsiveBrandLockup> createState() =>
      _SwipeResponsiveBrandLockupState();
}

class _SwipeResponsiveBrandLockupState extends State<SwipeResponsiveBrandLockup>
    with SingleTickerProviderStateMixin {
  static const Duration _introDelay = Duration(seconds: 2);

  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handlePageTick);
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    );
    _startIntro();
  }

  Future<void> _startIntro() async {
    await Future<void>.delayed(_introDelay);
    if (mounted) _introController.forward();
  }

  @override
  void didUpdateWidget(covariant SwipeResponsiveBrandLockup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePageTick);
      widget.controller.addListener(_handlePageTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePageTick);
    _introController.dispose();
    super.dispose();
  }

  void _handlePageTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _introController,
          builder: (context, _) {
            final BrandLockupGeometry geometry =
                OnboardingMetrics.of(context).lockupAt(_currentPage);
            final double logoIntroProgress = _interval(0.00, 0.56);
            final double brandIntroProgress = _interval(0.20, 0.40);
            final double brandTextOpacity =
                Curves.easeOut.transform(brandIntroProgress) *
                    geometry.brandSlot;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: geometry.top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedGuvenLogo(
                          width: geometry.logoWidth,
                          progress: logoIntroProgress,
                        ),
                        SizedBox(height: geometry.gap),
                        Opacity(
                          opacity: brandTextOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 13 * (1 - brandIntroProgress)),
                            child: blurred(
                              13 * (1 - brandIntroProgress),
                              Text(
                                'Güvən Finans',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'CalSans',
                                  fontSize: geometry.brandSize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.05,
                                  letterSpacing: geometry.brandLetterSpacing,
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

  double _interval(double start, double end) {
    final double value = ((_introController.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(value);
  }
}

/// The soft lift every piece of onboarding type carries over the aurora.
const List<Shadow> kOnboardingTextShadows = <Shadow>[
  Shadow(
    color: Color(0x33000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];
