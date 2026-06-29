import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen looping video backdrop shared by every pre-login screen.
///
/// Blurs the video directly with [ImageFiltered] (avoids the known Flutter
/// limitation where [BackdropFilter] cannot sample [Texture]-based widgets
/// such as video_player). A dark scrim is layered on top for legibility.
/// The [child] is stacked above everything.
///
/// The controller lives here for the lifetime of this widget so the video
/// continues looping seamlessly as pre-login screens are pushed or popped.
class AuthBackground extends StatefulWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.blurSigma = 18.0,
    this.scrimOpacity = 0.25,
  });

  final Widget child;
  final double blurSigma;
  final double scrimOpacity;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> {
  static const String _assetPath = 'assets/videos/onboarding_background.mp4';

  late final VideoPlayerController _controller;
  bool _isReady = false;

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
    await _controller.initialize();
    await _controller.setLooping(true);
    await _controller.setVolume(0);
    await _controller.seekTo(Duration.zero);

    if (!mounted) return;
    setState(() => _isReady = true);

    await _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // ── 1. Blurred video ─────────────────────────────────────────────────
        //   ImageFiltered applies blur directly to the VideoPlayer widget,
        //   which avoids BackdropFilter's inability to sample Texture layers.
        Positioned.fill(
          child: IgnorePointer(
            child: _isReady
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: widget.blurSigma,
                      sigmaY: widget.blurSigma,
                      tileMode: TileMode.mirror,
                    ),
                    child: _CoverVideo(controller: _controller),
                  )
                : const ColoredBox(color: Colors.black),
          ),
        ),

        // ── 2. Dark scrim ────────────────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: widget.scrimOpacity),
            ),
          ),
        ),

        // ── 3. Screen content ────────────────────────────────────────────────
        widget.child,
      ],
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
      return const ColoredBox(color: Colors.black);
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
