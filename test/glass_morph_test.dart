import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/auth/presentation/login_screen.dart';
import 'package:guven_mobile/src/features/auth/presentation/widgets/auth_glass.dart';
import 'package:guven_mobile/src/shared/motion/glass_morph.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// A phone-sized stand-in for the two ends of the auth morph.
const Rect _pill = Rect.fromLTWH(70, 470, 250, 70);
const Rect _card = Rect.fromLTWH(24, 192, 342, 460);

/// The login card's lens — anchored on the card's own title, since the back
/// button beside it is a lens as well.
final Finder _cardLens = find.ancestor(
  of: find.text('Giriş'),
  matching: find.byType(LiquidGlassLens),
);

GlassMorphFrame _frameAt(double t, {bool back = false}) {
  final AnimationController controller = AnimationController(
    vsync: const TestVSync(),
    duration: kGlassMorphDuration,
    reverseDuration: kGlassMorphReverseDuration,
  );
  addTearDown(controller.dispose);
  controller.value = t;
  if (back && t > 0 && t < 1) controller.reverse();

  return resolveGlassMorph(
    progress: controller,
    from: _pill,
    fromRadius: _pill.height / 2,
    to: _card,
    toRadius: 56,
  );
}

void main() {
  // `reverse()` reaches for the semantics binding to decide whether to honour
  // the animation, so the direction-dependent cases need one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('geometry', () {
    test('opens exactly on the button and lands exactly on the card', () {
      expect(_frameAt(0).rect, _pill);
      expect(_frameAt(0).radius, _pill.height / 2);
      expect(_frameAt(1).rect, _card);
      expect(_frameAt(1).radius, 56);
    });

    test('the radius can never exceed a capsule at the current size', () {
      for (double t = 0; t <= 1.0001; t += 0.02) {
        final GlassMorphFrame frame = _frameAt(t.clamp(0.0, 1.0));
        expect(
          frame.radius,
          lessThanOrEqualTo(frame.rect.shortestSide / 2 + 1e-9),
          reason: 'corner blew past the capsule at t=$t',
        );
        expect(frame.radius, greaterThan(0));
      }
    });

    test('width leads, height follows', () {
      double travelled(double from, double to, double now) =>
          (now - from) / (to - from);

      final GlassMorphFrame early = _frameAt(0.15);
      expect(
        travelled(_pill.width, _card.width, early.rect.width),
        greaterThan(travelled(_pill.height, _card.height, early.rect.height)),
      );
    });

    test('height overshoots a little, and only a little', () {
      double peak = 0;
      for (double t = 0; t <= 1.0001; t += 0.005) {
        peak = peak > _frameAt(t.clamp(0.0, 1.0)).rect.height
            ? peak
            : _frameAt(t.clamp(0.0, 1.0)).rect.height;
      }
      expect(peak, greaterThan(_card.height));
      expect(peak / _card.height, lessThan(1.03));
    });

    test('never leaves the phone it is flying across', () {
      const Rect screen = Rect.fromLTWH(0, 0, 390, 844);
      for (double t = 0; t <= 1.0001; t += 0.01) {
        final Rect rect = _frameAt(t.clamp(0.0, 1.0)).rect;
        expect(screen.contains(rect.topLeft), isTrue, reason: 't=$t');
        expect(screen.contains(rect.bottomRight), isTrue, reason: 't=$t');
      }
    });
  });

  group('cross-fade', () {
    test('only one content is ever fully present', () {
      for (double t = 0; t <= 1.0001; t += 0.01) {
        final GlassMorphFrame frame = _frameAt(t.clamp(0.0, 1.0));
        expect(
          frame.sourceOpacity + frame.targetOpacity,
          lessThanOrEqualTo(1.0001),
          reason: 'the label and the form overlap at t=$t',
        );
      }
    });

    test('the label is gone before the form arrives', () {
      expect(_frameAt(0).sourceOpacity, 1);
      expect(_frameAt(0.2).sourceOpacity, 0);
      expect(_frameAt(0.4).targetOpacity, 0);
      expect(_frameAt(1).targetOpacity, 1);
    });

    test('coming back, the form leaves before the pill reforms', () {
      expect(_frameAt(0.8, back: true).sourceOpacity, 0);
      expect(_frameAt(0.6, back: true).targetOpacity, 0);
      expect(_frameAt(0.1, back: true).sourceOpacity, greaterThan(0.5));
    });
  });

  group('in a route', () {
    /// A phone, so the layout's phone-calibrated clamps behave as designed.
    void asAPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('the card opens on the button and lands centred', (
      WidgetTester tester,
    ) async {
      asAPhone(tester);
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
      );

      navigator.currentState!.push(
        GlassMorphRoute<void>(
          sourceRect: _pill,
          sourceRadius: _pill.height / 2,
          builder: (_) => const LoginScreen(),
        ),
      );
      // Two frames, neither advancing the clock: the first lands the route in
      // the navigator's history, the second builds it. The morph is still at
      // zero.
      await tester.pump();
      await tester.pump();

      // The lens is laid out from a rect the button measured in *global*
      // coordinates, so this is the check that that coordinate space really
      // does survive the trip into the pushed route.
      // The card, specifically: the back button beside it is a lens too.
      final Finder lens = _cardLens;
      expect(tester.getRect(lens), _pill);

      // Halfway out: still one lens, still on screen, still no reflow.
      await tester.pump(kGlassMorphDuration ~/ 2);
      expect(lens, findsOneWidget);
      final Rect midway = tester.getRect(lens);
      expect(midway.width, greaterThan(_pill.width));
      expect(midway.height, greaterThan(_pill.height));

      await tester.pump(kGlassMorphDuration);
      expect(
        tester.getRect(lens),
        const Rect.fromLTWH(28, 192, 334, 460),
      );
    });

    testWidgets('lands the same way when pushed without a morph', (
      WidgetTester tester,
    ) async {
      asAPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      expect(
        tester.getRect(_cardLens),
        const Rect.fromLTWH(28, 192, 334, 460),
      );
      expect(find.text('Giriş'), findsOneWidget);
    });
  });

  group('style', () {
    test('frame zero is the start button, to the uniform', () {
      final LiquidGlassStyle button =
          glassAtRadius(kStartCtaGlass, _pill.height / 2);
      final LiquidGlassStyle morphed = lerpLiquidGlassStyle(
        kStartCtaGlass,
        kLoginCardGlass,
        0,
        cornerRadius: _pill.height / 2,
      );

      expect(morphed.shape!.cornerStyle, button.shape!.cornerStyle);
      expect(morphed.shape!.cornerRadius, button.shape!.cornerRadius);
      expect(morphed.shape!.lightIntensity, button.shape!.lightIntensity);
      expect(morphed.appearance.color, button.appearance.color);
      expect(morphed.appearance.saturation, button.appearance.saturation);
      // The morph hands the refraction over to an explicit model; the button
      // leaves it null. What reaches the shader has to match either way.
      expect(
        morphed.refraction.effectiveDistortion,
        button.refraction.effectiveDistortion,
      );
      expect(
        morphed.refraction.effectiveDistortionWidth,
        button.refraction.effectiveDistortionWidth,
      );
      expect(
        morphed.refraction.effectiveRefractionIndex,
        button.refraction.effectiveRefractionIndex,
      );
      expect(morphed.refraction.magnification, button.refraction.magnification);
    });

    test('frame one is the login card', () {
      final LiquidGlassStyle morphed =
          lerpLiquidGlassStyle(kStartCtaGlass, kLoginCardGlass, 1);

      expect(morphed.appearance.color, kLoginCardGlass.appearance.color);
      expect(
        morphed.refraction.effectiveRefractionIndex,
        kLoginCardGlass.refraction.effectiveRefractionIndex,
      );
      expect(
        morphed.refraction.effectiveDistortion,
        kLoginCardGlass.refraction.effectiveDistortion,
      );
      expect(
        (morphed.shape!.borderType as OpticalBorder).ambientIntensity,
        (kLoginCardGlass.shape!.borderType as OpticalBorder).ambientIntensity,
      );
    });

    test('the refraction band never jumps across the model handover', () {
      double? previous;
      for (double t = 0; t <= 1.0001; t += 0.005) {
        final LiquidGlassStyle style = lerpLiquidGlassStyle(
          kStartCtaGlass,
          kLoginCardGlass,
          t.clamp(0.0, 1.0),
        );
        final double width = style.refraction.effectiveDistortionWidth;
        final double strength = style.refraction.effectiveDistortion;
        if (previous != null) {
          expect((width - previous).abs(), lessThan(0.5), reason: 't=$t');
        }
        previous = width;
        expect(strength, inInclusiveRange(0.12, 0.17));
      }
    });
  });
}
