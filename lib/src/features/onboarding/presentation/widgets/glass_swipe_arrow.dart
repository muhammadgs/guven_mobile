import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';

/// Liquid-glass "swipe right" hint shown only beneath the first page.
///
/// [visibility] (1 on page one → 0 by page two) ties the control to the page
/// scroll so it animates away as the user swipes. On top of that it plays a
/// one-shot entrance (fade + scale) and a gentle, looping nudge so the arrow
/// keeps inviting the swipe. Tapping it advances to the next page.
class GlassSwipeArrow extends StatefulWidget {
  const GlassSwipeArrow({
    super.key,
    required this.visibility,
    required this.onTap,
  });

  final double visibility;
  final VoidCallback onTap;

  @override
  State<GlassSwipeArrow> createState() => _GlassSwipeArrowState();
}

class _GlassSwipeArrowState extends State<GlassSwipeArrow>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _nudge;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_entrance, _nudge]),
      builder: (context, _) {
        final double enter = Curves.easeOutBack.transform(_entrance.value)
            .clamp(0.0, 1.0);
        final double opacity = (widget.visibility * _entrance.value)
            .clamp(0.0, 1.0);
        final double nudge =
            Curves.easeInOut.transform(_nudge.value) * 5; // 0..5 px

        if (opacity <= 0.01) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.85 + 0.15 * enter,
            child: IgnorePointer(
              ignoring: widget.visibility < 0.6,
              child: _GlassButton(
                onTap: widget.onTap,
                child: Transform.translate(
                  offset: Offset(nudge, 0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: scaled(context, 24),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double radius = scaled(context, 20);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: scaled(context, 64),
            height: scaled(context, 42),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
