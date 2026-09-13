import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/shell/domain/shell_destination.dart';

/// The nav bar's glyphs, loaded from the bundle the way the bar loads them.
///
/// A path that is not in `pubspec.yaml`, or an SVG this renderer cannot parse,
/// fails when the bar is first drawn on a device and nowhere earlier. The
/// second group pins `Daha çox`'s pair, which the bar cross-fades between: they
/// are one construction mirrored into four quadrants, so a transform that this
/// renderer reads differently from a browser would silently move a lobe.
void main() {
  final List<String> icons = <String>[
    for (final ShellDestination d in ShellDestination.values) d.icon,
    kMenuIcon,
    kMenuOpenIcon,
  ];

  for (final String icon in icons) {
    testWidgets('$icon loads and draws', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }

  testWidgets('the Daha çox pair is congruent and registers', (
    WidgetTester tester,
  ) async {
    const int side = 96;
    // The art keeps a 1.4 keyline margin inside a 24 box; see menu.svg.
    const double want = 21.2 / 24 * side;

    late final _Ink filled;
    late final _Ink outline;
    // Rasterising needs the real async frame; the fake one never resolves it.
    await tester.runAsync(() async {
      filled = await _render(kMenuIcon, side);
      outline = await _render(kMenuOpenIcon, side);
    });

    for (final _Ink ink in <_Ink>[filled, outline]) {
      // One pixel of slack each way for the edge's anti-aliasing.
      expect(ink.width, closeTo(want, 1.5));
      expect(ink.height, closeTo(want, 1.5));
      expect(ink.left + ink.right, closeTo(side.toDouble(), 1.5));
      expect(ink.top + ink.bottom, closeTo(side.toDouble(), 1.5));

      // Each glyph is one quadrant mirrored twice over. If a mirror landed
      // wrong the drawing stops being symmetric about either axis.
      expect(ink.mirrorErrorX, lessThan(0.01));
      expect(ink.mirrorErrorY, lessThan(0.01));
    }

    // The outline is the filled glyph's own silhouette, drawn as a stroke
    // half in and half out of it — so the two must cover the same square.
    expect(outline.width, closeTo(filled.width, 1.5));
    expect(outline.left, closeTo(filled.left, 1.5));
  });
}

/// Where the ink of a rasterised glyph sits, and how symmetric it is.
class _Ink {
  _Ink(this.alpha, this.side);

  final Uint8List alpha;
  final int side;

  double _at(int x, int y) => alpha[y * side + x] / 255;

  late final double left = _edge(_column);
  late final double right = _edgeFromEnd(_column);
  late final double top = _edge(_row);
  late final double bottom = _edgeFromEnd(_row);

  double get width => right - left;
  double get height => bottom - top;

  double _column(int x) {
    double sum = 0;
    for (int y = 0; y < side; y++) {
      sum += _at(x, y);
    }
    return sum;
  }

  double _row(int y) {
    double sum = 0;
    for (int x = 0; x < side; x++) {
      sum += _at(x, y);
    }
    return sum;
  }

  /// The first line that carries ink — anything fainter is the edge's own
  /// anti-aliasing bleeding a pixel outward.
  double _edge(double Function(int) line) {
    for (int i = 0; i < side; i++) {
      if (line(i) > 0.25) return i.toDouble();
    }
    return 0;
  }

  /// One past the last line that carries ink.
  double _edgeFromEnd(double Function(int) line) {
    for (int i = side - 1; i >= 0; i--) {
      if (line(i) > 0.25) return (i + 1).toDouble();
    }
    return side.toDouble();
  }

  /// Mean per-pixel disagreement with this glyph's own mirror image, 0 when
  /// the two halves match exactly.
  late final double mirrorErrorX = _mirrorError((int x, int y) => (side - 1 - x, y));
  late final double mirrorErrorY = _mirrorError((int x, int y) => (x, side - 1 - y));

  double _mirrorError((int, int) Function(int, int) flip) {
    double sum = 0;
    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        final (int fx, int fy) = flip(x, y);
        sum += (_at(x, y) - _at(fx, fy)).abs();
      }
    }
    return sum / (side * side);
  }
}

/// [asset] drawn on its own into a [side]-square, as the alpha of every pixel.
Future<_Ink> _render(String asset, int side) async {
  final PictureInfo info = await vg.loadPicture(SvgAssetLoader(asset), null);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.scale(side / info.size.width, side / info.size.height);
  canvas.drawPicture(info.picture);

  // The recording still refers to the picture: dispose it any earlier and the
  // image comes back blank.
  final ui.Image image = await recorder.endRecording().toImage(side, side);
  info.picture.dispose();
  final ByteData data = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  image.dispose();

  final Uint8List alpha = Uint8List(side * side);
  for (int i = 0; i < alpha.length; i++) {
    alpha[i] = data.getUint8(i * 4 + 3);
  }
  return _Ink(alpha, side);
}
