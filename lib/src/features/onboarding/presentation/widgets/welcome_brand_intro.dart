import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/layout.dart';
import '../onboarding_metrics.dart';
import 'swipe_responsive_brand_lockup.dart' show kOnboardingTextShadows;

/// First onboarding hero text, revealed after the shared brand lockup.
///
/// The lockup itself belongs to the onboarding screen, which floats it above
/// the `PageView` so it can travel between pages. This body used to reserve a
/// hand-computed stand-in for the lockup's height and then centre the result,
/// which meant its idea of where the logo ended and the logo's actual position
/// drifted apart on any screen unlike the design canvas. It now anchors to
/// [BrandLockupGeometry.bottom] — the real edge — so the two cannot collide.
class WelcomeBrandIntro extends StatefulWidget {
  const WelcomeBrandIntro({super.key});

  @override
  State<WelcomeBrandIntro> createState() => _WelcomeBrandIntroState();
}

class _WelcomeBrandIntroState extends State<WelcomeBrandIntro>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const Duration _introDelay = Duration(seconds: 2);

  /// PageView may dispose and recreate this widget when the user swipes away.
  /// Keep the intro timeline in memory for the current app session so returning
  /// to page one does not replay the text sequence from zero.
  static double _savedProgress = 0;
  static bool _hasStartedOnce = false;

  late final AnimationController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )
      ..value = _savedProgress.clamp(0.0, 1.0)
      ..addListener(_rememberProgress)
      ..addStatusListener(_rememberCompletion);

    if (_savedProgress >= 1) return;

    if (_hasStartedOnce) {
      _controller.forward();
    } else {
      _hasStartedOnce = true;
      _startAfterBackgroundBreathes();
    }
  }

  Future<void> _startAfterBackgroundBreathes() async {
    await Future<void>.delayed(_introDelay);
    if (mounted && _controller.value < 1) _controller.forward();
  }

  void _rememberProgress() {
    _savedProgress = _controller.value;
  }

  void _rememberCompletion(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _savedProgress = 1;
    }
  }

  @override
  void dispose() {
    _savedProgress = _controller.value;
    _controller
      ..removeListener(_rememberProgress)
      ..removeStatusListener(_rememberCompletion)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final OnboardingMetrics metrics = OnboardingMetrics.of(context);
    final double top = metrics.welcomeBodyTop;
    final double subtitleSize =
        responsive(context, factor: 0.04, min: 14, max: 18);
    final double welcomeSize =
        responsive(context, factor: 0.105, min: 34, max: 48);

    // Whatever room is left between the wordmark and the page indicator, up to
    // the gap the design asks for. On a short screen it closes rather than
    // pushing the hero line down into the dots.
    final double slack = metrics.floor -
        top -
        metrics.lineHeight(subtitleSize, 1.25) -
        metrics.lineHeight(welcomeSize, 1);
    final double signatureGap = math.min(metrics.px(50), math.max(slack, 0));

    return Stack(
      children: <Widget>[
        Positioned(
          top: top,
          left: metrics.px(28),
          right: metrics.px(28),
          child: ConstrainedBox(
            // The last line of defence: a viewport too short even for the
            // closed-up gap shrinks the pair as one piece instead of
            // overflowing. A no-op on every phone.
            constraints: BoxConstraints(
              maxHeight: math.max(0, metrics.floor - top),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _BlurRevealText(
                        progress: _interval(0.4, 0.6),
                        text: 'İnnovativ maliyyə həlləri',
                        style: TextStyle(
                          color: const Color(0xEFFFFFFF),
                          fontFamily: 'Poppins',
                          fontSize: subtitleSize,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                          letterSpacing: 0.15,
                          shadows: kOnboardingTextShadows,
                        ),
                        beginOffset: 11,
                        beginBlur: 11,
                        beginLetterSpacing: 1.0,
                        endLetterSpacing: 0.15,
                      ),
                      SizedBox(height: signatureGap),
                      _BlurRevealText(
                        progress: _interval(0.6, 0.8),
                        text: 'Xoş Gəlmişsiniz!',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'CalSans',
                          fontSize: welcomeSize,
                          fontWeight: FontWeight.w400,
                          height: 1,
                          letterSpacing: 1.0,
                          shadows: kOnboardingTextShadows,
                        ),
                        beginOffset: 16,
                        beginBlur: 14,
                        beginScale: 0.94,
                        endScale: 1,
                        beginLetterSpacing: 3.2,
                        endLetterSpacing: 1.0,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _interval(double start, double end) {
    final double value = ((_controller.value - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return Curves.easeOutCubic.transform(value);
  }
}

class _BlurRevealText extends StatelessWidget {
  const _BlurRevealText({
    required this.progress,
    required this.text,
    required this.style,
    required this.beginOffset,
    required this.beginBlur,
    required this.beginLetterSpacing,
    required this.endLetterSpacing,
    this.beginScale = 1,
    this.endScale = 1,
  });

  final double progress;
  final String text;
  final TextStyle style;
  final double beginOffset;
  final double beginBlur;
  final double beginLetterSpacing;
  final double endLetterSpacing;
  final double beginScale;
  final double endScale;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0).toDouble();
    final double opacity = Curves.easeOut.transform(t);
    final double scale = beginScale + (endScale - beginScale) * t;
    final double letterSpacing =
        beginLetterSpacing + (endLetterSpacing - beginLetterSpacing) * t;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, beginOffset * (1 - t)),
        child: Transform.scale(
          scale: scale,
          child: blurred(
            beginBlur * (1 - t),
            Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: style.copyWith(letterSpacing: letterSpacing),
            ),
          ),
        ),
      ),
    );
  }
}
