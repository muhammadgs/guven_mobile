import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../../../shared/motion/glass_shimmer.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../auth/presentation/widgets/auth_glass.dart';
import '../onboarding_metrics.dart';

/// The final page: one glass pill that morphs into the login card.
///
/// The pill hangs off [BrandLockupGeometry.bottom] so it clears the wordmark
/// on every screen. It used to be centred with a fixed top pad, which on a
/// short phone centred it straight onto the logo.
class StartCtaPage extends StatefulWidget {
  const StartCtaPage({
    super.key,
    required this.pageController,
    required this.pageIndex,
  });

  final PageController pageController;
  final int pageIndex;

  @override
  State<StartCtaPage> createState() => _StartCtaPageState();
}

class _StartCtaPageState extends State<StartCtaPage> {
  final GlobalKey _buttonKey = GlobalKey();

  /// True from the moment the morph takes over the button's rect until the
  /// card has shrunk all the way back into it.
  bool _handedOver = false;

  @override
  Widget build(BuildContext context) {
    final OnboardingMetrics metrics = OnboardingMetrics.of(context);

    final double buttonWidth =
        responsive(context, factor: 0.52, min: 210, max: 280);
    final double buttonHeight = (metrics.band * 0.10)
        .clamp(metrics.px(64), metrics.px(82))
        .toDouble();
    final double top = metrics.startCtaTop;

    return Stack(
      children: <Widget>[
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Center(
            // While the morph holds the surface, the button stops painting —
            // otherwise two lenses sit on the same rect and refract each other.
            // `Visibility` and not `Opacity`: an opacity layer over a lens is a
            // `saveLayer`, and a lens inside one renders black.
            child: Visibility(
              visible: !_handedOver,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: GlassPressButton(
                key: _buttonKey,
                width: buttonWidth,
                height: buttonHeight,
                cornerRadius: buttonHeight / 2,
                style: kStartCtaGlass,
                shadow: kStartCtaShadow,
                onTap: _openLogin,
                child: const StartCtaLabel(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openLogin() async {
    if (_handedOver) return;

    final RenderBox? box =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final GlassMorphRoute<void> route = GlassMorphRoute<void>(
      // Global coordinates: the login route fills the screen from (0, 0), so
      // its own Stack reads these unchanged.
      sourceRect: box.localToGlobal(Offset.zero) & box.size,
      sourceRadius: box.size.height / 2,
      builder: (_) => const LoginScreen(),
    );

    setState(() => _handedOver = true);
    await Navigator.of(context).push<void>(route);
    // `push` completes the moment the pop starts; `completed` waits for the
    // route to actually leave, which is when the card is a pill again.
    await route.completed;
    if (mounted) setState(() => _handedOver = false);
  }
}
