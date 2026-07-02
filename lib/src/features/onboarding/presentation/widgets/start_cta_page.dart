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
              color: Color(0x4A000000),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
            BoxShadow(
              color: Color(0x22FFFFFF),
              blurRadius: 18,
              offset: Offset(-8, -8),
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
                  Color(0x36FFFFFF),
                  Color(0x10FFFFFF),
                  Color(0x26000000),
                ],
                stops: <double>[0, 0.46, 1],
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 8,
            bottom: 8,
            child: Opacity(
              opacity: 0.38,
              child: blurred(
                10,
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: Colors.white,
                  ),
                  child: const SizedBox(width: 78),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.2,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x70FFFFFF)),
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
                    color: Color(0x55000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
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
