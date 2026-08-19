import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/effects.dart';
import '../../../shared/layout.dart';
import '../../../shared/settled_page_controller.dart';
import 'onboarding_metrics.dart';
import 'widgets/gf44_data_hub_page.dart';
import 'widgets/glass_page_indicator.dart';
import 'widgets/glass_swipe_arrow.dart';
import 'widgets/start_cta_page.dart';
import 'widgets/swipe_responsive_brand_lockup.dart';
import 'widgets/swipe_responsive_gf44_headline.dart';
import 'widgets/welcome_brand_intro.dart';

/// The four-page intro.
///
/// The brand lockup and the "GF44" headline are siblings of the `PageView`
/// rather than children of it, because they travel between pages while the
/// pages slide past underneath. Everything on this screen — floating layer and
/// page bodies alike — takes its position from [OnboardingMetrics], so the two
/// can no longer drift into each other on a device unlike the design canvas.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const int pageCount = 4;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final SettledPageController _pageController = SettledPageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _page => _pageController.settledPage;

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
                _StartPage(controller: _pageController, index: 3),
              ],
            ),
          ),
          SwipeResponsiveBrandLockup(controller: _pageController),
          SwipeResponsiveGf44Headline(controller: _pageController),
          Positioned(
            left: 0,
            right: 0,
            bottom: scaled(context, 36) + bottomInset,
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
                    SizedBox(height: scaled(context, 26)),
                    SizedBox(
                      height: scaled(context, 42),
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

  final SettledPageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    // No `SafeArea` here, and no bottom reserve: the body positions itself in
    // screen coordinates off the lockup's measured edge, and `OnboardingMetrics`
    // already folds both insets into that band. Wrapping it would shift the
    // origin out from under the very anchors it shares with the floating layer.
    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: const WelcomeBrandIntro(),
    );
  }
}

class _Gf44Page extends StatelessWidget {
  const _Gf44Page({required this.controller, required this.index});

  final SettledPageController controller;
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

  final SettledPageController controller;

  static const String _description =
      'GF44 innovativ həlli ilə şirkətinizin bütün idarəetmə prosesi bir '
      'ekranda toplanır: tapşırıqlar, komanda, sənədlər, partnyorlar və '
      'hesabatlar — daha sürətli, daha şəffaf, daha peşəkar.';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final OnboardingMetrics metrics = OnboardingMetrics.of(context);
        final double progress =
            ((_page - 0.74) / 0.26).clamp(0.0, 1.0).toDouble();
        final double t = Curves.easeOutCubic.transform(progress);

        // Directly under the headline's real bottom edge. This used to be an
        // `Align` inside the leftover space with a `SizedBox` standing in for
        // the headline's height, which is what let "GF44" land on the text.
        final double top = metrics.overviewBodyTop;
        final double descriptionSize =
            responsive(context, factor: 0.052, min: 17, max: 22);
        final double lineHeight = metrics.lineHeight(descriptionSize, 1.24);
        // As many lines as actually fit above the page indicator, so a large
        // system font scale costs a line rather than overrunning the dots.
        final int maxLines =
            math.max(3, ((metrics.floor - top) / lineHeight).floor());
        final double horizontal = metrics.px(22);

        return Stack(
          children: <Widget>[
            Positioned(
              top: top,
              left: horizontal,
              right: horizontal,
              child: Opacity(
                opacity: Curves.easeOut.transform(t),
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: blurred(
                    14 * (1 - t),
                    Text(
                      _description,
                      textAlign: TextAlign.center,
                      maxLines: maxLines,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: descriptionSize,
                        fontWeight: FontWeight.w400,
                        height: 1.24,
                        letterSpacing: -0.15,
                        shadows: kOnboardingTextShadows,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _page => controller.settledPage;
}

class _Gf44DataPage extends StatelessWidget {
  const _Gf44DataPage({required this.controller, required this.index});

  final SettledPageController controller;
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

class _StartPage extends StatelessWidget {
  const _StartPage({required this.controller, required this.index});

  final SettledPageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return StartCtaPage(
      pageController: controller,
      pageIndex: index,
    );
  }
}

class _ExitOnSwipe extends StatelessWidget {
  const _ExitOnSwipe({
    required this.controller,
    required this.index,
    required this.child,
  });

  final SettledPageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final double page = controller.settledPage;
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
