import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/layout.dart';
import '../../../auth/presentation/login_screen.dart';

class StartCtaPage extends StatelessWidget {
  const StartCtaPage({
    super.key,
    required this.pageController,
    required this.pageIndex,
  });

  final PageController pageController;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);

    final double buttonWidth =
        responsive(context, factor: 0.52, min: 210, max: 280);

    final double buttonHeight = (screen.height * 0.075)
        .clamp(scaled(context, 64), scaled(context, 82))
        .toDouble();

    final double fontSize =
        responsive(context, factor: 0.075, min: 28, max: 40);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: screen.height * 0.13),
          child: _LiquidGlassStartButton(
            width: buttonWidth,
            height: buttonHeight,
            fontSize: fontSize,
            onTap: () => _openLogin(context),
          ),
        ),
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 720),
        reverseTransitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Starts after the onboarding has mostly dissolved (see
          // AuthFlowShell), so the two never crossfade at full sharpness:
          // login condenses out of blur and settles with a gentle scale.
          final CurvedAnimation reveal = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
            reverseCurve: const Interval(0.45, 1.0, curve: Curves.easeInCubic),
          );

          return AnimatedBuilder(
            animation: reveal,
            child: child,
            builder: (context, child) {
              final double t = reveal.value;
              return Opacity(
                opacity: t,
                child: blurred(
                  14 * (1 - t),
                  Transform.scale(
                    scale: 0.96 + 0.04 * t,
                    child: child,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LiquidGlassStartButton extends StatelessWidget {
  const _LiquidGlassStartButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double radius = height / 2;

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x36000000),
              blurRadius: 28,
              spreadRadius: -8,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: LiquidStretch(
          stretch: 0.35,
          interactionScale: 1.03,
          child: LiquidGlass.withOwnLayer(
            settings: const LiquidGlassSettings(
              thickness: 30,
              blur: 0,
              glassColor: Color.fromARGB(0, 255, 255, 255),
              refractiveIndex: 1.45,
              lightIntensity: 1.45,
              ambientStrength: 0.60,
              saturation: 1.25,
            ),
            shape: LiquidRoundedSuperellipse(
              borderRadius: radius,
            ),
            glassContainsChild: false,
            child: GlassGlow(
              glowColor: Colors.white38,
              glowRadius: 1.30,
              child: SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: Text(
                    'Başlayın',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'CalSans',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
