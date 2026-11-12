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
/// The video itself is shared: every [AuthBackground] on screen shows the same
/// playing controller ([_SharedAuthVideo]). The passcode lock sits above the
/// app's navigator while the login flow sits inside it, so the two are
/// separate widgets — but sharing the player means the lock opens over the
/// login card on the very frame the video was already showing, with no
/// restart and no jump.
class AuthBackground extends StatefulWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.blurSigma = 4.0,
    this.scrimOpacity = 0.0,
    this.videoOpacity = 1.0,
  });

  final Widget child;
  final double blurSigma;
  final double scrimOpacity;

  /// How much of the video layer is drawn, 0–1. Only the video: [child] is
  /// never faded through this, so glass in it is never inside the layer an
  /// opacity opens (see `backdrop-filter-black-flash`). Below 1, whatever is
  /// painted under this widget shows through the video.
  final double videoOpacity;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> {
  late final _SharedAuthVideo _video = _SharedAuthVideo.acquire();

  @override
  void dispose() {
    _video.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double videoOpacity = widget.videoOpacity.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // ── 1. Blurred video ─────────────────────────────────────────────────
        //   ImageFiltered applies blur directly to the VideoPlayer widget,
        //   which avoids BackdropFilter's inability to sample Texture layers.
        if (videoOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: videoOpacity,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _video.ready,
                  builder: (BuildContext context, bool ready, _) => ready
                      ? ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: widget.blurSigma,
                            sigmaY: widget.blurSigma,
                            tileMode: TileMode.mirror,
                          ),
                          child: _CoverVideo(controller: _video.controller),
                        )
                      : const ColoredBox(color: Colors.black),
                ),
              ),
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

/// The one looping backdrop video, shared by every [AuthBackground] that is
/// mounted at the same time and disposed when the last one goes.
class _SharedAuthVideo {
  _SharedAuthVideo._()
    : controller = VideoPlayerController.asset(
        _assetPath,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      ) {
    _prepare();
  }

  static const String _assetPath = 'assets/videos/onboarding_background.mp4';

  static _SharedAuthVideo? _current;

  static _SharedAuthVideo acquire() {
    final _SharedAuthVideo video = _current ??= _SharedAuthVideo._();
    video._users += 1;
    return video;
  }

  final VideoPlayerController controller;
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  int _users = 0;
  bool _disposed = false;

  Future<void> _prepare() async {
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      if (_disposed) return;
      ready.value = true;
      await controller.play();
    } catch (_) {
      // No video (a test, a broken asset): the black placeholder stays.
    }
  }

  void release() {
    _users -= 1;
    if (_users > 0) return;
    if (identical(_current, this)) _current = null;
    _disposed = true;
    ready.dispose();
    controller.dispose();
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
