// Smoke test for the pre-login onboarding flow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:guven_mobile/src/app/guven_app.dart';
import 'package:guven_mobile/src/features/auth/presentation/login_screen.dart';
import 'package:guven_mobile/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:guven_mobile/src/features/onboarding/presentation/widgets/start_cta_page.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';
import 'package:guven_mobile/src/shared/motion/glass_morph.dart';

const MethodChannel _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // AuthBackground plays a looping video on every pre-login screen. There is
    // no platform implementation under `flutter test`, so stand in a fake that
    // reports a ready, correctly-sized texture and does nothing else.
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
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

  testWidgets('The login card grows out of the start button', (
    WidgetTester tester,
  ) async {
    // A phone, so the layout's phone-calibrated clamps behave as designed.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GuvenApp());
    await tester.pump(const Duration(milliseconds: 50));

    // Swipe to the last onboarding page. Fling rather than drag — a drag with
    // no velocity has to clear half a page to turn it. And never
    // pumpAndSettle here: the background animates forever and would time out.
    for (int i = 0; i < OnboardingScreen.pageCount - 1; i++) {
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    final Finder button = find.ancestor(
      of: find.text('Başlayın'),
      matching: find.byType(AppGlassSurface),
    );
    expect(button, findsOneWidget);
    final Rect buttonRect = tester.getRect(button);

    await tester.tap(find.text('Başlayın'));
    await tester.pump();
    await tester.pump();

    // The morph measured the button itself, through a GlobalKey and
    // `localToGlobal`. If that measurement were off by so much as the status
    // bar, the card would open somewhere other than where the user tapped.
    // Anchored on the card's own title, since the back button beside it is a
    // lens too.
    final Finder card = find.ancestor(
      of: find.text('Giriş'),
      matching: find.byType(AppGlassSurface),
    );
    expect(tester.getRect(card), buttonRect);

    // …and the button itself has stopped painting, so only one pane of glass
    // is on that rect.
    expect(
      tester
          .widget<Visibility>(
            find.descendant(
              of: find.byType(StartCtaPage),
              matching: find.byType(Visibility),
            ),
          )
          .visible,
      isFalse,
    );

    // Land it: the card ends up bigger than the pill it came from, centred.
    await tester.pump(kGlassMorphDuration);
    final Rect landed = tester.getRect(card);
    expect(landed.height, greaterThan(buttonRect.height * 3));
    expect(
      landed.center.dx,
      moreOrLessEquals(buttonRect.center.dx, epsilon: 1),
    );

    // The glass back button has bloomed in beside the card, and pressing it
    // runs the whole thing backwards.
    final Finder back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(back, findsOneWidget);
    expect(
      tester.getRect(back).bottom,
      lessThan(landed.top),
      reason: 'the back button should clear the card, not sit on it',
    );

    await tester.tap(back);
    await tester.pump();
    await tester.pump(kGlassMorphReverseDuration ~/ 2);
    expect(
      tester.getRect(card).height,
      lessThan(landed.height),
      reason: 'the card should be shrinking back into the pill',
    );

    await tester.pump(kGlassMorphReverseDuration);
    await tester.pump();
    expect(find.byType(LoginScreen), findsNothing);
    // The button is painting again, on the rect it started from.
    expect(tester.getRect(button), buttonRect);
    expect(
      tester
          .widget<Visibility>(
            find.descendant(
              of: find.byType(StartCtaPage),
              matching: find.byType(Visibility),
            ),
          )
          .visible,
      isTrue,
    );
    // Re-enterable — the hand-off flag really was released — and this time the
    // system back closes it. Without the shell's NavigatorPopHandler that
    // would reach the root navigator and close the app instead.
    await tester.tap(find.text('Başlayın'));
    await tester.pump();
    await tester.pump(kGlassMorphDuration);
    expect(find.byType(LoginScreen), findsOneWidget);

    await _systemBack(tester);
    // Generous: the route pops a frame or two after the message lands, so the
    // reverse animation's clock starts later than the message does.
    await tester.pump();
    await tester.pump(kGlassMorphReverseDuration);
    await tester.pump(kGlassMorphReverseDuration);
    await tester.pump();
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}

/// Android's back button, as the framework sees it.
Future<void> _systemBack(WidgetTester tester) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (ByteData? _) {},
  );
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
