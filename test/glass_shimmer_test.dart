import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/auth/presentation/widgets/auth_glass.dart';
import 'package:guven_mobile/src/features/home/presentation/widgets/home_glass.dart';
import 'package:guven_mobile/src/shared/motion/glass_shimmer.dart';
import 'package:guven_mobile/src/shared/motion/glass_touch_surface.dart';

AppGlassStyle _styleAt(double t) => shimmerAppGlassStyle(kStartCtaGlass, t);

void main() {
  group('the flash', () {
    test('leaves the surface untouched at either end of the lap', () {
      expect(shimmerAppGlassStyle(kStartCtaGlass, 0), same(kStartCtaGlass));
      expect(shimmerAppGlassStyle(kStartCtaGlass, 1), same(kStartCtaGlass));
    });

    test('travels: the light angle only ever moves forward, one full lap', () {
      double previous = _styleAt(0.001).settings.lightAngle;
      for (double t = 0.001; t < 1; t += 0.01) {
        final double now = _styleAt(t).settings.lightAngle;
        expect(now, greaterThanOrEqualTo(previous), reason: 't=$t');
        previous = now;
      }
      final double base = kStartCtaGlass.settings.lightAngle;
      expect(
        _styleAt(0.999).settings.lightAngle - base,
        closeTo(math.pi * 2, 0.02),
      );
    });

    test('brightens and tightens at the peak, then gives it all back', () {
      final AppGlassStyle base = kStartCtaGlass;
      final AppGlassStyle peak = _styleAt(0.5);

      expect(
        peak.settings.lightIntensity,
        greaterThan(base.settings.lightIntensity),
      );
      expect(
        peak.legacy.lightSpread,
        lessThan(base.legacy.lightSpread),
        reason: 'a broad highlight cannot be seen to travel',
      );
      expect(
        peak.settings.ambientStrength,
        greaterThan(base.settings.ambientStrength),
      );

      // Nothing near the end of the lap: the rim is already home.
      expect(
        _styleAt(0.99).settings.lightIntensity,
        closeTo(base.settings.lightIntensity, 0.05),
      );
    });

    test('moves light and nothing else', () {
      final AppGlassStyle mid = shimmerAppGlassStyle(kStartCtaGlass, 0.5);

      expect(mid.cornerRadius, kStartCtaGlass.cornerRadius);
      expect(mid.settings.glassColor, kStartCtaGlass.settings.glassColor);
      expect(mid.settings.thickness, kStartCtaGlass.settings.thickness);
      expect(mid.settings.blur, kStartCtaGlass.settings.blur);
      expect(
        mid.settings.refractiveIndex,
        kStartCtaGlass.settings.refractiveIndex,
      );
      expect(mid.legacy.distortion, kStartCtaGlass.legacy.distortion);
    });
  });

  group('the button', () {
    Future<AppGlassStyle> pumpButton(
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
      return tester.widget<AppGlassSurface>(find.byType(AppGlassSurface)).style;
    }

    double lightOf(WidgetTester tester) => tester
        .widget<AppGlassSurface>(find.byType(AppGlassSurface))
        .style
        .settings
        .lightAngle;

    testWidgets('takes the radius from its geometry, not its style', (
      WidgetTester tester,
    ) async {
      final AppGlassStyle resting = await pumpButton(tester, () {});
      // kStartCtaGlass carries a nominal 40; the button is a 64pt capsule.
      expect(resting.cornerRadius, 32);
    });

    testWidgets('flashes on touch-down and is back at rest after the lap', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, () {});
      final double rest = lightOf(tester);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('tap')),
      );
      // The first frame is the ticker's origin; time only starts after it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        lightOf(tester),
        greaterThan(rest),
        reason:
            'the highlight should already be moving before the finger '
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

  testWidgets('the stat glow survives press, release, and unmount', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 64,
            child: AppGlassLayer(
              style: kStatPillGlass,
              child: GlassTouchSurface(
                style: kStatPillGlass,
                cornerRadius: 32,
                child: const Center(child: Text('stat')),
              ),
            ),
          ),
        ),
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('stat')),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
