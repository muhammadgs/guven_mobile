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
              color: Color(0x5A000000),
              blurRadius: 46,
              spreadRadius: -6,
              offset: Offset(0, 24),
            ),
            BoxShadow(
              color: Color(0x2AFFFFFF),
              blurRadius: 24,
              spreadRadius: -9,
              offset: Offset(-11, -11),
            ),
          ],
        ),
        child: LiquidGlassLayer(
          settings: const LiquidGlassSettings(
            // Figma Refraction 100 / Depth 25 approximation.
            thickness: 28,
            refractiveIndex: 1.52,
            // Figma Frost 5 approximation.
            blur: 5,
            glassColor: Color(0x22FFFFFF),
            // Figma light angle 0° with controlled 25%-style intensity.
            lightAngle: 0,
            lightIntensity: 1.22,
            ambientStrength: 0.42,
            outlineIntensity: 0.86,
            saturation: 1.38,
          ),
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: radius),
            child: GlassGlow(
              glowColor: const Color(0x70FFFFFF),
              glowRadius: 1.08,
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
                  Color(0x4AFFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x08000000),
                  Color(0x38000000),
                ],
                stops: <double>[0, 0.33, 0.61, 1],
              ),
            ),
          ),
          Positioned(
            left: -8,
            top: 5,
            bottom: 5,
            width: 128,
            child: Opacity(
              opacity: 0.47,
              child: blurred(
                14,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color(0xF5FFFFFF),
                        Color(0x78FFFFFF),
                        Color(0x16FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: <double>[0, 0.28, 0.66, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 34,
            top: 5,
            height: 22,
            child: Opacity(
              opacity: 0.54,
              child: blurred(
                9,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Color(0x00FFFFFF),
                        Color(0xCCFFFFFF),
                        Color(0x38FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: <double>[0, 0.38, 0.68, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -10,
            top: 0,
            bottom: 0,
            width: 28,
            child: Opacity(
              opacity: 0.24,
              child: blurred(
                7,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00B9FFFF),
                        Color(0x8AB9FFFF),
                        Color(0x00B9FFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -12,
            top: 0,
            bottom: 0,
            width: 30,
            child: Opacity(
              opacity: 0.20,
              child: blurred(
                7,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x00D6B7FF),
                        Color(0x7AD6B7FF),
                        Color(0x00D6B7FF),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -24,
            width: 128,
            height: 70,
            child: Opacity(
              opacity: 0.32,
              child: blurred(
                20,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        Color(0x94000000),
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
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x96FFFFFF)),
            ),
          ),
          const Positioned(
            left: 1,
            right: 1,
            bottom: 0,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x30000000)),
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
                    color: Color(0x70000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                  Shadow(
                    color: Color(0x38FFFFFF),
                    blurRadius: 9,
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
