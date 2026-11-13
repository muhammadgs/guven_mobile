/// Glass that is blurred once, not on every frame.
///
/// A live `BackdropFilter` copies and blurs what is behind it on every frame
/// anything on screen moves. On a 1.5K, 120 Hz phone with a mid-range GPU
/// (HONOR X9b) that alone made the whole app stutter — with every blur
/// switched off it ran smoothly.
///
/// But what sits behind the glass in this app is almost always still: the
/// signed-in screens stand on one fixed background, and every panel, menu
/// and prompt opens over a screen that waits for it. So the blur is done
/// once, into a picture — [GlassBackdropImage] — and each glass surface
/// paints its own piece of that picture under its tint ([GlassBackdropPaint]).
/// Per frame that is one texture draw per surface.
///
/// Two sources fill the picture:
///
///  * `AppBackground` bakes its artwork blurred once, for every glass that
///    stands on it;
///  * [FrozenGlassBackdrop] photographs the screen — everything under
///    [GlassScreenBoundary] — the moment a panel, menu or prompt opens, and
///    blurs that photograph once.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'liquid_glass.dart';

/// How soft a photographed screen is, in logical pixels.
const double kFrozenBackdropSigma = 16;

/// Resolution of the photograph against the screen's logical size. Blurred,
/// half of it is indistinguishable from all of it, and a quarter the memory.
const double _kFrozenScale = 0.5;

/// Resolution of the unblurred photograph liquid glass bends at its rim.
const double _kFrozenSharpScale = 1;

/// A picture of what lies behind the glass, already blurred.
@immutable
class GlassBackdropImage {
  const GlassBackdropImage({
    required this.image,
    required this.size,
    required this.anchor,
    this.sharp,
    this.origin = Offset.zero,
  });

  final ui.Image image;

  /// The same picture unblurred, covering the same [size]; only liquid glass
  /// keeps one, to bend at its rim. Null when there is none.
  final ui.Image? sharp;

  /// The logical size [image] covers, from [origin].
  final Size size;

  /// Where the picture's top left lies in [anchor]'s coordinates — zero for
  /// a picture of the whole anchor, not for one of a region around it.
  final Offset origin;

  /// The render object the picture is of. Glass works out which piece of the
  /// picture is behind it from its own position relative to this.
  final RenderObject anchor;

  /// Releases [image] and [sharp].
  void dispose() {
    image.dispose();
    sharp?.dispose();
  }
}

/// Hands a backdrop picture to every glass surface below it.
///
/// The nearest scope wins, so a menu's photograph of the screen shadows the
/// background's picture for the glass inside the menu.
class GlassBackdropScope extends InheritedWidget {
  const GlassBackdropScope({
    super.key,
    required this.backdrop,
    required super.child,
  });

  /// Null until the picture is ready; glass draws its tint alone until then.
  final ValueListenable<GlassBackdropImage?> backdrop;

  static ValueListenable<GlassBackdropImage?>? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassBackdropScope>()
          ?.backdrop;

  @override
  bool updateShouldNotify(GlassBackdropScope oldWidget) =>
      oldWidget.backdrop != backdrop;
}

/// Draws [source] into a new [width]×[height] image, blurred by [sigma]
/// pixels of the new image.
///
/// Synchronous: the image is usable at once and the GPU renders it before
/// the first frame that draws it.
ui.Image blurImageSync(
  ui.Image source, {
  required int width,
  required int height,
  required double sigma,
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()
      ..filterQuality = FilterQuality.medium
      // Mirror, not clamp to transparent: the edges stay as bright as the
      // middle instead of fading out.
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.mirror,
      ),
  );
  final ui.Picture picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}

final GlobalKey _screenKey = GlobalKey(debugLabel: 'glass screen');

/// Marks the screen [FrozenGlassBackdrop] photographs: the navigator, with
/// every route in it.
class GlassScreenBoundary extends SingleChildRenderObjectWidget {
  GlassScreenBoundary({required Widget child})
    : super(key: _screenKey, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlassScreen();
}

class _RenderGlassScreen extends RenderRepaintBoundary {
  /// [region] of what this last drew — in its own coordinates — as an image
  /// [pixelRatio] times its logical size. Null before the first paint.
  ui.Image? regionImage(Rect region, double pixelRatio) {
    final ContainerLayer? layer = this.layer;
    if (layer is! OffsetLayer) return null;
    return layer.toImageSync(region, pixelRatio: pixelRatio);
  }
}

/// Keeps [child] out of [captureScreenRegion]'s photographs, while drawing it
/// on screen as usual.
///
/// For whatever sits over the region it photographs: a selection marker that
/// a lens is about to replace, or the lens itself.
class GlassCaptureHidden extends SingleChildRenderObjectWidget {
  const GlassCaptureHidden({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCaptureHidden();
}

class _RenderCaptureHidden extends RenderProxyBox {
  static final Set<_RenderCaptureHidden> _live = <_RenderCaptureHidden>{};

  // Its own layer, so a photograph can switch it off without a repaint.
  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _live.add(this);
  }

  @override
  void detach() {
    _live.remove(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    layer = context.pushOpacity(
      offset,
      255,
      super.paint,
      oldLayer: layer as OpacityLayer?,
    );
  }

  OpacityLayer? get _switch {
    final ContainerLayer? layer = this.layer;
    return layer is OpacityLayer ? layer : null;
  }

  /// Runs [photograph] with every hidden child's layer switched off.
  static T hidden<T>(T Function() photograph) {
    final List<OpacityLayer> off = <OpacityLayer>[
      for (final _RenderCaptureHidden box in _live)
        if (box._switch case final OpacityLayer layer) layer,
    ];
    for (final OpacityLayer layer in off) {
      layer.alpha = 0;
    }
    try {
      return photograph();
    } finally {
      for (final OpacityLayer layer in off) {
        layer.alpha = 255;
      }
    }
  }
}

/// Photographs the screen around [region] — in [anchor]'s coordinates — as
/// it was last drawn, unblurred, at [pixelRatio] pixels per logical pixel,
/// leaving out everything under a [GlassCaptureHidden].
///
/// For a lens that bends and magnifies what is under it: one photograph when
/// it appears, sharper than the screen by as much as it magnifies, instead of
/// a read of the live screen on every frame. Null when there is no
/// [GlassScreenBoundary] or it has not been drawn yet.
GlassBackdropImage? captureScreenRegion({
  required RenderBox anchor,
  required Rect region,
  required double pixelRatio,
}) {
  final RenderObject? screen = _screenKey.currentContext?.findRenderObject();
  if (screen is! _RenderGlassScreen ||
      !screen.hasSize ||
      !anchor.attached ||
      !anchor.hasSize) {
    return null;
  }
  try {
    final Matrix4 toScreen = anchor.getTransformTo(screen);
    final Matrix4? fromScreen = Matrix4.tryInvert(toScreen);
    if (fromScreen == null) return null;
    final Rect onScreen = MatrixUtils.transformRect(
      toScreen,
      region,
    ).intersect(Offset.zero & screen.size);
    if (onScreen.isEmpty) return null;
    final ui.Image? image = _RenderCaptureHidden.hidden(
      () => screen.regionImage(onScreen, pixelRatio),
    );
    if (image == null) return null;
    // Back into the anchor's coordinates; only a translation is supported.
    final Offset origin = MatrixUtils.transformPoint(
      fromScreen,
      onScreen.topLeft,
    );
    return GlassBackdropImage(
      image: image,
      size: onScreen.size,
      anchor: anchor,
      origin: origin,
    );
  } catch (_) {
    return null;
  }
}

/// Photographs the screen as it was last drawn and blurs it once. Null when
/// there is no [GlassScreenBoundary], or it has not been drawn yet.
GlassBackdropImage? captureScreenBackdrop() {
  final RenderObject? box = _screenKey.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary || !box.hasSize || box.size.isEmpty) {
    return null;
  }
  // Mid-frame the boundary may already be marked for a repaint it has not
  // had yet; debug builds assert on that. Release builds photograph the last
  // frame, which is exactly the screen as the user saw it.
  if (kDebugMode && box.debugNeedsPaint) return null;
  // Liquid glass bends the unblurred photograph at its rim, so it is taken
  // sharper and kept; the blurred one is made from it at the usual size.
  final bool keepSharp = LiquidGlassShader.ready;
  try {
    final ui.Image raw = box.toImageSync(
      pixelRatio: keepSharp ? _kFrozenSharpScale : _kFrozenScale,
    );
    try {
      final ui.Image blurred = blurImageSync(
        raw,
        width: keepSharp
            ? math.max(1, (box.size.width * _kFrozenScale).round())
            : raw.width,
        height: keepSharp
            ? math.max(1, (box.size.height * _kFrozenScale).round())
            : raw.height,
        sigma: kFrozenBackdropSigma * _kFrozenScale,
      );
      final GlassBackdropImage backdrop = GlassBackdropImage(
        image: blurred,
        sharp: keepSharp ? raw : null,
        size: box.size,
        anchor: box,
      );
      if (!keepSharp) raw.dispose();
      return backdrop;
    } catch (_) {
      raw.dispose();
      rethrow;
    }
  } catch (_) {
    return null;
  }
}

/// Gives the glass below it a blurred photograph of the screen it opened
/// over.
///
/// Without [animation] the photograph is taken when this widget first
/// builds — a route's page builds before the route has ever been drawn, so
/// it is the screen underneath. With [animation] it is taken as the
/// animation starts forward from shut, and dropped once it is shut again.
class FrozenGlassBackdrop extends StatefulWidget {
  const FrozenGlassBackdrop({super.key, this.animation, required this.child});

  final Animation<double>? animation;
  final Widget child;

  @override
  State<FrozenGlassBackdrop> createState() => _FrozenGlassBackdropState();
}

class _FrozenGlassBackdropState extends State<FrozenGlassBackdrop> {
  final ValueNotifier<GlassBackdropImage?> _backdrop =
      ValueNotifier<GlassBackdropImage?>(null);

  @override
  void initState() {
    super.initState();
    final Animation<double>? animation = widget.animation;
    if (animation == null) {
      _capture();
    } else {
      animation.addStatusListener(_onStatus);
      if (animation.status != AnimationStatus.dismissed) _capture();
    }
  }

  @override
  void didUpdateWidget(covariant FrozenGlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation?.removeStatusListener(_onStatus);
    widget.animation?.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    widget.animation?.removeStatusListener(_onStatus);
    _backdrop.value?.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _release();
    } else if (status == AnimationStatus.forward && _backdrop.value == null) {
      // Called from inside `forward()`, before the frame that first draws
      // anything of the opening: the screen is still as the user left it.
      _capture();
    }
  }

  void _capture() {
    final GlassBackdropImage? previous = _backdrop.value;
    _backdrop.value = captureScreenBackdrop();
    previous?.dispose();
  }

  void _release() {
    final GlassBackdropImage? previous = _backdrop.value;
    _backdrop.value = null;
    previous?.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GlassBackdropScope(backdrop: _backdrop, child: widget.child);
}

/// What liquid glass with no scope above it bends: nothing.
final ValueListenable<GlassBackdropImage?> _noBackdrop =
    ValueNotifier<GlassBackdropImage?>(null);

/// Paints the piece of the nearest [GlassBackdropScope]'s picture that lies
/// behind this widget, then [child] over it.
///
/// With [liquid], the piece is drawn through the liquid glass shader instead
/// — bent at the edge, tinted, with its rim — once that shader has loaded.
///
/// Where there is no scope — the screens over the login video — only
/// [child] is drawn, or for [liquid] the tint and rim alone.
class GlassBackdropPaint extends StatelessWidget {
  const GlassBackdropPaint({
    super.key,
    this.amount = 1,
    this.liquid,
    this.child,
  });

  /// Opacity of the picture: 0 none, 1 all of it. Scrims fade it in with
  /// their own progress, which reads as the screen going soft. Liquid glass
  /// fades by its own [LiquidGlassSpec.fade] instead.
  final double amount;

  /// Draws this as liquid glass; null for the plain picture.
  final LiquidGlassSpec? liquid;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final LiquidGlassSpec? liquid = LiquidGlassShader.ready
        ? this.liquid
        : null;
    final ValueListenable<GlassBackdropImage?>? scoped =
        GlassBackdropScope.maybeOf(context);
    if (scoped == null && liquid == null) {
      return child ?? const SizedBox.shrink();
    }
    final ValueListenable<GlassBackdropImage?> backdrop = scoped ?? _noBackdrop;

    // Inside a list the glass slides over a picture that stays put, so every
    // scroll has to repaint it. A list item is its own repaint boundary and
    // would otherwise be moved without being repainted.
    final List<Listenable> repaint = <Listenable>[backdrop];
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      repaint.add(scrollable.position);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    return _BackdropPaint(
      backdrop: backdrop,
      amount: amount.clamp(0.0, 1.0),
      repaint: Listenable.merge(repaint),
      liquid: liquid,
      devicePixelRatio: liquid == null
          ? 1
          : MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      child: child,
    );
  }
}

class _BackdropPaint extends SingleChildRenderObjectWidget {
  const _BackdropPaint({
    required this.backdrop,
    required this.amount,
    required this.repaint,
    required this.liquid,
    required this.devicePixelRatio,
    super.child,
  });

  final ValueListenable<GlassBackdropImage?> backdrop;
  final double amount;
  final Listenable repaint;
  final LiquidGlassSpec? liquid;
  final double devicePixelRatio;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop._(
        backdrop: backdrop,
        amount: amount,
        repaint: repaint,
        liquid: liquid,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..backdrop = backdrop
      ..amount = amount
      ..repaint = repaint
      ..liquid = liquid
      ..devicePixelRatio = devicePixelRatio;
  }
}

/// The render side of [GlassBackdropPaint].
class RenderGlassBackdrop extends RenderProxyBox {
  RenderGlassBackdrop._({
    required this._backdrop,
    required this._amount,
    required this._repaint,
    required this._liquid,
    required this._devicePixelRatio,
  });

  LiquidGlassSpec? _liquid;
  set liquid(LiquidGlassSpec? value) {
    if (value == _liquid) return;
    _liquid = value;
    markNeedsPaint();
  }

  /// Whether this draws liquid glass rather than the plain picture.
  @visibleForTesting
  bool get debugIsLiquid => _liquid != null;

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// Kept across frames; only its uniforms change.
  ui.FragmentShader? _shader;

  ValueListenable<GlassBackdropImage?> _backdrop;
  set backdrop(ValueListenable<GlassBackdropImage?> value) {
    if (value == _backdrop) return;
    _backdrop = value;
    markNeedsPaint();
  }

  double _amount;
  set amount(double value) {
    if (value == _amount) return;
    _amount = value;
    markNeedsPaint();
  }

  Listenable _repaint;
  set repaint(Listenable value) {
    if (value == _repaint) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  /// Where this was, in its picture's coordinates, when it last drew it.
  Rect? _painted;

  /// The piece of the picture this last drew, in the picture's logical
  /// coordinates; null when it drew none.
  @visibleForTesting
  Rect? get debugPaintedRect => _painted;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
    _MoveWatch.add(this);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    _MoveWatch.remove(this);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  Rect? _rectIn(GlassBackdropImage backdrop) {
    if (!hasSize || !backdrop.anchor.attached) return null;
    try {
      return MatrixUtils.transformRect(
        getTransformTo(backdrop.anchor),
        Offset.zero & size,
      ).shift(-backdrop.origin);
    } catch (_) {
      return null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _painted = null;
    final GlassBackdropImage? backdrop = _backdrop.value;
    final LiquidGlassSpec? liquid = _liquid;
    if (liquid != null && hasSize && !size.isEmpty) {
      final ui.FragmentShader? shader = _shader ??= LiquidGlassShader.create();
      if (shader != null) {
        _paintLiquid(context.canvas, offset, shader, liquid, backdrop);
        super.paint(context, offset);
        return;
      }
    }
    if (backdrop != null && _amount > 0) {
      final Rect? mine = _rectIn(backdrop);
      if (mine != null && !mine.isEmpty) {
        _painted = mine;
        final double sx = backdrop.image.width / backdrop.size.width;
        final double sy = backdrop.image.height / backdrop.size.height;
        context.canvas.drawImageRect(
          backdrop.image,
          Rect.fromLTRB(
            mine.left * sx,
            mine.top * sy,
            mine.right * sx,
            mine.bottom * sy,
          ),
          offset & size,
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = Color.fromRGBO(0, 0, 0, _amount),
        );
      }
    }
    super.paint(context, offset);
  }

  void _paintLiquid(
    Canvas canvas,
    Offset offset,
    ui.FragmentShader shader,
    LiquidGlassSpec liquid,
    GlassBackdropImage? backdrop,
  ) {
    final Rect? mine = backdrop == null ? null : _rectIn(backdrop);
    final bool bends = mine != null && !mine.isEmpty;
    if (bends) _painted = mine;
    // A surface scaled on its way in covers fewer pixels per unit.
    final double scale = bends ? mine.width / size.width : 1;
    LiquidGlassShader.paint(
      canvas,
      shader,
      offset: offset,
      size: size,
      pxPerUnit: _devicePixelRatio * scale,
      spec: liquid,
      picture: bends ? backdrop!.image : null,
      sharp: bends ? backdrop!.sharp : null,
      pictureSize: bends ? backdrop!.size : null,
      pictureRect: mine,
    );
  }

  /// Repaints if this has moved against its picture since it last drew it
  /// without being asked to repaint — a repaint boundary above it shifted as
  /// a whole. Runs after every frame, so such a move is one frame late at
  /// most.
  void _checkMoved() {
    final Rect? painted = _painted;
    final GlassBackdropImage? backdrop = _backdrop.value;
    if (painted == null || backdrop == null) return;
    final Rect? now = _rectIn(backdrop);
    if (now == null) return;
    if ((now.left - painted.left).abs() > 0.5 ||
        (now.top - painted.top).abs() > 0.5 ||
        (now.width - painted.width).abs() > 0.5 ||
        (now.height - painted.height).abs() > 0.5) {
      markNeedsPaint();
    }
  }
}

/// Every attached [RenderGlassBackdrop], checked after each frame.
abstract final class _MoveWatch {
  static final Set<RenderGlassBackdrop> _live = <RenderGlassBackdrop>{};
  static bool _installed = false;

  static void add(RenderGlassBackdrop glass) {
    _live.add(glass);
    if (_installed) return;
    _installed = true;
    // A persistent callback runs on every frame; the check itself has to
    // wait for the frame's post-frame phase, where a repaint it asks for
    // still schedules the next frame.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_live.isEmpty) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final RenderGlassBackdrop glass in _live.toList()) {
          if (glass.attached) glass._checkMoved();
        }
      });
    });
  }

  static void remove(RenderGlassBackdrop glass) => _live.remove(glass);
}
