import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart'
    show IndicatorPhysics;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

import '../../../../shared/motion/lens_rim.dart';
import '../../../../shared/motion/spring.dart';
import '../../../home/presentation/widgets/home_glass.dart';

/// Güvən's compact bottom bar with a restrained, refractive moving lens.
///
/// `LGBottomBar` hard-codes a 14px indicator expansion. This app-owned shell
/// keeps the package's drag resistance but owns the visual layer, allowing
/// the moving lens to follow a finger and fit each label's measured width.
///
/// Motion is a small spring system rather than a curve. A finger holds the
/// lens directly — it never lags behind the thing dragging it — while three
/// springs run off one ticker beside it: the travel back to a cell once the
/// finger is gone, the sideways deformation, and the vertical pull. The last
/// two are fed straight into `RawLiquidStretch`, the same squash-and-stretch
/// engine the package's own `LiquidStretch` wraps, so the capsule leads with
/// its front edge while moving and stands up when it is pulled off its rail.
/// Driving it from here rather than from `LiquidStretch`'s own listener is
/// what lets a *tap* deform the capsule too, and not only a drag.
class GuvenGlassBottomBar extends StatefulWidget {
  const GuvenGlassBottomBar({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
    required this.iconSize,
    required this.textStyle,
  }) : assert(labels.length == icons.length),
       assert(labels.length > 1);

  final List<String> labels;

  /// One SVG asset path per cell, drawn tinted to [kGlassInk] — the artwork's
  /// own fills are painted over, so a black-filled export and a `currentColor`
  /// one look the same here.
  final List<String> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final double iconSize;
  final TextStyle textStyle;

  @override
  State<GuvenGlassBottomBar> createState() => _GuvenGlassBottomBarState();
}

/// The travel spring, at ζ ≈ 0.71: the lens overshoots its cell and rocks back
/// instead of gliding to a stop.
const double _kTravelStiffness = 265;
const double _kTravelDamping = 23;

/// The sideways deformation. Bouncy on purpose — it is what recoils when a
/// drag stops dead.
const double _kSquashStiffness = 500;
const double _kSquashDamping = 30;

/// The vertical pull on its way home, at ζ ≈ 0.44, so letting go of a lens
/// that has been dragged upwards squashes it flat before it recovers.
const double _kPullReturnStiffness = 330;
const double _kPullReturnDamping = 16;

/// The swell from flat marker to lens, at ζ ≈ 0.72 so it arrives with a little
/// overshoot rather than easing in.
const double _kLensStiffness = 520;
const double _kLensDamping = 33;

/// How far the capsule grows on each side when it becomes a lens, in pixels.
/// The bar insets it by 7, so this all but fills the bar's height.
const double _kSwell = 10;

/// Cells of deformation per cell of finger travel, dumped into the squash
/// spring on every drag update. A fast drag outruns the spring's recovery and
/// the capsule stays stretched; a slow one barely marks it.
const double _kGrabSquash = 0.30;

/// How far ahead of itself a freely travelling lens runs, in seconds of
/// travel, before the soft limit starts holding it back.
const double _kTravelSquash = 0.070;

/// Neither deformation ever passes these, in pixels. The pull is the smaller
/// of the two on purpose: `RawLiquidStretch` translates by the offset as well
/// as scaling by it, so every pixel here lifts the capsule off its rail by
/// rather more than a pixel.
const double _kSquashLimit = 50;
const double _kPullLimit = 5;

/// Cells per second the lens may carry out of a fling. Left unclamped, a flick
/// throws it most of a cell past its target.
const double _kFlingLimit = 6;

/// How far the lens may sit from the finger that grabbed it, in cells. A grab
/// from further away still pulls it over — it just has to travel.
const double _kGrabReach = 0.6;

/// Cells of overdrag allowed past either end of the bar.
const double _kOverdrag = 0.35;

class _GuvenGlassBottomBarState extends State<GuvenGlassBottomBar>
    with SingleTickerProviderStateMixin {
  /// Where the lens is, in cells.
  late final Spring _travel = Spring(
    stiffness: _kTravelStiffness,
    damping: _kTravelDamping,
    value: widget.selectedIndex.toDouble(),
  );

  /// How far the lens is stretched along the bar, in cells.
  final Spring _squash = Spring(
    stiffness: _kSquashStiffness,
    damping: _kSquashDamping,
  );

  /// How far a finger has dragged it off its rail, in pixels.
  final Spring _pull = Spring(
    stiffness: _kPullReturnStiffness,
    damping: _kPullReturnDamping,
  );

  /// 0 flat marker, 1 full lens. Held up only while a finger is on the bar.
  final Spring _lens = Spring(
    stiffness: _kLensStiffness,
    damping: _kLensDamping,
  );

  /// Created eagerly rather than on first use: a bar that is disposed without
  /// ever having been touched would otherwise build its ticker from inside
  /// `dispose`, which reaches for an ancestor that is already gone.
  late final Ticker _ticker;

  /// Bumped whenever the lens needs redrawing. Only the indicator listens, so
  /// the labels are built once and handed down as a cached child.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;
  bool _pressed = false;
  bool _grabbed = false;
  double _grabOffset = 0;
  double _pullRaw = 0;

  /// Whether a finger is on the bar. The only thing that makes glass.
  bool get _active => _pressed || _grabbed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant GuvenGlassBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex &&
        oldWidget.labels.length == widget.labels.length) {
      return;
    }

    final double target = widget.selectedIndex.toDouble();
    // Drag-end already aimed the spring here before notifying the shell, so
    // the parent rebuild must not restart the settle from scratch.
    if (_travel.target == target) return;

    _travel.target = target;
    _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double radius = widget.height / 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: kGlassLift,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppGlassSurface(
            style: glassAtRadius(kNavBarGlass, radius),
            cornerRadius: radius,
            child: const SizedBox.expand(),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double barWidth = constraints.maxWidth;
              final double slotWidth = barWidth / widget.labels.length;
              final List<double> indicatorWidths = <double>[
                for (final String label in widget.labels)
                  _measureIndicatorWidth(context, label, slotWidth, barWidth),
              ];

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) =>
                    _onTapAt(details.localPosition.dx, barWidth),
                // Pan rather than a horizontal drag: the vertical component
                // never moves the selection, it only feeds the pull that makes
                // the capsule stand up and squash when it is let go.
                onPanDown: _onPanDown,
                onPanStart: (DragStartDetails details) =>
                    _onPanStart(details, barWidth),
                onPanUpdate: (DragUpdateDetails details) =>
                    _onPanUpdate(details, slotWidth, barWidth),
                onPanEnd: (DragEndDetails details) =>
                    _onPanEnd(details, slotWidth, barWidth),
                onPanCancel: _onPanCancel,
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (BuildContext context, Widget? child) {
                    final double last = (widget.labels.length - 1).toDouble();
                    final double index = _travel.value.clamp(0.0, last);
                    final double indicatorWidth = _widthAtIndex(
                      indicatorWidths,
                      index,
                    );
                    final double desiredCenter = slotWidth * (index + 0.5);
                    const double edgeInset = 3;
                    final double left = (desiredCenter - indicatorWidth / 2)
                        .clamp(
                          edgeInset,
                          barWidth - indicatorWidth - edgeInset,
                        );

                    final double lens = _lens.value;
                    final double swell = _kSwell * lens;
                    // Leading along the rail, standing up along the pull: one
                    // offset, and the renderer turns it into volume-preserving
                    // squash and stretch.
                    final Offset stretch = Offset(
                      soften(_squash.value * slotWidth, _kSquashLimit),
                      _pull.value,
                    );

                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // Parked, the marker is a plain fill and it sits
                        // *under* the glyphs, so they stay black on white.
                        if (lens < 0.999)
                          _RestingPill(
                            left: left,
                            width: indicatorWidth,
                            radius: radius - 7,
                            opacity: 1 - lens,
                            stretchPixels: stretch,
                          ),
                        IgnorePointer(child: child!),
                        // The lens goes over them instead. A lens only shows
                        // what it has to bend, and over this app's near-flat
                        // backdrop the glyphs and labels are the only real
                        // content in reach — putting them behind it is what
                        // makes the rim distort something visible, the way an
                        // iOS tab bar's does. It exists only while a finger
                        // does, so a parked bar runs no shader at all.
                        if (_active || lens > 0.001)
                          _MovingLens(
                            left: (left - swell).clamp(
                              0.0,
                              math.max(
                                0,
                                barWidth - indicatorWidth - 2 * swell,
                              ),
                            ),
                            width: indicatorWidth + 2 * swell,
                            inset: 7 - swell,
                            radius: radius - 7 + swell,
                            lens: lens.clamp(0.0, 1.0),
                            stretchPixels: stretch,
                          ),
                      ],
                    );
                  },
                  child: Row(
                    children: <Widget>[
                      for (int index = 0; index < widget.labels.length; index++)
                        Expanded(child: _tab(index)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tab(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SvgPicture.asset(
          widget.icons[index],
          width: widget.iconSize,
          height: widget.iconSize,
          // The exports are not all square — `contain` letterboxes them inside
          // the square box so every cell's glyph keeps its own proportions and
          // still sits on one baseline with the others.
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
        ),
        const SizedBox(height: 3),
        // Five cells share the bar's width, so on a 360pt phone each one is
        // barely wider than the longest Azerbaijani label. An ellipsis there
        // truncates a word — `Əməkdaşl…` — for the sake of two or three
        // pixels; scaling the label down by those same pixels keeps it whole
        // and is invisible next to its neighbours.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.labels[index],
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: widget.textStyle.copyWith(color: kGlassInk),
          ),
        ),
      ],
    );
  }

  double _measureIndicatorWidth(
    BuildContext context,
    String label,
    double slotWidth,
    double barWidth,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: widget.textStyle),
      textDirection: Directionality.of(context),
      // Measured at the same scale it is drawn at, now that the app bounds the
      // system font scale centrally instead of pinning this label to 1.
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // The label is drawn inside a `FittedBox`, so however large the font
    // scale it is never wider than its cell. The lens hugs what is actually
    // drawn rather than the width the text would have wanted.
    final double drawnWidth = math.min(painter.width, slotWidth);
    final double contentWidth = math.max(drawnWidth, widget.iconSize);
    final double minimum = widget.iconSize + 20;
    final double maximum = math.min(slotWidth * 1.48, barWidth - 6);
    return (contentWidth + 20).clamp(minimum, maximum);
  }

  double _widthAtIndex(List<double> widths, double index) {
    final int lower = index.floor().clamp(0, widths.length - 1);
    final int upper = index.ceil().clamp(0, widths.length - 1);
    return widths[lower] + (widths[upper] - widths[lower]) * (index - lower);
  }

  double _indexAtPosition(double dx, double barWidth) {
    final double indicatorFraction = 1 / widget.labels.length;
    final double raw =
        (dx / barWidth - indicatorFraction / 2) / (1 - indicatorFraction);
    final double resisted = IndicatorPhysics.applyRubberBandResistance(raw);
    return resisted * (widget.labels.length - 1);
  }

  // ---------------------------------------------------------------- gestures

  void _onTapAt(double dx, double barWidth) {
    final int next = (dx / (barWidth / widget.labels.length)).floor().clamp(
      0,
      widget.labels.length - 1,
    );
    if (next != widget.selectedIndex) widget.onSelected(next);
  }

  /// Fires on every touch, a tap included — which is why it only lights the
  /// lens up. Moving it from here is what used to teleport the capsule under a
  /// finger that had merely tapped a distant cell.
  void _onPanDown(DragDownDetails details) {
    _pressed = true;
    _pullRaw = 0;
    _wake();
  }

  void _onPanStart(DragStartDetails details, double barWidth) {
    final double finger = _indexAtPosition(details.localPosition.dx, barWidth);
    // Grab the lens where it stands: it keeps its offset to the finger rather
    // than jumping to it, and a grab from beyond [_kGrabReach] drags it over
    // the remaining distance instead of snapping.
    _grabOffset = (_travel.value - finger).clamp(-_kGrabReach, _kGrabReach);
    _grabbed = true;
    _pullRaw = 0;
    // Whatever the last flight left aimed at, a finger now owns the shape.
    _squash.target = 0;
    _holdAt(finger);
    _wake();
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    double slotWidth,
    double barWidth,
  ) {
    _holdAt(_indexAtPosition(details.localPosition.dx, barWidth));
    // Every pixel of drag shoves the capsule further out of shape, and the
    // squash spring spends the gaps between updates pulling it back. Outrun
    // that recovery and it stays stretched for as long as the finger moves.
    _squash.value += details.delta.dx / slotWidth * _kGrabSquash;
    _pullRaw += details.delta.dy;
    _pull.hold(soften(_pullRaw, _kPullLimit));
    _wake();
  }

  void _onPanEnd(DragEndDetails details, double slotWidth, double barWidth) {
    final int last = widget.labels.length - 1;
    final double landing = _travel.target.clamp(0.0, last.toDouble());
    final double projected =
        landing + details.velocity.pixelsPerSecond.dx / barWidth * 0.15;
    final int next = projected.round().clamp(0, last);
    _release(next);
    // Hand the fling to the travel spring so the settle continues the throw
    // rather than starting a new movement from a standstill.
    _travel.velocity = (details.velocity.pixelsPerSecond.dx / slotWidth).clamp(
      -_kFlingLimit,
      _kFlingLimit,
    );
    if (next != widget.selectedIndex) widget.onSelected(next);
  }

  void _onPanCancel() {
    // A tap loses the pan arena here. It never moved the lens, so its target
    // is left alone for the tap handler to set.
    if (!_grabbed) {
      _pressed = false;
      _wake();
      return;
    }
    _release(widget.selectedIndex);
  }

  /// Pins the lens to the finger. A dragged capsule sits exactly where the
  /// finger is; what deforms is its shape, not its position.
  void _holdAt(double finger) {
    final double last = (widget.labels.length - 1).toDouble();
    _travel.hold(
      (finger + _grabOffset).clamp(-_kOverdrag, last + _kOverdrag),
    );
  }

  void _release(int target) {
    _grabbed = false;
    _pressed = false;
    _pullRaw = 0;
    _travel.target = target.toDouble();
    _pull.target = 0;
    _wake();
  }

  // ----------------------------------------------------------------- physics

  /// Redraws the lens, and starts the ticker if the springs have work left.
  void _wake() {
    _frame.value++;
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond)
            .clamp(0.0, 0.1);
    _lastTick = elapsed;

    if (dt > 0) {
      if (!_grabbed) {
        _travel.advance(dt);
        _pull.advance(dt);
        // Off the finger, the deformation follows the travel: the faster the
        // lens moves, the further its leading edge runs ahead of it.
        _squash.target = _travel.velocity * _kTravelSquash;
      }
      _squash.advance(dt);
      // The glass is a touch response, not a movement one: it swells in under
      // the finger and drains away the moment the finger is gone, whether the
      // capsule is still travelling or not.
      _lens.target = _active ? 1 : 0;
      _lens.advance(dt);
      _frame.value++;
    } else {
      // The first tick after a start carries no elapsed time to integrate,
      // and the rest check below would read that as "nothing to do".
      return;
    }

    // Every gesture wakes the ticker again, so parking it the moment the
    // springs are still is safe even with a finger resting on the bar.
    if (!_grabbed &&
        _travel.isAtRest(0.0008) &&
        _squash.isAtRest(0.001) &&
        _pull.isAtRest(0.01) &&
        _lens.isAtRest(0.001)) {
      // Land on exact values rather than near them: a resting lens has to
      // report no stretch at all, or it sits permanently a hair out of shape.
      _travel.snap();
      _squash
        ..target = 0
        ..snap();
      _pull.snap();
      _lens.snap();
      _ticker.stop();
      _frame.value++;
    }
  }
}

/// The selected cell while nothing is being touched: a plain fill, no shader.
class _RestingPill extends StatelessWidget {
  const _RestingPill({
    required this.left,
    required this.width,
    required this.radius,
    required this.opacity,
    required this.stretchPixels,
  });

  final double left;
  final double width;
  final double radius;
  final double opacity;
  final Offset stretchPixels;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey<String>('nav-selection-pill'),
      left: left,
      top: 7,
      bottom: 7,
      width: width,
      child: renderer.RawLiquidStretch(
        stretchPixels: stretchPixels,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: kNavIndicatorRestFill,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The same marker under a finger: swollen, refracting, and over the glyphs.
class _MovingLens extends StatelessWidget {
  const _MovingLens({
    required this.left,
    required this.width,
    required this.inset,
    required this.radius,
    required this.lens,
    required this.stretchPixels,
  });

  final double left;
  final double width;

  /// Distance from the bar's top and bottom edges, shrinking as it swells.
  final double inset;
  final double radius;

  /// 0 not there at all, 1 fully formed.
  final double lens;
  final Offset stretchPixels;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: inset,
      bottom: inset,
      width: width,
      child: renderer.RawLiquidStretch(
        stretchPixels: stretchPixels,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            AppGlassSurface(
              key: const ValueKey<String>('nav-selection-glass'),
              // `liquid_glass_easy` rather than the renderer everything else
              // here uses, for its optical border — see [kNavIndicatorGlass].
              // Nothing about the geometry or the motion changes; only who
              // draws the glass inside the capsule.
              backend: AppGlassBackend.easy,
              style: kNavIndicatorGlass.copyWith(cornerRadius: radius),
              cornerRadius: radius,
              // Swells in with the touch rather than switching on: the
              // backend spreads it across every optical property it has, so
              // a capsule that has not been asked for yet costs nothing.
              fade: lens,
              // A bloom that tracks the finger across the capsule, so the
              // side being touched is the side that lights up.
              glowColor: Color.fromRGBO(255, 255, 255, 0.2 * lens),
              glowRadius: 0.9,
              child: const SizedBox.expand(),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: LensRimPainter(radius: radius, lens: lens),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
