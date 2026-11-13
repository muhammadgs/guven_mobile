import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../glass/app_glass.dart' show kGlassMinBlur;
import '../glass/glass_backdrop.dart';
import '../glass/liquid_glass.dart';

/// The backdrop every signed-in screen sits on.
///
/// A pale wash with a few soft aurora shapes drifting through it, drawn from
/// the design's own vector so the blobs land where they were composed rather
/// than approximated in code.
///
/// It is deliberately quiet: everything above it is frosted glass, and the
/// text on those surfaces has to stay readable. It also never moves.
///
/// Because it never moves, it is also what every glass surface on it shows
/// through: once the artwork is baked, a blurred copy of it is made once and
/// handed down as the [GlassBackdropScope], and each surface paints its own
/// piece of that copy instead of blurring live.
///
/// The counterpart to the pre-login [AuthBackground], which is a video and
/// dark; this one is still and light.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child});

  static const String _asset = 'assets/images/background/home_aurora.svg';

  final Widget child;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  /// The box the artwork fills; glass finds its piece of the blurred copy
  /// from its own position in this box.
  final GlobalKey _anchor = GlobalKey(debugLabel: 'app background');

  final ValueNotifier<GlassBackdropImage?> _backdrop =
      ValueNotifier<GlassBackdropImage?>(null);

  @override
  void dispose() {
    _backdrop.value?.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  /// One logical pixel per pixel is plenty for something this soft.
  ///
  /// Liquid glass also bends the unblurred artwork at its rim: a second
  /// handle on the bitmap already on screen, so it costs no memory.
  void _onBaked(ui.Image artwork, Size size) {
    final RenderObject? anchor = _anchor.currentContext?.findRenderObject();
    final int width = size.width.round();
    final int height = size.height.round();
    if (anchor == null || width <= 0 || height <= 0) return;
    final GlassBackdropImage? previous = _backdrop.value;
    _backdrop.value = GlassBackdropImage(
      image: blurImageSync(
        artwork,
        width: width,
        height: height,
        sigma: kGlassMinBlur,
      ),
      sharp: LiquidGlassShader.ready ? artwork.clone() : null,
      size: size,
      anchor: anchor,
    );
    previous?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: _anchor,
      // Painted under the artwork as well as around it: the artwork is a fixed
      // 463×874 portrait, and `cover` on a wider or taller device would
      // otherwise show through at the edges before it has decoded.
      color: const Color(0xFFF2F7FE),
      child: GlassBackdropScope(
        backdrop: _backdrop,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(child: _BakedAurora(onBaked: _onBaked)),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// The aurora, drawn once into a bitmap at the screen's own pixel size.
///
/// Drawn live, the vector costs on every frame: nine translucent groups —
/// each one an offscreen pass — 57 paths and 16 gradients, redrawn whenever
/// anything on the screen animates (Impeller keeps no raster cache) and then
/// blurred again by every glass surface above it. Baked, it is one texture.
///
/// Until the bitmap is ready — the first frame or two, and again after the
/// size changes — the vector is drawn as before, so nothing ever flashes.
class _BakedAurora extends StatefulWidget {
  const _BakedAurora({required this.onBaked});

  /// Called with each finished bitmap and the logical size it covers, while
  /// the bitmap is still alive — copy or `clone()` it, do not keep it.
  final void Function(ui.Image artwork, Size size) onBaked;

  @override
  State<_BakedAurora> createState() => _BakedAuroraState();
}

class _BakedAuroraState extends State<_BakedAurora> {
  ui.Image? _image;

  /// The logical size and pixel ratio [_image] was drawn for.
  Size? _imageSize;
  double _imageRatio = 0;

  /// What the bake in flight, or the last one, was asked for.
  Size? _requestedSize;
  double _requestedRatio = 0;

  /// Bumped per bake, so a slow bake that is overtaken is thrown away.
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  void _bake(Size size, double ratio) {
    if (_requestedSize == size && _requestedRatio == ratio) return;
    _requestedSize = size;
    _requestedRatio = ratio;
    final int generation = ++_generation;
    _render(size, ratio).then((ui.Image? image) {
      if (!mounted || generation != _generation || image == null) {
        image?.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _imageSize = size;
        _imageRatio = ratio;
      });
      widget.onBaked(image, size);
    });
  }

  /// Draws the vector exactly as `SvgPicture` with `BoxFit.cover` and
  /// `Alignment.topCenter` would, into a bitmap of [size] × [ratio] pixels.
  /// Null when it cannot, which leaves the vector on screen.
  static Future<ui.Image?> _render(Size size, double ratio) async {
    final int width = (size.width * ratio).round();
    final int height = (size.height * ratio).round();
    if (width <= 0 || height <= 0) return null;

    try {
      final PictureInfo info = await vg.loadPicture(
        const SvgAssetLoader(AppBackground._asset),
        null,
      );
      try {
        // The same arithmetic as the FittedBox inside SvgPicture.
        final FittedSizes fit = applyBoxFit(BoxFit.cover, info.size, size);
        final Rect source = Alignment.topCenter.inscribe(
          fit.source,
          Offset.zero & info.size,
        );
        final Rect destination = Alignment.topCenter.inscribe(
          fit.destination,
          Offset.zero & size,
        );

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas(recorder)
          ..scale(width / size.width, height / size.height)
          ..clipRect(Offset.zero & size)
          ..translate(destination.left, destination.top)
          ..scale(
            destination.width / source.width,
            destination.height / source.height,
          )
          ..translate(-source.left, -source.top)
          ..drawPicture(info.picture);
        final ui.Picture picture = recorder.endRecording();
        try {
          return await picture.toImage(width, height);
        } finally {
          picture.dispose();
        }
      } finally {
        info.picture.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        if (size.isFinite && !size.isEmpty) _bake(size, ratio);

        final ui.Image? image = _image;
        if (image != null && _imageSize == size && _imageRatio == ratio) {
          return RawImage(
            image: image,
            width: size.width,
            height: size.height,
            fit: BoxFit.fill,
          );
        }
        return SvgPicture.asset(
          AppBackground._asset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      },
    );
  }
}
