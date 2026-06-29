import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';

/// Resolves a headline out of blur into crisp text on first appearance.
///
/// The text starts heavily blurred, transparent and slightly lowered with a
/// loose letter-spacing, then settles into place. (The matching "exit" — a
/// blur-out as the page is swiped away — is applied by the page wrapper that
/// hosts this widget, so the effect reads as blur-in *and* blur-out.)
class WelcomeText extends StatefulWidget {
  const WelcomeText({
    super.key,
    required this.text,
    this.delay = const Duration(milliseconds: 650),
  });

  final String text;
  final Duration delay;

  @override
  State<WelcomeText> createState() => _WelcomeTextState();
}

class _WelcomeTextState extends State<WelcomeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double t = Curves.easeOutCubic.transform(_controller.value);
        final double sigma = (1 - t) * 14;
        final double opacity = Curves.easeOut.transform(_controller.value);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: blurred(
              sigma,
              Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'CalSans',
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -1.1 + 0.7 * t,
                  height: 1.1,
                  shadows: const <Shadow>[
                    Shadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
