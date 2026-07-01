import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import 'animated_logo.dart';

class SwipeResponsiveBrandLockup extends StatefulWidget {
  const SwipeResponsiveBrandLockup({super.key, required this.controller});

  final PageController controller;

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
            final Size screen = MediaQuery.sizeOf(context);
            final EdgeInsets padding = MediaQuery.paddingOf(context);
            final double page = _currentPage;
            final double pageT = page.clamp(0.0, 1.0).toDouble();
            final double moveT = Curves.easeInOutCubic.transform(pageT);

            // Keep the shared Güvən Finans lockup visible on page 3 as well.
            final double opacity =
                (1 - (page - 2).clamp(0.0, 1.0)).toDouble();

            final double logoIntroProgress = _interval(0.00, 0.56);
            final double brandIntroProgress = _interval(0.20, 0.40);
            final double startLogoWidth =
                (screen.width * 0.58).clamp(190.0, 270.0).toDouble();
            final double endLogoWidth =
                (screen.width * 0.33).clamp(116.0, 158.0).toDouble();
            final double logoWidth = _lerp(startLogoWidth, endLogoWidth, moveT);

            final double startBrandSize =
                (screen.width * 0.092).clamp(30.0, 42.0).toDouble();
            final double endBrandSize =
                (screen.width * 0.064).clamp(22.0, 30.0).toDouble();
            final double brandSize = _lerp(startBrandSize, endBrandSize, moveT);

            final double startTop =
                (screen.height * 0.305).clamp(218.0, 286.0).toDouble();
            final double endTop = padding.top +
                (screen.height * 0.07).clamp(48.0, 72.0).toDouble();
            final double top = _lerp(startTop, endTop, moveT);

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: opacity,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedGuvenLogo(
                            width: logoWidth,
                            progress: logoIntroProgress,
                          ),
                          SizedBox(height: _lerp(14, 6, moveT)),
                          Opacity(
                            opacity: Curves.easeOut.transform(
                              brandIntroProgress,
                            ),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                13 * (1 - brandIntroProgress),
                              ),
                              child: blurred(
                                13 * (1 - brandIntroProgress),
                                Text(
                                  'Güvən Finans',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'CalSans',
                                    fontSize: brandSize,
                                    fontWeight: FontWeight.w400,
                                    height: 1.05,
                                    letterSpacing: _lerp(-0.7, -0.45, moveT),
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

  double _interval(double start, double end) {
    final double value = ((_introController.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(value);
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
