import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import 'animated_logo.dart';

/// Second onboarding page introducing GF44 with a compact brand lockup,
/// typewriter headline, and soft blur-reveal description.
class Gf44OverviewPage extends StatefulWidget {
  const Gf44OverviewPage({
    super.key,
    required this.pageController,
    required this.pageIndex,
  });

  final PageController pageController;
  final int pageIndex;

  @override
  State<Gf44OverviewPage> createState() => _Gf44OverviewPageState();
}

class _Gf44OverviewPageState extends State<Gf44OverviewPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const String _headline = 'GF44';
  static const String _description =
      'GF44 innovativ həlli ilə şirkətinizin bütün idarəetmə prosesi bir '
      'ekranda toplanır: tapşırıqlar, komanda, sənədlər, partnyorlar və '
      'hesabatlar — daha sürətli, daha şəffaf, daha peşəkar.';

  /// Keep this page finished if PageView rebuilds it later in the same session.
  static double _savedProgress = 0;
  static bool _hasStartedOnce = false;

  late final AnimationController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )
      ..value = _savedProgress.clamp(0.0, 1.0)
      ..addListener(_rememberProgress)
      ..addStatusListener(_rememberCompletion);

    widget.pageController.addListener(_startWhenPageIsNear);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenPageIsNear());
  }

  @override
  void didUpdateWidget(covariant Gf44OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_startWhenPageIsNear);
      widget.pageController.addListener(_startWhenPageIsNear);
    }
  }

  void _startWhenPageIsNear() {
    if (!mounted || _controller.value >= 1) return;

    final double page = _currentPage;
    final bool isNearThisPage = page >= widget.pageIndex - 0.42 &&
        page <= widget.pageIndex + 0.42;

    if (!isNearThisPage) return;

    if (!_hasStartedOnce) {
      _hasStartedOnce = true;
    }

    if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  double get _currentPage {
    final PageController controller = widget.pageController;
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }

  void _rememberProgress() {
    _savedProgress = _controller.value;
  }

  void _rememberCompletion(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _savedProgress = 1;
    }
  }

  @override
  void dispose() {
    _savedProgress = _controller.value;
    widget.pageController.removeListener(_startWhenPageIsNear);
    _controller
      ..removeListener(_rememberProgress)
      ..removeStatusListener(_rememberCompletion)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size screen = MediaQuery.sizeOf(context);
          final double availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screen.height;
          final double logoWidth = (screen.width * 0.33).clamp(116.0, 158.0);
          final double brandSize = (screen.width * 0.064).clamp(22.0, 30.0);
          final double headlineSize = (screen.width * 0.13).clamp(42.0, 58.0);
          final double descriptionSize =
              (screen.width * 0.052).clamp(17.0, 22.0);
          final double topOffset = (availableHeight * 0.018).clamp(8.0, 24.0);
          final double bottomReserve = 132 + MediaQuery.paddingOf(context).bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, bottomReserve),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double headerProgress = _interval(0.00, 0.30);
                final double headlineProgress = _interval(0.26, 0.68);
                final double descriptionProgress = _interval(0.62, 1.00);

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      top: topOffset,
                      left: 0,
                      right: 0,
                      child: _CompactBrandLockup(
                        progress: headerProgress,
                        logoWidth: logoWidth,
                        brandSize: brandSize,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0.28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _TypewriterBlurText(
                            progress: headlineProgress,
                            text: _headline,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'CalSans',
                              fontSize: headlineSize,
                              fontWeight: FontWeight.w400,
                              height: 1,
                              letterSpacing: 0.8,
                              shadows: _softShadows,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _BlurRevealText(
                            progress: descriptionProgress,
                            text: _description,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: descriptionSize,
                              fontWeight: FontWeight.w400,
                              height: 1.24,
                              letterSpacing: -0.15,
                              shadows: _softShadows,
                            ),
                            beginOffset: 18,
                            beginBlur: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  double _interval(double start, double end) {
    final double value = ((_controller.value - start) / (end - start))
        .clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(value);
  }
}

class _CompactBrandLockup extends StatelessWidget {
  const _CompactBrandLockup({
    required this.progress,
    required this.logoWidth,
    required this.brandSize,
  });

  final double progress;
  final double logoWidth;
  final double brandSize;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);
    final double opacity = Curves.easeOut.transform(t);
    final double scale = 1.22 - 0.22 * t;
    final double dy = 58 * (1 - t);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedGuvenLogo(
                width: logoWidth,
                progress: 1,
              ),
              const SizedBox(height: 6),
              Text(
                'Güvən Finans',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CalSans',
                  fontSize: brandSize,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  letterSpacing: -0.45,
                  shadows: _softShadows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypewriterBlurText extends StatelessWidget {
  const _TypewriterBlurText({
    required this.progress,
    required this.text,
    required this.style,
  });

  final double progress;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);
    final int visibleCount = (text.length * t).ceil().clamp(0, text.length);
    final String visibleText = text.substring(0, visibleCount);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Opacity(
          opacity: 0,
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
        Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              child: blurred(
                16 * (1 - t),
                Text(
                  visibleText,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurRevealText extends StatelessWidget {
  const _BlurRevealText({
    required this.progress,
    required this.text,
    required this.style,
    required this.beginOffset,
    required this.beginBlur,
  });

  final double progress;
  final String text;
  final TextStyle style;
  final double beginOffset;
  final double beginBlur;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);

    return Opacity(
      opacity: Curves.easeOut.transform(t),
      child: Transform.translate(
        offset: Offset(0, beginOffset * (1 - t)),
        child: blurred(
          beginBlur * (1 - t),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 7,
            overflow: TextOverflow.fade,
            style: style,
          ),
        ),
      ),
    );
  }
}

const List<Shadow> _softShadows = <Shadow>[
  Shadow(
    color: Color(0x30000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];
