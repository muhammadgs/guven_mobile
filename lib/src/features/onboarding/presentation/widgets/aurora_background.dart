import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen looping video backdrop used by the onboarding flow.
///
/// Keeps the public widget name so the onboarding screen can continue using
/// `AuroraBackground()` as the bottom layer of its Stack.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> {
  static const String _assetPath = 'assets/videos/onboarding_background.mp4';

  late final VideoPlayerController _controller;
  bool _isReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      _assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.seekTo(Duration.zero);

      if (!mounted) return;
      setState(() {
        _isReady = true;
      });

      await _controller.play();
    } on Object {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _FallbackBackground(),
          if (_isReady && !_hasError)
            Positioned.fill(
              child: _CoverVideo(controller: _controller),
            ),
          const _ReadabilityOverlay(),
        ],
      ),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final VideoPlayerValue value = controller.value;
    final Size videoSize = value.size;

    if (!value.isInitialized || videoSize.width <= 0 || videoSize.height <= 0) {
      return const SizedBox.expand();
    }

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: videoSize.width,
            height: videoSize.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF030416),
            Color(0xFF050736),
            Color(0xFF01021F),
          ],
          stops: <double>[0, 0.58, 1],
        ),
      ),
    );
  }
}

class _ReadabilityOverlay extends StatelessWidget {
  const _ReadabilityOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x26000000),
            Color(0x08000000),
            Color(0x33000000),
          ],
          stops: <double>[0, 0.48, 1],
        ),
      ),
    );
  }
}
