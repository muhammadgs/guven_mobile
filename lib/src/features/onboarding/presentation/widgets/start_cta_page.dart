import 'dart:ui';

import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0x52FFFFFF),
                  Color(0x1FFFFFFF),
                  Color(0x26000000),
                ],
                stops: <double>[0, 0.44, 1],
              ),
              border: Border.all(
                color: const Color(0x55FFFFFF),
                width: 1.1,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x42000000),
                  blurRadius: 34,
                  offset: Offset(0, 18),
                ),
                BoxShadow(
                  color: Color(0x22FFFFFF),
                  blurRadius: 18,
                  offset: Offset(-10, -9),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  left: 10,
                  top: 8,
                  bottom: 8,
                  child: Opacity(
                    opacity: 0.42,
                    child: blurred(
                      10,
                      Container(
                        width: width * 0.34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x66FFFFFF)),
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
          ),
        ),
      ),
    );
  }
}
