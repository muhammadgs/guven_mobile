import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../../shared/effects.dart';

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
    return SafeArea(
      child: AnimatedBuilder(
        animation: pageController,
        builder: (context, _) {
          final double page = _currentPage;
          final double raw = (page - (pageIndex - 1)).clamp(0.0, 1.0).toDouble();
          final double t = Curves.easeOutCubic.transform(raw);
          final Size screen = MediaQuery.sizeOf(context);
          final double buttonWidth = (screen.width * 0.52).clamp(210.0, 280.0).toDouble();
          final double buttonHeight = (screen.height * 0.075).clamp(64.0, 82.0).toDouble();
          final double fontSize = (screen.width * 0.075).clamp(28.0, 40.0).toDouble();

          return Center(
            child: Transform.translate(
              offset: Offset(0, 38 * (1 - t)),
              child: Opacity(
                opacity: t,
                child: Padding(
                  padding: EdgeInsets.only(top: screen.height * 0.13),
                  child: _LiquidGlassStartButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    fontSize: fontSize,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double get _currentPage {
    if (pageController.hasClients && pageController.position.haveDimensions) {
      return pageController.page ?? pageController.initialPage.toDouble();
    }
    return pageController.initialPage.toDouble();
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
              color: Color(0x52000000),
              blurRadius: 42,
              spreadRadius: -5,
              offset: Offset(0, 22),
            ),
            BoxShadow(
              color: Color(0x28FFFFFF),
              blurRadius: 22,
              spreadRadius: -8,
              offset: Offset(-10, -10),
            ),
          ],
        ),
        child: LiquidGlassLayer(
          settings: const LiquidGlassSettings(
            thickness: 24,
            blur: 7,
            glassColor: Color(0x24FFFFFF),
            lightIntensity: 1.35,
            outlineIntensity: 0.70,
            saturation: 1.22,
          ),
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: radius),
            child: GlassGlow(
              glowColor: const Color(0x66FFFFFF),
              glowRadius: 1.05,
              child: SizedBox(
                width: width,
                height: height,
                child: _StartButtonContent(
                  radius: radius,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButtonContent extends StatelessWidget {
  const _StartButtonContent({
    required this.radius,
    required this.fontSize,
  });

  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0x40FFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x10000000),
                  Color(0x30000000),
                ],
                stops: <double>[0, 0.34, 0.62, 1],
              ),
            ),
          ),
          Positioned(
            left: 9,
            top: 7,
            bottom: 7,
            child: Opacity(
              opacity: 0.44,
              child: blurred(
                12,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color(0xF0FFFFFF),
                        Color(0x66FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                  child: const SizedBox(width: 94),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            right: 42,
            top: 7,
            height: 18,
            child: Opacity(
              opacity: 0.50,
              child: blurred(
                8,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color(0x00FFFFFF),
                        Color(0xB8FFFFFF),
                        Color(0x24FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -22,
            width: 118,
            height: 64,
            child: Opacity(
              opacity: 0.28,
              child: blurred(
                18,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        Color(0x88000000),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x88FFFFFF)),
            ),
          ),
          const Positioned(
            left: 1,
            right: 1,
            bottom: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x26000000)),
            ),
          ),
          Center(
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
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                  Shadow(
                    color: Color(0x33FFFFFF),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
