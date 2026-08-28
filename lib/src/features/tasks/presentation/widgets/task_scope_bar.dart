import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_liquid_glass_plus/flutter_liquid_glass.dart'
    show IndicatorPhysics;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as renderer;

import '../../../../shared/motion/lens_rim.dart';
import '../../../../shared/motion/spring.dart';
import '../../domain/task_scope.dart';
import 'task_glass.dart';

/// The five-cell bar over the task list.
///
/// The same object as the bottom nav bar, minus one layer: there the bar
/// *and* its marker are glass, here the bar is flat grey and only the marker
/// refracts. Everything about how the marker behaves is the nav bar's — it is
/// parked as a plain fill, a finger swells it into a lens, it can be dragged,
/// flung and overdragged, and it leads with its front edge while it travels —
/// and both bars run off the same [Spring] and the same [LensRimPainter], so
/// the two cannot drift apart.
///
/// The one real difference is the rail. The nav bar divides its width into
/// five equal cells; here the cells are as wide as their own labels need, so
/// `Partniyor` gets more room than `Arxiv` and the marker hugs whatever it is
/// sitting on. That turns every position calculation from a division into a
/// lookup along measured cell centres.
class TaskScopeBar extends StatefulWidget {
  const TaskScopeBar({
    super.key,
    required this.scopes,
    required this.selected,
    required this.onSelected,
    required this.height,
    required this.iconSize,
    required this.textStyle,
  }) : assert(scopes.length > 1);

  final List<TaskScope> scopes;
  final TaskScope selected;
  final ValueChanged<TaskScope> onSelected;
  final double height;
  final double iconSize;
  final TextStyle textStyle;

  @override
  State<TaskScopeBar> createState() => _TaskScopeBarState();
}

/// The travel spring, at ζ ≈ 0.71: the marker overshoots its cell and rocks
/// back instead of gliding to a stop.
const double _kTravelStiffness = 265;
const double _kTravelDamping = 23;

/// The sideways deformation. Bouncy on purpose — it is what recoils when a
/// drag stops dead.
const double _kSquashStiffness = 500;
const double _kSquashDamping = 30;

/// The vertical pull on its way home, at ζ ≈ 0.44.
const double _kPullReturnStiffness = 330;
const double _kPullReturnDamping = 16;

/// The swell from flat marker to lens.
const double _kLensStiffness = 520;
const double _kLensDamping = 33;

/// Distance from the bar's top and bottom edges to the parked marker.
const double _kMarkerInset = 4;

/// How far the marker grows on each side when it becomes a lens. Set to the
/// inset, so a held marker all but fills the bar's height — the same
/// relationship the nav bar's 7 and 10 have.
const double _kSwell = 4;

/// Cells of deformation per cell of finger travel.
const double _kGrabSquash = 0.30;

/// How far ahead of itself a freely travelling marker runs, in seconds.
const double _kTravelSquash = 0.070;

/// Neither deformation ever passes these, in pixels.
const double _kSquashLimit = 34;
const double _kPullLimit = 4;

/// Cells per second the marker may carry out of a fling.
const double _kFlingLimit = 6;

/// How far the marker may sit from the finger that grabbed it, in cells.
const double _kGrabReach = 0.6;

/// Cells of overdrag allowed past either end.
const double _kOverdrag = 0.3;

/// Space either side of a cell's icon-and-label pair.
const double _kCellPadding = 9;

/// Gap between a cell's icon and its label.
const double _kCellGap = 6;

/// How much wider than its content the marker sits.
const double _kMarkerPadding = 16;

class _TaskScopeBarState extends State<TaskScopeBar>
    with SingleTickerProviderStateMixin {
  late final Spring _travel = Spring(
    stiffness: _kTravelStiffness,
    damping: _kTravelDamping,
    value: _selectedIndex.toDouble(),
  );

  final Spring _squash = Spring(
    stiffness: _kSquashStiffness,
    damping: _kSquashDamping,
  );

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

  /// Bumped whenever the marker needs redrawing. Only the marker listens, so
  /// the cells are built once and handed down as a cached child.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;
  bool _pressed = false;
  bool _grabbed = false;
  double _grabOffset = 0;
  double _pullRaw = 0;

  /// The rail: one entry per cell, rebuilt whenever the bar's width or the
  /// text scale changes.
  _Rail? _rail;

  bool get _active => _pressed || _grabbed;

  int get _selectedIndex => widget.scopes.indexOf(widget.selected);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant TaskScopeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textStyle != widget.textStyle ||
        oldWidget.iconSize != widget.iconSize) {
      _rail = null;
    }
    if (oldWidget.selected == widget.selected) return;

    final double target = _selectedIndex.toDouble();
    // Drag-end already aimed the spring here before notifying the screen, so
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
        color: kScopeBarFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kScopeBarBorder, width: 1),
      ),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final _Rail rail = _railFor(context, constraints.maxWidth);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) =>
                  _onTapAt(details.localPosition.dx, rail),
              // Pan rather than a horizontal drag: the vertical component
              // never moves the selection, it only feeds the pull that makes
              // the marker stand up and squash when it is let go.
              onPanDown: _onPanDown,
              onPanStart: (DragStartDetails details) =>
                  _onPanStart(details, rail),
              onPanUpdate: (DragUpdateDetails details) =>
                  _onPanUpdate(details, rail),
              onPanEnd: (DragEndDetails details) => _onPanEnd(details, rail),
              onPanCancel: _onPanCancel,
              child: AnimatedBuilder(
                animation: _frame,
                builder: (BuildContext context, Widget? child) {
                  final double last = (widget.scopes.length - 1).toDouble();
                  final double index = _travel.value.clamp(0.0, last);
                  final double markerWidth = rail.markerWidthAt(index);
                  final double centre = rail.centreAt(index);
                  final double left = (centre - markerWidth / 2).clamp(
                    _kMarkerInset,
                    math.max(
                      _kMarkerInset,
                      rail.width - markerWidth - _kMarkerInset,
                    ),
                  );

                  final double lens = _lens.value.clamp(0.0, 1.0);
                  final double swell = _kSwell * lens;
                  final double cell = rail.width / widget.scopes.length;
                  // Leading along the rail, standing up along the pull: one
                  // offset, and the renderer turns it into volume-preserving
                  // squash and stretch.
                  final Offset stretch = Offset(
                    soften(_squash.value * cell, _kSquashLimit),
                    _pull.value,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // Parked, the marker is a plain fill and it sits *under*
                      // the glyphs, so they stay black on white.
                      if (lens < 0.999)
                        _RestingMarker(
                          left: left,
                          width: markerWidth,
                          radius: radius - _kMarkerInset,
                          opacity: 1 - lens,
                          stretchPixels: stretch,
                        ),
                      IgnorePointer(child: child!),
                      // The lens goes over them instead: a lens only shows
                      // what it has to bend, and the glyphs are the only real
                      // content in reach on this pale bar.
                      if (_active || lens > 0.001)
                        _MovingMarkerLens(
                          left: (left - swell).clamp(
                            0.0,
                            math.max(
                              0,
                              rail.width - markerWidth - 2 * swell,
                            ),
                          ),
                          width: markerWidth + 2 * swell,
                          inset: _kMarkerInset - swell,
                          radius: radius - _kMarkerInset + swell,
                          lens: lens,
                          stretchPixels: stretch,
                        ),
                    ],
                  );
                },
                child: _cells(rail),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The cells themselves, laid out at the rail's measured widths.
  Widget _cells(_Rail rail) {
    return Row(
      children: <Widget>[
        for (int index = 0; index < widget.scopes.length; index++)
          SizedBox(width: rail.widths[index], child: _cell(index)),
      ],
    );
  }

  Widget _cell(int index) {
    final TaskScope scope = widget.scopes[index];
    final bool selected = scope == widget.selected;
    // The ink follows the *settled* selection rather than the travelling
    // marker: a label that darkened as the lens crossed it would flicker
    // through every cell of a drag.
    final Color ink = selected ? kGlassInk : kScopeInkMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kCellPadding),
        // However large the system font scale, a cell never grows past the
        // width the rail measured for it — the label scales down instead of
        // ellipsising a word.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SvgPicture.asset(
                scope.icon,
                width: widget.iconSize,
                height: widget.iconSize,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              ),
              const SizedBox(width: _kCellGap),
              Text(
                scope.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: widget.textStyle.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- rail

  _Rail _railFor(BuildContext context, double width) {
    final _Rail? cached = _rail;
    if (cached != null && (cached.width - width).abs() < 0.5) return cached;

    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final List<double> contents = <double>[
      for (final TaskScope scope in widget.scopes)
        widget.iconSize +
            _kCellGap +
            _measureLabel(context, scope.label, scaler),
    ];
    final _Rail rail = _Rail.pack(
      width: width,
      contents: contents,
      padding: _kCellPadding,
      markerPadding: _kMarkerPadding,
    );
    _rail = rail;
    return rail;
  }

  double _measureLabel(BuildContext context, String label, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: widget.textStyle),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  // ---------------------------------------------------------------- gestures

  void _onTapAt(double dx, _Rail rail) {
    final int next = rail.cellAt(dx);
    if (widget.scopes[next] != widget.selected) {
      widget.onSelected(widget.scopes[next]);
    }
  }

  /// Fires on every touch, a tap included — which is why it only lights the
  /// lens up. Moving the marker from here is what would teleport it under a
  /// finger that had merely tapped a distant cell.
  void _onPanDown(DragDownDetails details) {
    _pressed = true;
    _pullRaw = 0;
    _wake();
  }

  void _onPanStart(DragStartDetails details, _Rail rail) {
    final double finger = _indexAt(details.localPosition.dx, rail);
    // Grab the marker where it stands: it keeps its offset to the finger
    // rather than jumping to it, and a grab from beyond [_kGrabReach] drags it
    // over the remaining distance instead of snapping.
    _grabOffset = (_travel.value - finger).clamp(-_kGrabReach, _kGrabReach);
    _grabbed = true;
    _pullRaw = 0;
    _squash.target = 0;
    _holdAt(finger);
    _wake();
  }

  void _onPanUpdate(DragUpdateDetails details, _Rail rail) {
    _holdAt(_indexAt(details.localPosition.dx, rail));
    // Every pixel of drag shoves the marker further out of shape, and the
    // squash spring spends the gaps between updates pulling it back.
    _squash.value +=
        details.delta.dx / (rail.width / widget.scopes.length) * _kGrabSquash;
    _pullRaw += details.delta.dy;
    _pull.hold(soften(_pullRaw, _kPullLimit));
    _wake();
  }

  void _onPanEnd(DragEndDetails details, _Rail rail) {
    final int last = widget.scopes.length - 1;
    final double landing = _travel.target.clamp(0.0, last.toDouble());
    final double projected =
        landing + details.velocity.pixelsPerSecond.dx / rail.width * 0.15;
    final int next = projected.round().clamp(0, last);
    _release(next);
    // Hand the fling to the travel spring so the settle continues the throw
    // rather than starting a new movement from a standstill.
    _travel.velocity =
        (details.velocity.pixelsPerSecond.dx /
                (rail.width / widget.scopes.length))
            .clamp(-_kFlingLimit, _kFlingLimit);
    if (widget.scopes[next] != widget.selected) {
      widget.onSelected(widget.scopes[next]);
    }
  }

  void _onPanCancel() {
    // A tap loses the pan arena here. It never moved the marker, so its target
    // is left alone for the tap handler to set.
    if (!_grabbed) {
      _pressed = false;
      _wake();
      return;
    }
    _release(_selectedIndex);
  }

  /// Where the finger is, in cells, with the package's rubber band applied
  /// past either end.
  double _indexAt(double dx, _Rail rail) {
    final double last = (widget.scopes.length - 1).toDouble();
    final double raw = rail.indexAt(dx);
    final double resisted = IndicatorPhysics.applyRubberBandResistance(
      raw / last,
    );
    return resisted * last;
  }

  /// Pins the marker to the finger. What deforms is its shape, not its
  /// position.
  void _holdAt(double finger) {
    final double last = (widget.scopes.length - 1).toDouble();
    _travel.hold((finger + _grabOffset).clamp(-_kOverdrag, last + _kOverdrag));
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
    // The first tick after a start carries no elapsed time to integrate, and
    // the rest check below would read that as "nothing to do".
    if (dt <= 0) return;

    if (!_grabbed) {
      _travel.advance(dt);
      _pull.advance(dt);
      // Off the finger, the deformation follows the travel: the faster the
      // marker moves, the further its leading edge runs ahead of it.
      _squash.target = _travel.velocity * _kTravelSquash;
    }
    _squash.advance(dt);
    // The glass is a touch response, not a movement one: it swells in under
    // the finger and drains away the moment the finger is gone.
    _lens.target = _active ? 1 : 0;
    _lens.advance(dt);
    _frame.value++;

    if (!_grabbed &&
        _travel.isAtRest(0.0008) &&
        _squash.isAtRest(0.001) &&
        _pull.isAtRest(0.01) &&
        _lens.isAtRest(0.001)) {
      // Land on exact values rather than near them: a resting marker has to
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

/// The measured rail: how wide each cell is, where its centre sits, and how
/// wide the marker is when it is parked on it.
@immutable
class _Rail {
  const _Rail({
    required this.width,
    required this.widths,
    required this.centres,
    required this.markerWidths,
  });

  /// Distributes [width] across the cells in proportion to what each one has
  /// to show.
  ///
  /// Proportional rather than equal because the labels are nothing like the
  /// same length — `Partniyor` beside `Arxiv` in five equal cells leaves one
  /// crushed and the other mostly air.
  factory _Rail.pack({
    required double width,
    required List<double> contents,
    required double padding,
    required double markerPadding,
  }) {
    final List<double> natural = <double>[
      for (final double content in contents) content + 2 * padding,
    ];
    final double total = natural.fold<double>(0, (double a, double b) => a + b);
    final double factor = total <= 0 ? 1 : width / total;

    final List<double> widths = <double>[
      for (final double value in natural) value * factor,
    ];
    final List<double> centres = <double>[];
    double x = 0;
    for (final double cell in widths) {
      centres.add(x + cell / 2);
      x += cell;
    }
    final List<double> markers = <double>[
      for (int i = 0; i < widths.length; i++)
        math.min(widths[i], contents[i] + markerPadding),
    ];

    return _Rail(
      width: width,
      widths: widths,
      centres: centres,
      markerWidths: markers,
    );
  }

  final double width;
  final List<double> widths;
  final List<double> centres;
  final List<double> markerWidths;

  double centreAt(double index) => _lerpAt(centres, index);

  double markerWidthAt(double index) => _lerpAt(markerWidths, index);

  /// Which cell a point belongs to.
  int cellAt(double dx) {
    double edge = 0;
    for (int i = 0; i < widths.length; i++) {
      edge += widths[i];
      if (dx < edge) return i;
    }
    return widths.length - 1;
  }

  /// A point on the bar as a continuous cell index, by walking the centres.
  ///
  /// Outside the first and last centre it keeps going at that cell's own
  /// width, so an overdrag past either end still reads as cells rather than
  /// stopping dead.
  double indexAt(double dx) {
    final int last = centres.length - 1;
    if (dx <= centres.first) {
      return (dx - centres.first) / math.max(widths.first, 1);
    }
    if (dx >= centres.last) {
      return last + (dx - centres.last) / math.max(widths.last, 1);
    }
    for (int i = 0; i < last; i++) {
      if (dx <= centres[i + 1]) {
        final double span = math.max(centres[i + 1] - centres[i], 1);
        return i + (dx - centres[i]) / span;
      }
    }
    return last.toDouble();
  }

  double _lerpAt(List<double> values, double index) {
    final int lower = index.floor().clamp(0, values.length - 1);
    final int upper = index.ceil().clamp(0, values.length - 1);
    if (lower == upper) return values[lower];
    return values[lower] + (values[upper] - values[lower]) * (index - lower);
  }
}

/// The selected cell while nothing is being touched: a plain fill, no shader.
class _RestingMarker extends StatelessWidget {
  const _RestingMarker({
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
      left: left,
      top: _kMarkerInset,
      bottom: _kMarkerInset,
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
              shadows: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A25384F),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same marker under a finger: swollen, refracting, and over the glyphs.
class _MovingMarkerLens extends StatelessWidget {
  const _MovingMarkerLens({
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
              // `liquid_glass_easy` rather than the renderer, for its optical
              // border — the same reason the nav bar's indicator is pinned to
              // it, and the same style, so the two markers are one material.
              backend: AppGlassBackend.easy,
              style: kNavIndicatorGlass.copyWith(cornerRadius: radius),
              cornerRadius: radius,
              fade: lens,
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
