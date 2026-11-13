import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';
import 'package:guven_mobile/src/shared/glass/glass_backdrop.dart';

/// A plain [size]×[size] image to stand in for a blurred backdrop.
ui.Image _image(int size) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(size, size);
  picture.dispose();
  return image;
}

/// A 300×600 anchor whose backdrop picture covers it exactly.
class _Host extends StatefulWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final GlobalKey anchor = GlobalKey();
  final ValueNotifier<GlassBackdropImage?> backdrop =
      ValueNotifier<GlassBackdropImage?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backdrop.value = GlassBackdropImage(
        image: _image(150),
        size: const Size(300, 600),
        anchor: anchor.currentContext!.findRenderObject()!,
      );
    });
  }

  @override
  void dispose() {
    backdrop.value?.image.dispose();
    backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: anchor,
          width: 300,
          height: 600,
          child: GlassBackdropScope(backdrop: backdrop, child: widget.child),
        ),
      ),
    );
  }
}

RenderGlassBackdrop _glass(WidgetTester tester, [int index = 0]) => tester
    .renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdropPaint))
    .elementAt(index);

void main() {
  testWidgets('a baked glass reads no backdrop and paints its own piece', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Host(
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 20,
              top: 30,
              width: 60,
              height: 40,
              child: AppGlassSurface(
                style: AppGlassStyle(cornerRadius: 10),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      _glass(tester).debugPaintedRect,
      const Rect.fromLTWH(20, 30, 60, 40),
    );
  });

  testWidgets('glass in a list follows the scroll over a still picture', (
    WidgetTester tester,
  ) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _Host(
        child: ListView(
          controller: controller,
          children: <Widget>[
            for (int i = 0; i < 20; i++)
              const SizedBox(
                height: 100,
                child: GlassBackdropPaint(child: SizedBox.expand()),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(_glass(tester, 1).debugPaintedRect?.top, 100);

    controller.jumpTo(45);
    await tester.pump();
    expect(
      _glass(tester, 1).debugPaintedRect?.top,
      55,
      reason: 'a list item is moved, not repainted, unless the glass asks',
    );
  });

  testWidgets('glass moved without a repaint catches up a frame later', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<double> left = ValueNotifier<double>(10);
    addTearDown(left.dispose);
    await tester.pumpWidget(
      _Host(
        child: ValueListenableBuilder<double>(
          valueListenable: left,
          builder: (BuildContext context, double x, Widget? child) => Stack(
            children: <Widget>[Positioned(left: x, top: 10, child: child!)],
          ),
          // Its own repaint boundary: moving it moves its layer, and nothing
          // inside is asked to repaint.
          child: const RepaintBoundary(
            child: SizedBox(
              width: 50,
              height: 50,
              child: GlassBackdropPaint(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_glass(tester).debugPaintedRect?.left, 10);

    left.value = 90;
    await tester.pump();
    await tester.pump();
    expect(_glass(tester).debugPaintedRect?.left, 90);
  });

  testWidgets('a scrim fades the picture in with its own progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Host(
        child: AppBackdropBlur(
          sigma: 12,
          amount: 0.4,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    final GlassBackdropPaint paint = tester.widget<GlassBackdropPaint>(
      find.byType(GlassBackdropPaint),
    );
    expect(paint.amount, 0.4);
    expect(
      _glass(tester).debugPaintedRect,
      const Rect.fromLTWH(0, 0, 300, 600),
    );
  });

  testWidgets('a panel photographs the screen it opens over', (
    WidgetTester tester,
  ) async {
    final AnimationController open = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(open.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassScreenBoundary(
          child: Stack(
            children: <Widget>[
              const ColoredBox(color: Color(0xFF00FF00)),
              FrozenGlassBackdrop(
                animation: open,
                child: const GlassBackdropPaint(child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_glass(tester).debugPaintedRect, isNull, reason: 'shut: nothing');

    open.forward();
    await tester.pump();
    expect(_glass(tester).debugPaintedRect, isNotNull, reason: 'opened');

    await tester.pumpAndSettle();
    open.reverse();
    await tester.pumpAndSettle();
    await tester.pump();
    expect(_glass(tester).debugPaintedRect, isNull, reason: 'shut again');
  });

  testWidgets('a region photograph leaves out what is hidden from it', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final GlobalKey anchor = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassScreenBoundary(
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF00FF00)),
              ),
              Positioned(
                left: 50,
                top: 50,
                width: 100,
                height: 40,
                child: SizedBox(key: anchor),
              ),
              // A red marker inside the anchor, kept out of the photograph.
              const Positioned(
                left: 60,
                top: 60,
                width: 20,
                height: 20,
                child: GlassCaptureHidden(
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final RenderBox box = tester.renderObject(find.byKey(anchor));
    final GlassBackdropImage? picture = captureScreenRegion(
      anchor: box,
      region: const Rect.fromLTRB(-10, -10, 110, 50),
      pixelRatio: 2,
    );
    expect(picture, isNotNull);
    addTearDown(picture!.dispose);
    // Reaching 10 out on every side, in the anchor's own coordinates.
    expect(picture.origin, const Offset(-10, -10));
    expect(picture.size, const Size(120, 60));
    expect(picture.image.width, 240);
    expect(picture.image.height, 120);

    final ByteData bytes = (await tester.runAsync<ByteData?>(
      () => picture.image.toByteData(),
    ))!;
    // Where the red marker stands on screen (70, 70) → (20, 20) logical in
    // the photograph → (40, 40) pixels: green, the marker left out.
    final int i = (40 * 240 + 40) * 4;
    expect(
      <int>[bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)],
      <int>[0, 255, 0],
    );

    // And the screen itself still shows it: its switch is back on.
    final RenderBox marker = tester.renderObject(
      find.descendant(
        of: find.byType(GlassCaptureHidden),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(marker.debugNeedsPaint, isFalse);
    expect(
      marker.parent!.debugLayer,
      isA<OpacityLayer>().having((OpacityLayer l) => l.alpha, 'alpha', 255),
    );
  });

  testWidgets('without a screen boundary there is no region photograph', (
    WidgetTester tester,
  ) async {
    final GlobalKey anchor = GlobalKey();
    await tester.pumpWidget(SizedBox(key: anchor, width: 10, height: 10));
    expect(
      captureScreenRegion(
        anchor: tester.renderObject(find.byKey(anchor)),
        region: const Rect.fromLTWH(0, 0, 10, 10),
        pixelRatio: 1,
      ),
      isNull,
    );
  });

  testWidgets('a blurred picture keeps its edges opaque', (
    WidgetTester tester,
  ) async {
    final ui.Image source = _image(64);
    final ui.Image blurred = blurImageSync(
      source,
      width: 32,
      height: 32,
      sigma: 6,
    );
    final ByteData? bytes = await tester.runAsync<ByteData?>(
      () => blurred.toByteData(),
    );
    source.dispose();
    blurred.dispose();
    final Uint8List rgba = bytes!.buffer.asUint8List();
    // Alpha of the four corners.
    for (final int pixel in <int>[0, 31, 32 * 31, 32 * 32 - 1]) {
      expect(rgba[pixel * 4 + 3], greaterThan(250), reason: 'corner $pixel');
    }
  });
}
