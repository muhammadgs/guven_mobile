import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import 'animated_logo.dart';

/// First onboarding hero that reveals the brand on one deterministic timeline.
///
/// The sequence is intentionally strict: mark first, then brand, then subtitle,
/// then the GF44 signature. Keeping a single controller prevents the elements
/// from drifting into simultaneous starts when the page rebuilds.
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
  /// to page one does not replay the logo/text sequence from zero.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size screen = MediaQuery.sizeOf(context);
        final double availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screen.height;
        final double logoWidth = (screen.width * 0.58).clamp(190.0, 270.0);
        final double brandSize = (screen.width * 0.092).clamp(30.0, 42.0);
        final double subtitleSize = (screen.width * 0.04).clamp(14.0, 18.0);
        final double gfSize = (screen.width * 0.105).clamp(34.0, 48.0);
        final double signatureGap = (availableHeight * 0.085).clamp(42.0, 70.0);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double logoProgress = _interval(0.00, 0.56);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedGuvenLogo(
                    width: logoWidth,
                    progress: logoProgress,
                  ),
                  const SizedBox(height: 14),
                  _BlurRevealText(
                    progress: _interval(0.2, 0.4),
                    text: 'Güvən Finans',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'CalSans',
                      fontSize: brandSize,
                      fontWeight: FontWeight.w400,
                      height: 1.05,
                      letterSpacing: -0.7,
                      shadows: _softShadows,
                    ),
                    beginOffset: 13,
                    beginBlur: 13,
                    beginLetterSpacing: 0.5,
                    endLetterSpacing: -0.7,
                  ),
                  const SizedBox(height: 8),
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
                      shadows: _softShadows,
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
                      fontSize: gfSize,
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: 1.0,
                      shadows: _softShadows,
                    ),
                    beginOffset: 16,
                    beginBlur: 14,
                    beginScale: 0.94,
                    endScale: 1,
                    beginLetterSpacing: 3.2,
                    endLetterSpacing: 1.0,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _interval(double start, double end) {
    final double value = ((_controller.value - start) / (end - start))
        .clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(value);
  }
}

const List<Shadow> _softShadows = <Shadow>[
  Shadow(
    color: Color(0x33000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];

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
    final double t = progress.clamp(0.0, 1.0);
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
