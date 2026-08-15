// Smoke test for the pre-login onboarding flow.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:guven_mobile/src/app/guven_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AuthBackground plays a looping video on every pre-login screen. There is
    // no platform implementation under `flutter test`, so stand in a fake that
    // reports a ready, correctly-sized texture and does nothing else.
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
  });

  testWidgets('Onboarding shows the welcome headline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GuvenApp());
    // The headline is in the tree from the first frame (it merely starts at
    // zero opacity), so a short pump is enough to find it. We must not
    // pumpAndSettle — the aurora background animates forever.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Xoş Gəlmişsiniz!'), findsOneWidget);

    // Drain the staggered entrance delays (Future.delayed) so no timer is left
    // pending when the widget tree is torn down.
    await tester.pump(const Duration(seconds: 2));
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  static const int _textureId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<int?> create(DataSource dataSource) async => _textureId;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream<VideoEvent>.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 29),
        size: const Size(480, 854),
        rotationCorrection: 0,
      ),
    );
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int textureId) => const SizedBox.expand();
}
