import 'package:flutter/material.dart';

import '../../../shared/effects.dart';
import 'widgets/gf44_data_hub_page.dart';
import 'widgets/glass_page_indicator.dart';
import 'widgets/glass_swipe_arrow.dart';
import 'widgets/swipe_responsive_brand_lockup.dart';
import 'widgets/swipe_responsive_gf44_headline.dart';
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
          SwipeResponsiveBrandLockup(controller: _pageController),
          SwipeResponsiveGf44Headline(controller: _pageController),
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
      child: _Gf44OverviewBody(controller: controller),
    );
  }
}

class _Gf44OverviewBody extends StatelessWidget {
  const _Gf44OverviewBody({required this.controller});

  final PageController controller;

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
          final double progress = ((_page - 0.74) / 0.26)
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
              alignment: const Alignment(0, 0.24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: headlineSize),
                  const SizedBox(height: 20),
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
                            shadows: _softTextShadows,
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

const List<Shadow> _softTextShadows = <Shadow>[
  Shadow(
    color: Color(0x33000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];
