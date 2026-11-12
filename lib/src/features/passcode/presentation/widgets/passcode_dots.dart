import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../../../shared/glass/app_glass.dart';

import '../../domain/passcode_hash.dart';
import '../passcode_metrics.dart';
import '../passcode_style.dart';

/// The four dots over the keypad: clear glass while empty, white glass once a
/// digit is in.
///
/// Filling is the user's brief (2026-11-12): fast, and the dot swells a
/// little as the white comes in and settles back.
class PasscodeDots extends StatefulWidget {
  const PasscodeDots({
    super.key,
    required this.metrics,
    required this.filled,
    required this.shakeTick,
    required this.pulseTick,
    this.appear = 1,
  });

  final PasscodeMetrics metrics;

  /// How many dots are full, 0–[kPasscodeLength].
  final int filled;

  /// Bumped on a wrong code: the row shakes.
  final int shakeTick;

  /// Bumped on a right code: every dot swells at once.
  final int pulseTick;

  /// 0 hidden, 1 in place — the dots bloom in by size on entry.
  final double appear;

  @override
  State<PasscodeDots> createState() => _PasscodeDotsState();
}

class _PasscodeDotsState extends State<PasscodeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Per-dot delay for the current change — a reset drains right to left.
  final List<Duration> _delays = List<Duration>.filled(
    kPasscodeLength,
    Duration.zero,
  );

  @override
  void didUpdateWidget(PasscodeDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTick != oldWidget.shakeTick) {
      _shake.forward(from: 0);
    }
    final int dropped = oldWidget.filled - widget.filled;
    for (int i = 0; i < kPasscodeLength; i++) {
      _delays[i] = dropped > 1
          ? Duration(milliseconds: 45 * (oldWidget.filled - 1 - i))
          : Duration.zero;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PasscodeMetrics m = widget.metrics;
    // Room around the row for the swell and the shake.
    final double pad = m.dotDiameter * 1.5;
    final Rect box = m.dotsRect.inflate(pad);
    return Positioned.fromRect(
      rect: box,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _shake,
          builder: (BuildContext context, Widget? child) {
            final double t = _shake.value;
            // A damped sine — four swings, dying out, the iOS refusal shake.
            final double dx = _shake.isAnimating
                ? 13 *
                      m.scale *
                      math.sin(t * math.pi * 8) *
                      math.pow(1 - t, 1.6).toDouble()
                : 0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int i = 0; i < kPasscodeLength; i++)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: m.dotCenter(i) - box.topLeft,
                    width: m.dotDiameter,
                    height: m.dotDiameter,
                  ),
                  child: _PasscodeDot(
                    filled: i < widget.filled,
                    delay: _delays[i],
                    pulseTick: widget.pulseTick,
                    appear: _stagger(widget.appear, i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot blooms a beat after the one to its left.
  static double _stagger(double appear, int index) {
    const double step = 0.12;
    final double start = index * step;
    final double span = 1 - (kPasscodeLength - 1) * step;
    return ((appear - start) / span).clamp(0.0, 1.0);
  }
}

class _PasscodeDot extends StatefulWidget {
  const _PasscodeDot({
    required this.filled,
    required this.delay,
    required this.pulseTick,
    required this.appear,
  });

  final bool filled;
  final Duration delay;
  final int pulseTick;
  final double appear;

  @override
  State<_PasscodeDot> createState() => _PasscodeDotState();
}

class _PasscodeDotState extends State<_PasscodeDot>
    with TickerProviderStateMixin {
  /// 0 empty → 1 white. Quick in, a little quicker out.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
    reverseDuration: const Duration(milliseconds: 140),
    value: widget.filled ? 1 : 0,
  );

  /// How far past its size the dot is right now; a spring kicked from rest.
  late final AnimationController _swell = AnimationController.unbounded(
    vsync: this,
  );

  /// Underdamped: up to about a fifth bigger, a small dip under, settled in
  /// roughly a third of a second.
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 620,
    damping: 21,
  );

  @override
  void didUpdateWidget(_PasscodeDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filled != oldWidget.filled) {
      if (widget.delay == Duration.zero) {
        _apply();
      } else {
        Future<void>.delayed(widget.delay, () {
          if (mounted) _apply();
        });
      }
    }
    if (widget.pulseTick != oldWidget.pulseTick) _kick(10);
  }

  void _apply() {
    if (widget.filled) {
      _fill.forward();
      _kick(9);
    } else {
      _fill.reverse();
      _kick(-4);
    }
  }

  void _kick(double velocity) {
    _swell.animateWith(SpringSimulation(_spring, _swell.value, 0, velocity));
  }

  @override
  void dispose() {
    _fill.dispose();
    _swell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_fill, _swell]),
      builder: (BuildContext context, _) {
        final double fill = Curves.easeOutCubic.transform(_fill.value);
        final double swell = _swell.value;
        final double appear = Curves.easeOutBack.transform(widget.appear);
        final double scale = (1 + swell) * appear;
        if (scale <= 0.01) return const SizedBox.shrink();
        return Transform.scale(
          scale: scale,
          child: AppGlassSurface(
            style: passcodeDotGlass(fill),
            cornerRadius: 999,
            child: Center(
              // The white comes in from the middle of the dot outwards.
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: fill,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFFFFFFF,
                    ).withValues(alpha: 0.55 * fill),
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
