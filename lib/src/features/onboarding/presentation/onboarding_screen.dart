import 'package:flutter/material.dart';

import '../../../shared/effects.dart';
import 'widgets/animated_logo.dart';
import 'widgets/gf44_data_hub_page.dart';
import 'widgets/glass_page_indicator.dart';
import 'widgets/glass_swipe_arrow.dart';
import 'widgets/welcome_brand_intro.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const int pageCount = 4;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _page {
    if (_pageController.hasClients &&
        _pageController.position.haveDimensions) {
      return _pageController.page ?? 0;
    }
    return 0;
  }

  void _goNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                _WelcomePage(controller: _pageController, index: 0),
                _Gf44Page(controller: _pageController, index: 1),
                _Gf44DataPage(controller: _pageController, index: 2),
                _PlaceholderPage(controller: _pageController, index: 3),
              ],
            ),
          ),
          _SwipeResponsiveBrandLockup(controller: _pageController),
          _SwipeResponsiveGf44Headline(controller: _pageController),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36 + bottomInset,
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                final double page = _page;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GlassPageIndicator(
                      page: page,
                      count: OnboardingScreen.pageCount,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 42,
                      child: GlassSwipeArrow(
                        visibility: (1 - page).clamp(0.0, 1.0),
                        onTap: _goNext,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeResponsiveBrandLockup extends StatefulWidget {
  const _SwipeResponsiveBrandLockup({required this.controller});

  final PageController controller;

  @override
  State<_SwipeResponsiveBrandLockup> createState() =>
      _SwipeResponsiveBrandLockupState();
}

class _SwipeResponsiveBrandLockupState extends State<_SwipeResponsiveBrandLockup>
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
  void didUpdateWidget(covariant _SwipeResponsiveBrandLockup oldWidget) {
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
            final double fadeAfterSecondPage =
                (1 - (page - 1).clamp(0.0, 1.0)).toDouble();
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
                    opacity: fadeAfterSecondPage,
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
    final PageController controller = widget.controller;
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }

  double _interval(double start, double end) {
    final double value = ((_introController.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(value);
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;
}

class _SwipeResponsiveGf44Headline extends StatefulWidget {
  const _SwipeResponsiveGf44Headline({required this.controller});

  final PageController controller;

  @override
  State<_SwipeResponsiveGf44Headline> createState() =>
      _SwipeResponsiveGf44HeadlineState();
}

class _SwipeResponsiveGf44HeadlineState
    extends State<_SwipeResponsiveGf44Headline>
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
  void didUpdateWidget(covariant _SwipeResponsiveGf44Headline oldWidget) {
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
              (screen.height * 0.43).clamp(340.0, 408.0).toDouble(),
              (screen.height * 0.36).clamp(292.0, 352.0).toDouble(),
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
    final PageController controller = widget.controller;
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
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

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.controller, required this.index});

  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final double bottomReserve = 150 + MediaQuery.paddingOf(context).bottom;

    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomReserve),
          child: const Center(child: WelcomeBrandIntro()),
        ),
      ),
    );
  }
}

class _Gf44Page extends StatelessWidget {
  const _Gf44Page({required this.controller, required this.index});

  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: _Gf44OverviewBody(controller: controller, index: index),
    );
  }
}

class _Gf44OverviewBody extends StatelessWidget {
  const _Gf44OverviewBody({required this.controller, required this.index});

  final PageController controller;
  final int index;

  static const String _description =
      'GF44 innovativ həlli ilə şirkətinizin bütün idarəetmə prosesi bir '
      'ekranda toplanır: tapşırıqlar, komanda, sənədlər, partnyorlar və '
      'hesabatlar — daha sürətli, daha şəffaf, daha peşəkar.';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final double page = _page;
          final double progress = ((page - 0.74) / 0.26)
              .clamp(0.0, 1.0)
              .toDouble();
          final double t = Curves.easeOutCubic.transform(progress);
          final Size screen = MediaQuery.sizeOf(context);
          final double headlineSize =
              (screen.width * 0.13).clamp(42.0, 58.0).toDouble();
          final double descriptionSize =
              (screen.width * 0.052).clamp(17.0, 22.0).toDouble();
          final double bottomReserve =
              132 + MediaQuery.paddingOf(context).bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, bottomReserve),
            child: Align(
              alignment: const Alignment(0, 0.28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: headlineSize),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: Curves.easeOut.transform(t),
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - t)),
                      child: blurred(
                        14 * (1 - t),
                        Text(
                          _description,
                          textAlign: TextAlign.center,
                          maxLines: 7,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: descriptionSize,
                            fontWeight: FontWeight.w400,
                            height: 1.24,
                            letterSpacing: -0.15,
                            shadows: _softBrandShadows,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double get _page {
    if (controller.hasClients && controller.position.haveDimensions) {
      return controller.page ?? controller.initialPage.toDouble();
    }
    return controller.initialPage.toDouble();
  }
}

class _Gf44DataPage extends StatelessWidget {
  const _Gf44DataPage({required this.controller, required this.index});

  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: Gf44DataHubPage(
        pageController: controller,
        pageIndex: index,
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.controller, required this.index});

  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: const SafeArea(
        child: Center(
          child: Text(
            'Tezliklə',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitOnSwipe extends StatelessWidget {
  const _ExitOnSwipe({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        double page = index.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? index.toDouble();
        }
        final double visibility =
            (1 - (page - index).abs()).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: visibility,
          child: blurred((1 - visibility) * 10, child!),
        );
      },
    );
  }
}
