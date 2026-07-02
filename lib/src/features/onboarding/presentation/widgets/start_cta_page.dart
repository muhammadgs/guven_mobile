import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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
        (screen.width * 0.52).clamp(210.0, 280.0).toDouble();

    final double buttonHeight =
        (screen.height * 0.075).clamp(64.0, 82.0).toDouble();

    final double fontSize =
        (screen.width * 0.075).clamp(28.0, 40.0).toDouble();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: screen.height * 0.13),
          child: Builder(
            builder: (buttonContext) {
              return _LiquidGlassStartButton(
                width: buttonWidth,
                height: buttonHeight,
                fontSize: fontSize,
                onTap: () => _openLogin(context, buttonContext),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openLogin(BuildContext context, BuildContext buttonContext) {
    final Rect startRect = _buttonRectFrom(buttonContext, context);

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 760),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _LoginBurstTransition(
            animation: animation,
            startRect: startRect,
            child: child,
          );
        },
      ),
    );
  }

  Rect _buttonRectFrom(BuildContext buttonContext, BuildContext pageContext) {
    final RenderObject? buttonObject = buttonContext.findRenderObject();
    final RenderObject? overlayObject =
        Navigator.of(pageContext).overlay?.context.findRenderObject();

    if (buttonObject is RenderBox &&
        overlayObject is RenderBox &&
        buttonObject.hasSize) {
      final Offset topLeft = buttonObject.localToGlobal(
        Offset.zero,
        ancestor: overlayObject,
      );
      return topLeft & buttonObject.size;
    }

    final Size screen = MediaQuery.sizeOf(pageContext);
    return Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height * 0.58),
      width: 240,
      height: 72,
    );
  }
}

class _LoginBurstTransition extends StatelessWidget {
  const _LoginBurstTransition({
    required this.animation,
    required this.startRect,
    required this.child,
  });

  final Animation<double> animation;
  final Rect startRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = Curves.easeOutCubic.transform(animation.value);
        final double childOpacity = Curves.easeOut.transform(
          ((t - 0.34) / 0.66).clamp(0.0, 1.0).toDouble(),
        );
        final double burstOpacity =
            (1 - ((t - 0.76) / 0.24).clamp(0.0, 1.0)).toDouble();
        final Size screen = MediaQuery.sizeOf(context);
        final Rect endRect = Rect.fromLTWH(
          -screen.width * 0.12,
          -screen.height * 0.12,
          screen.width * 1.24,
          screen.height * 1.24,
        );
        final Rect burstRect = Rect.lerp(startRect, endRect, t)!;
        final double radius = (startRect.height / 2) * (1 - t);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Opacity(
              opacity: childOpacity,
              child: child,
            ),
            IgnorePointer(
              child: Opacity(
                opacity: burstOpacity,
                child: Stack(
                  children: <Widget>[
                    Positioned.fromRect(
                      rect: burstRect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: const Color(0x9AFFFFFF),
                            width: 1.15,
                          ),
                          gradient: const RadialGradient(
                            center: Alignment(-0.35, -0.45),
                            radius: 1.25,
                            colors: <Color>[
                              Color(0x72FFFFFF),
                              Color(0x507E6BFF),
                              Color(0x2D15005C),
                              Color(0x161B60FF),
                            ],
                            stops: <double>[0, 0.28, 0.62, 1],
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x5A9B78FF),
                              blurRadius: 42,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 34,
                              spreadRadius: -8,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
              thickness: 55,
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
