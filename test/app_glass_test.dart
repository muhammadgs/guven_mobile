import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/auth/presentation/widgets/auth_glass.dart';
import 'package:guven_mobile/src/features/home/presentation/widgets/home_glass.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, VoidCallback onTap) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 64,
            child: AppGlassButton(
              style: glassAtRadius(kStartCtaGlass, 32),
              cornerRadius: 32,
              onTap: onTap,
              child: const Center(child: Text('tap')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a glass button reports its tap', (WidgetTester tester) async {
    int taps = 0;
    await pumpButton(tester, () => taps++);

    await tester.tap(find.text('tap'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a pressed button neither grows nor changes its glass', (
    WidgetTester tester,
  ) async {
    await pumpButton(tester, () {});
    final Rect rest = tester.getRect(find.byType(AppGlassSurface));
    final AppGlassStyle style = tester
        .widget<AppGlassSurface>(find.byType(AppGlassSurface))
        .style;

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('tap')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(find.byType(AppGlassSurface)), rest);
    expect(
      tester.widget<AppGlassSurface>(find.byType(AppGlassSurface)).style,
      same(style),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a glass surface is a tint with no rim, and no live blur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AppGlassSurface(
          style: kStatPillGlass,
          cornerRadius: 20,
          child: SizedBox(width: 100, height: 40),
        ),
      ),
    );

    // The default build blurs once, ahead of time: no live backdrop read.
    expect(find.byType(BackdropFilter), findsNothing);
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppGlassSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    final BoxDecoration decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color, kStatPillGlass.glassColor);
  });
}
