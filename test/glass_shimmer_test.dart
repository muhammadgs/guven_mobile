import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/auth/presentation/widgets/auth_glass.dart';
import 'package:guven_mobile/src/shared/motion/glass_shimmer.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

LiquidGlassShape _shapeAt(double t) =>
    shimmerLiquidGlassStyle(kStartCtaGlass, t).shape!;

void main() {
  group('the flash', () {
    test('leaves the surface untouched at either end of the lap', () {
      expect(shimmerLiquidGlassStyle(kStartCtaGlass, 0), same(kStartCtaGlass));
      expect(shimmerLiquidGlassStyle(kStartCtaGlass, 1), same(kStartCtaGlass));
    });

    test('travels: the light angle only ever moves forward, one full lap', () {
      double previous = _shapeAt(0.001).lightDirection;
      for (double t = 0.001; t < 1; t += 0.01) {
        final double now = _shapeAt(t).lightDirection;
        expect(now, greaterThanOrEqualTo(previous), reason: 't=$t');
        previous = now;
      }
      final double base = kStartCtaGlass.shape!.lightDirection;
      expect(_shapeAt(0.999).lightDirection - base, closeTo(360, 1));
    });

    test('brightens and tightens at the peak, then gives it all back', () {
      final LiquidGlassShape base = kStartCtaGlass.shape!;
      final LiquidGlassShape peak = _shapeAt(0.5);

      expect(peak.lightIntensity, greaterThan(base.lightIntensity));
      expect(
        (peak.borderType as OpticalBorder).lightSpread,
        lessThan((base.borderType as OpticalBorder).lightSpread),
        reason: 'a broad highlight cannot be seen to travel',
      );
      expect(
        (peak.borderType as OpticalBorder).ambientIntensity,
        greaterThan((base.borderType as OpticalBorder).ambientIntensity),
      );

      // Nothing near the end of the lap: the rim is already home.
      expect(_shapeAt(0.99).lightIntensity, closeTo(base.lightIntensity, 0.05));
    });

    test('moves light and nothing else', () {
      final LiquidGlassStyle mid = shimmerLiquidGlassStyle(kStartCtaGlass, 0.5);

      expect(mid.appearance, same(kStartCtaGlass.appearance));
      expect(mid.refraction, same(kStartCtaGlass.refraction));
      expect(mid.shape!.cornerRadius, kStartCtaGlass.shape!.cornerRadius);
      expect(mid.shape!.cornerStyle, kStartCtaGlass.shape!.cornerStyle);
      expect(mid.shape!.borderWidth, kStartCtaGlass.shape!.borderWidth);
    });
  });

  group('the button', () {
    Future<LiquidGlassStyle> pumpButton(
      WidgetTester tester,
      VoidCallback onTap,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GlassPressButton(
              width: 200,
              height: 64,
              cornerRadius: 32,
              style: kStartCtaGlass,
              onTap: onTap,
              child: const Text('tap'),
            ),
          ),
        ),
      );
      return tester.widget<LiquidGlassLens>(find.byType(LiquidGlassLens)).style;
    }

    double lightOf(WidgetTester tester) => tester
        .widget<LiquidGlassLens>(find.byType(LiquidGlassLens))
        .style
        .shape!
        .lightDirection;

    testWidgets('takes the radius from its geometry, not its style', (
      WidgetTester tester,
    ) async {
      final LiquidGlassStyle resting = await pumpButton(tester, () {});
      // kStartCtaGlass carries a nominal 40; the button is a 64pt capsule.
      expect(resting.shape!.cornerRadius, 32);
    });

    testWidgets('flashes on touch-down and is back at rest after the lap', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, () {});
      final double rest = lightOf(tester);

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('tap')));
      // The first frame is the ticker's origin; time only starts after it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        lightOf(tester),
        greaterThan(rest),
        reason: 'the highlight should already be moving before the finger '
            'lifts — on the start button, lifting pushes a route',
      );

      await gesture.up();
      await tester.pump(kGlassShimmerDuration);
      await tester.pump();
      expect(lightOf(tester), rest);
    });

    testWidgets('still reports the tap', (WidgetTester tester) async {
      int taps = 0;
      await pumpButton(tester, () => taps++);

      await tester.tap(find.text('tap'));
      await tester.pump();
      expect(taps, 1);

      await tester.pump(kGlassShimmerDuration);
    });
  });
}
