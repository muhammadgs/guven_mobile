import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/shared/glass/glass_backdrop.dart';
import 'package:guven_mobile/src/shared/glass/liquid_glass.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/guven_glass_bottom_bar.dart';

const Key _lensKey = ValueKey<String>('nav-lens');
const Key _pillKey = ValueKey<String>('nav-selection-pill');

Widget _app({bool boundary = true}) {
  int selected = 1;
  final Widget home = StatefulBuilder(
    builder: (BuildContext context, StateSetter setState) {
      return ColoredBox(
        color: const Color(0xFF8899AA),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: SizedBox(
              width: 340,
              height: 64,
              child: GuvenGlassBottomBar(
                labels: const <String>['A', 'B', 'C', 'D'],
                icons: const <String>[
                  'assets/images/icons/nav_icons/home.svg',
                  'assets/images/icons/nav_icons/workers.svg',
                  'assets/images/icons/nav_icons/tasks.svg',
                  'assets/images/icons/nav_icons/home.svg',
                ],
                selectedIndex: selected,
                onSelected: (int next) => setState(() => selected = next),
                height: 64,
                iconSize: 22,
                textStyle: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
      );
    },
  );
  return MaterialApp(
    builder: boundary
        ? (BuildContext context, Widget? child) =>
              GlassScreenBoundary(child: child!)
        : null,
    home: home,
  );
}

double _pillAlpha(WidgetTester tester) {
  final DecoratedBox box = tester.widget(
    find.descendant(
      of: find.byKey(_pillKey),
      matching: find.byType(DecoratedBox),
    ),
  );
  return ((box.decoration as ShapeDecoration).color!).a;
}

void main() {
  setUp(() {
    final TestWidgetsFlutterBinding binding =
        TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });

  testWidgets('a touch swells the marker into a lens that follows the drag', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(LiquidGlassShader.load);
    expect(LiquidGlassShader.ready, isTrue);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byKey(_lensKey), findsNothing, reason: 'nothing touched');

    final Rect bar = tester.getRect(find.byType(GuvenGlassBottomBar));
    final Rect pill = tester.getRect(find.byKey(_pillKey));
    final TestGesture gesture = await tester.startGesture(pill.center);
    await tester.pump();
    // Frame by frame: the springs step at most 0.1 s a frame.
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final Rect lens = tester.getRect(find.byKey(_lensKey));
    // Swollen past the marker, and past the bar's own top and bottom.
    expect(lens.width, greaterThan(pill.width + 20));
    expect(lens.top, lessThan(bar.top));
    expect(lens.bottom, greaterThan(bar.bottom));
    expect(lens.center.dx, closeTo(pill.center.dx, 0.5));
    // The plain marker has handed over to it.
    expect(_pillAlpha(tester), lessThan(0.05));
    final RenderGlassBackdrop glass = tester.renderObject(
      find.descendant(
        of: find.byKey(_lensKey),
        matching: find.byType(GlassBackdropPaint),
      ),
    );
    expect(glass.debugIsLiquid, isTrue);
    expect(glass.debugPaintedRect, isNotNull, reason: 'it has a photograph');

    // Dragged 84 pt right, it goes with the finger (less the touch slop the
    // drag has to clear before it starts).
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(14, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Rect moved = tester.getRect(find.byKey(_lensKey));
    expect(moved.center.dx, greaterThan(lens.center.dx + 45));
    // Still swollen while the finger is down.
    expect(moved.top, lessThan(bar.top));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_lensKey), findsNothing, reason: 'shrunk away');
    expect(_pillAlpha(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a screen to photograph, the marker stays plain', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(LiquidGlassShader.load);
    await tester.pumpWidget(_app(boundary: false));
    await tester.pump();
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_pillKey)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_lensKey), findsNothing);
    expect(_pillAlpha(tester), 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
