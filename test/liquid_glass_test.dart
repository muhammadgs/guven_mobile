import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';
import 'package:guven_mobile/src/shared/glass/glass_backdrop.dart';
import 'package:guven_mobile/src/shared/glass/liquid_glass.dart';

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

/// A 400×300 backdrop picture: red left of x = 120, blue from there on.
ui.Image _splitImage() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 120, 300), Paint()..color = _red)
    ..drawRect(const Rect.fromLTWH(120, 0, 280, 300), Paint()..color = _blue);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = picture.toImageSync(400, 300);
  picture.dispose();
  return image;
}

/// A 400×300 anchor whose backdrop picture is [_splitImage], drawn as-is
/// underneath so the glass can be compared against what it stands on.
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
  late final ui.Image under = _splitImage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backdrop.value = GlassBackdropImage(
        image: _splitImage(),
        size: const Size(400, 300),
        anchor: anchor.currentContext!.findRenderObject()!,
      );
    });
  }

  @override
  void dispose() {
    backdrop.value?.dispose();
    backdrop.dispose();
    under.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: SizedBox(
            key: anchor,
            width: 400,
            height: 300,
            child: GlassBackdropScope(
              backdrop: backdrop,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: RawImage(image: under)),
                  widget.child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A transparent 200×100 liquid surface at (100, 100) — its left edge sits
/// 20 logical pixels left of the red/blue split.
const Widget _surface = Positioned(
  left: 100,
  top: 100,
  width: 200,
  height: 100,
  child: AppGlassSurface(
    style: AppGlassStyle(cornerRadius: 20),
    child: SizedBox.expand(),
  ),
);

Future<Color Function(int x, int y)> _snapshot(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  );
  final ByteData bytes = (await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    try {
      return await image.toByteData();
    } finally {
      image.dispose();
    }
  }))!;
  return (int x, int y) {
    final int i = (y * 400 + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  };
}

double _luma(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

void main() {
  test('uniforms map the surface onto its piece of the picture', () {
    final List<double> floats = liquidGlassUniforms(
      offset: const Offset(5, 6),
      size: const Size(200, 100),
      pxPerUnit: 3,
      spec: const LiquidGlassSpec(
        cornerRadius: 20,
        tint: Color(0x80FFFFFF),
        fade: 0.5,
      ),
      pictureSize: const Size(400, 300),
      pictureRect: const Rect.fromLTWH(100, 150, 200, 100),
      hasSharp: true,
    );
    expect(floats, hasLength(32));
    expect(floats.sublist(0, 8), <double>[5, 6, 200, 100, 20, 3, 0.5, 1]);
    expect(floats.sublist(8, 12), <double>[0.25, 0.5, 0.75, 250 / 300]);
    expect(floats[15], closeTo(0x80 / 255, 1e-9));
    expect(floats.sublist(16, 20), <double>[20, 60, 0, 1]);
    expect(floats[25], 1, reason: 'has a sharp copy');
    expect(floats.sublist(28, 30), <double>[1, 1], reason: 'no lens');
  });

  test('a clear lens sends its magnification and its own bevel rule', () {
    final List<double> floats = liquidGlassUniforms(
      offset: Offset.zero,
      size: const Size(80, 50),
      pxPerUnit: 1,
      spec: const LiquidGlassSpec(
        cornerRadius: 25,
        tint: Color(0x00000000),
        optics: LiquidGlassOptics(magnification: 1.18, fitsShape: false),
      ),
    );
    expect(floats.sublist(28, 30), <double>[1.18, 0]);
  });

  test('without a picture the shader is told it has none', () {
    final List<double> floats = liquidGlassUniforms(
      offset: Offset.zero,
      size: const Size(10, 10),
      pxPerUnit: 1,
      spec: const LiquidGlassSpec(cornerRadius: 5, tint: Color(0x00000000)),
    );
    expect(floats[7], 0);
    expect(floats.sublist(8, 12), <double>[0, 0, 1, 1]);
    expect(floats[25], 0);
  });

  testWidgets('before the shader loads, glass is the plain frost', (
    WidgetTester tester,
  ) async {
    expect(LiquidGlassShader.ready, isFalse);
    await tester.pumpWidget(
      const _Host(child: Stack(children: <Widget>[_surface])),
    );
    await tester.pump();
    expect(
      tester
          .renderObject<RenderGlassBackdrop>(find.byType(GlassBackdropPaint))
          .debugIsLiquid,
      isFalse,
    );
  });

  // Each test loads the shader outside the fake-async zone (real file work);
  // after the first, `load` returns at once.
  group('once the shader has loaded', () {
    testWidgets('the shader loads and glass turns liquid', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(LiquidGlassShader.load);
      expect(LiquidGlassShader.ready, isTrue);
      await tester.pumpWidget(
        const _Host(child: Stack(children: <Widget>[_surface])),
      );
      await tester.pump();
      final RenderGlassBackdrop glass = tester.renderObject(
        find.byType(GlassBackdropPaint),
      );
      expect(glass.debugIsLiquid, isTrue);
      expect(glass.debugPaintedRect, const Rect.fromLTWH(100, 100, 200, 100));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('the edge bends the backdrop; the middle does not', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(LiquidGlassShader.load);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const _Host(child: Stack(children: <Widget>[_surface])),
      );
      await tester.pump();
      final Color Function(int, int) at = await _snapshot(tester);

      // Outside the glass, the picture as it is.
      expect(at(110, 50), _red);
      // The middle of the glass is flat: exactly what is behind it.
      expect(at(200, 150), _blue);
      // 5.5 pt in from the left edge the backdrop is red (x 105 < 120), but
      // the lens (bevel 20, amount 50 on a 100-tall surface) pulls in what
      // lies 15.6 pt further in, at x 121: blue.
      final Color bent = at(105, 150);
      expect(bent.b, greaterThan(0.6), reason: '$bent');
      expect(bent.r, lessThan(0.4), reason: '$bent');
      // At the bevel's inner end the pull has faded to nothing: red again.
      final Color settled = at(119, 150);
      expect(settled.r, greaterThan(0.6), reason: '$settled');
      expect(settled.b, lessThan(0.4), reason: '$settled');
    });

    testWidgets('a lens magnifies what is under it about its middle', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(LiquidGlassShader.load);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      // Centred at x 160, 40 right of the red/blue split; no bend, so only
      // the magnification moves anything.
      const Widget lens = Positioned(
        left: 60,
        top: 100,
        width: 200,
        height: 100,
        child: AppGlassSurface(
          style: AppGlassStyle(
            cornerRadius: 20,
            optics: LiquidGlassOptics(
              refractionHeight: 1,
              refractionAmount: 0,
              fitsShape: false,
              highlight: 0,
              contourStrength: 0,
              bevelShadowStrength: 0,
              magnification: 2,
            ),
          ),
          child: SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(
        const _Host(child: Stack(children: <Widget>[lens])),
      );
      await tester.pump();
      final Color Function(int, int) at = await _snapshot(tester);

      // At x 100 the backdrop is red, but the lens shows what lies half as
      // far from its middle: x 130, blue.
      final Color magnified = at(100, 150);
      expect(magnified.b, greaterThan(0.6), reason: '$magnified');
      expect(magnified.r, lessThan(0.4), reason: '$magnified');
      // At x 70 it shows x 115: still red.
      final Color near = at(70, 150);
      expect(near.r, greaterThan(0.6), reason: '$near');
      // Outside the lens, the backdrop as it is.
      expect(at(100, 90), _red);
    });

    testWidgets('the top edge glints and the side wall has a dark hairline', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(LiquidGlassShader.load);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const _Host(child: Stack(children: <Widget>[_surface])),
      );
      await tester.pump();
      final Color Function(int, int) at = await _snapshot(tester);

      // The top rim, mid-width, is brighter than the glass below it.
      expect(_luma(at(200, 100)), greaterThan(_luma(at(200, 150)) + 0.05));
      // Half a pixel outside the left wall the hairline (0.75 pt, 43%, full
      // strength on a side wall) lays ~16% black over the red ground.
      final Color hairline = at(99, 150);
      expect(hairline.r, lessThan(0.9), reason: '$hairline');
      expect(hairline.r, greaterThan(0.7), reason: '$hairline');
      // Far outside, nothing.
      expect(at(95, 150), _red);
    });
  });
}
