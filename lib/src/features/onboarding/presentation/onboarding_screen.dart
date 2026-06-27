import 'package:flutter/material.dart';

import '../../../shared/effects.dart';
import 'widgets/animated_logo.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass_page_indicator.dart';
import 'widgets/glass_swipe_arrow.dart';
import 'widgets/welcome_text.dart';

/// Pre-login welcome / intro flow.
///
/// Shown only when the user is not authenticated; once login lands this is
/// skipped in favour of the dashboards. It is a multi-page swipe experience —
/// page one is the branded "Xoş gəlmişsiniz!" welcome, the remaining pages are
/// placeholders whose content will be filled in later. A single continuous
/// aurora backdrop sits behind every page.
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

  /// Current fractional page, safe before the controller is laid out.
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
      backgroundColor: const Color(0xFF05030E),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AuroraBackground()),
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                _WelcomePage(controller: _pageController, index: 0),
                for (int i = 1; i < OnboardingScreen.pageCount; i++)
                  _PlaceholderPage(
                    controller: _pageController,
                    index: i,
                  ),
              ],
            ),
          ),
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

/// First page: the animated logo + blur-in welcome headline, wrapped in a
/// blur-out "exit" tied to the swipe so the hero dissolves as you leave.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.controller, required this.index});

  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final double logoWidth =
        (MediaQuery.of(context).size.width * 0.44).clamp(140.0, 190.0);

    return _ExitOnSwipe(
      controller: controller,
      index: index,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedGuvenLogo(
                width: logoWidth,
                delay: const Duration(milliseconds: 250),
              ),
              const SizedBox(height: 22),
              const WelcomeText(text: 'Xoş gəlmişsiniz!'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for pages 2-4; content arrives later. Keeps the shared backdrop
/// and the same swipe-exit treatment for continuity.
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

/// Fades and blurs its [child] out as the page scrolls away from centre.
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
            (1 - (page - index).abs()).clamp(0.0, 1.0);
        return Opacity(
          opacity: visibility,
          child: blurred((1 - visibility) * 10, child!),
        );
      },
    );
  }
}
