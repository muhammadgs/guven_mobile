import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/glass/app_glass.dart';
import '../../../../shared/glass/glass_backdrop.dart';
import '../../../../shared/glass/liquid_glass.dart';
import '../../../../shared/motion/spring.dart';
import '../../../home/presentation/widgets/home_glass.dart';

/// Güvən's compact bottom bar: a glass capsule with a plain marker under the
/// selected cell.
///
/// The marker is a flat fill sized to each label's measured width. It slides
/// between cells on a spring, and a finger dragging along the bar holds it
/// directly — it never lags behind the thing dragging it.
///
/// A touch turns the marker into a lens: it swells past the bar's edges and,
/// while the finger stays down, magnifies and bends the bar under it — the
/// iOS 26 tab bar. What it bends is a photograph of the bar taken as the
/// touch lands, without the marker in it ([captureScreenRegion]), so it costs
/// no read of the live screen. Without the liquid shader there is no lens.
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
    this.menuIndex,
    this.menuOpenIcon,
    this.menuOpen,
    this.liftedIndex,
    this.onLiftStart,
  }) : assert(labels.length == icons.length),
       assert(labels.length > 1);

  /// One per cell, and unique: a cell is keyed by its label, so when the
  /// order changes each one slides to its new place instead of the glyphs
  /// swapping under a stationary row.
  final List<String> labels;

  /// One SVG asset path per cell, drawn tinted to [kGlassInk] — the artwork's
  /// own fills are painted over, so a black-filled export and a `currentColor`
  /// one look the same here.
  final List<String> icons;
  final int selectedIndex;

  /// Every tap is reported, the selected cell's included — a cell that opens
  /// something, like `Daha çox`, has to hear the second tap that shuts it. A
  /// drag reports only a change.
  final ValueChanged<int> onSelected;
  final double height;
  final double iconSize;
  final TextStyle textStyle;

  /// A cell whose glyph turns into [menuOpenIcon] as [menuOpen] runs to 1.
  final int? menuIndex;
  final String? menuOpenIcon;
  final Animation<double>? menuOpen;

  /// A cell whose content a drag has picked up. It keeps its place in the
  /// row, drawn empty, until the drag puts something back.
  final int? liftedIndex;

  /// A long press on a cell. The caller owns the drag from then on; the bar
  /// only says which cell it started on and where.
  final void Function(int index, Offset globalPosition)? onLiftStart;

  @override
  State<GuvenGlassBottomBar> createState() => _GuvenGlassBottomBarState();
}

/// The travel spring, at ζ ≈ 0.71: the marker overshoots its cell and rocks back
/// instead of gliding to a stop.
const double _kTravelStiffness = 265;
const double _kTravelDamping = 23;

/// Cells per second the marker may carry out of a fling. Left unclamped, a flick
/// throws it most of a cell past its target.
const double _kFlingLimit = 6;

/// How far the marker may sit from the finger that grabbed it, in cells. A grab
/// from further away still pulls it over — it just has to travel.
const double _kGrabReach = 0.6;

/// Cells of overdrag allowed past either end of the bar.
const double _kOverdrag = 0.35;

/// How long a cell takes to slide to a new place when the order changes.
const Duration _kReflow = Duration(milliseconds: 260);

/// Room either side of a name inside the marker. The name sits low in the
/// capsule, where its rounded ends are already curving in, so less than this
/// and a letter at the name's bottom corner pokes out of the marker.
const double _kPillPad = 10;

/// The marker never comes closer than this to the bar's own rim.
const double _kEdgeInset = 3;

/// Between a marker and the name in the next cell.
const double _kNeighbourGap = 4;

/// The marker's inset from the bar's top and bottom.
const double _kPillInset = 7;

/// How far the lens swells past the resting marker on each side, fully
/// pressed. Vertically that is past the bar itself — the lens stands proud
/// of it.
const double _kLensOutsetX = 12;
const double _kLensOutsetY = 13;

/// How much of the screen round the bar the touch photographs, beyond the
/// bar: room for the swollen lens, its stretch and an overdragged end.
const double _kLensReachX = 64;
const double _kLensReachY = 28;

/// The press spring: smooth, a hint of overshoot as the lens swells.
const double _kPressStiffness = 420;
const double _kPressDamping = 36;

/// The stretch spring, and the most a fast drag stretches the lens: wider
/// and flatter, its area kept.
const double _kJellyStiffness = 320;
const double _kJellyDamping = 26;
const double _kJellyMax = 0.22;

/// The drag speed, in logical pixels a second, at which the stretch is half
/// of [_kJellyMax].
const double _kJellySpeed = 700;

/// Where each cell's name, marker and content go, for one set of names.
///
/// Five equal cells, but not every name fits one: a marker is its name plus
/// [_kPillPad] a side, so a long name's marker is wider than its cell and
/// reaches into the next one. That is fine until the next name is long too —
/// then the marker lands on its first letter. And an end cell's marker has to
/// be pushed in off the bar's rim, which leaves its own name hanging out of
/// the marker's rounded end unless the name moves with it.
///
/// So the names are fitted as a set. Any two neighbours must be short enough
/// that either one's marker clears the other's name; where a pair is not, the
/// longer name gives way — scaled down, never cut — by exactly the excess.
/// Every page can be dragged into the bar now, so this is worked out for
/// whatever row there is, not for the default one.
@immutable
class _BarCells {
  const _BarCells._(this.labels, this.pills, this.centers);

  factory _BarCells.fit({
    required List<double> natural,
    required double slotWidth,
    required double barWidth,
    required double iconSize,
  }) {
    final int n = natural.length;
    final List<double> labels = <double>[
      for (final double w in natural)
        math.min(w, barWidth - 2 * (_kEdgeInset + _kPillPad)),
    ];
    // Either one's marker, centred on its cell, clears the other's name.
    final double pairLimit = 2 * (slotWidth - _kPillPad - _kNeighbourGap);
    // An end marker pushed in off the rim clears the second cell's name.
    final double endLimit =
        1.5 * slotWidth - _kEdgeInset - 2 * _kPillPad - _kNeighbourGap;

    double body(int i) => math.max(labels[i], iconSize);

    void fitPair(int a, int b) {
      double excess = body(a) + body(b) - pairLimit;
      if (excess <= 0) return;
      // The longer name gives way first; only once the two are level is the
      // rest shared between them.
      final int long = labels[a] >= labels[b] ? a : b;
      final int short = long == a ? b : a;
      final double take = math.min(excess, labels[long] - labels[short]);
      labels[long] -= take;
      excess -= take;
      if (excess > 0) {
        labels[a] -= excess / 2;
        labels[b] -= excess / 2;
      }
    }

    void fitEnd(int end, int next) {
      double excess = body(end) + labels[next] / 2 - endLimit;
      if (excess <= 0) return;
      final double take = math.min(excess, labels[end] - iconSize);
      if (take > 0) {
        labels[end] -= take;
        excess -= take;
      }
      if (excess > 0) labels[next] -= 2 * excess;
    }

    // Each fix can only shorten a name, so a few sweeps settle.
    for (int pass = 0; pass < 4; pass++) {
      for (int i = 0; i + 1 < n; i++) {
        fitPair(i, i + 1);
      }
      if (n > 2) {
        fitEnd(0, 1);
        fitEnd(n - 1, n - 2);
      }
    }

    final List<double> pills = <double>[
      for (int i = 0; i < n; i++)
        math.min(body(i) + 2 * _kPillPad, barWidth - 2 * _kEdgeInset),
    ];
    final List<double> centers = <double>[
      for (int i = 0; i < n; i++)
        (slotWidth * (i + 0.5)).clamp(
          _kEdgeInset + pills[i] / 2,
          barWidth - _kEdgeInset - pills[i] / 2,
        ),
    ];
    return _BarCells._(labels, pills, centers);
  }

  /// How wide each name may be drawn.
  final List<double> labels;

  /// Each cell's resting marker.
  final List<double> pills;

  /// Where each cell's marker — and so its glyph and name — is centred.
  final List<double> centers;
}

class _GuvenGlassBottomBarState extends State<GuvenGlassBottomBar>
    with SingleTickerProviderStateMixin {
  /// Where the marker is, in cells.
  late final Spring _travel = Spring(
    stiffness: _kTravelStiffness,
    damping: _kTravelDamping,
    value: widget.selectedIndex.toDouble(),
  );

  /// Created eagerly rather than on first use: a bar that is disposed without
  /// ever having been touched would otherwise build its ticker from inside
  /// `dispose`, which reaches for an ancestor that is already gone.
  late final Ticker _ticker;

  /// Bumped whenever the marker needs redrawing. Only the indicator listens, so
  /// the labels are built once and handed down as a cached child.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Duration _lastTick = Duration.zero;
  bool _laidOut = false;
  bool _grabbed = false;
  double _grabOffset = 0;

  /// 0 the plain marker, 1 the lens fully swollen.
  final Spring _press = Spring(
    stiffness: _kPressStiffness,
    damping: _kPressDamping,
    value: 0,
  );

  /// How far the lens is stretched by the speed it moves at; see [_kJellyMax].
  final Spring _jelly = Spring(
    stiffness: _kJellyStiffness,
    damping: _kJellyDamping,
    value: 0,
  );

  /// Fingers on the bar.
  int _pointers = 0;

  /// The width of one cell, as last laid out.
  double _slotWidth = 0;

  /// The finger's speed along the bar, logical pixels a second, smoothed.
  double _fingerSpeed = 0;
  Duration? _lastDragStamp;

  /// What the lens shows: the bar and the screen round it, photographed as
  /// the touch landed. Null while there is no lens.
  final ValueNotifier<GlassBackdropImage?> _lensPicture =
      ValueNotifier<GlassBackdropImage?>(null);

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
    _lensPicture.value?.dispose();
    _lensPicture.dispose();
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
        // The lens stands proud of the bar; a clip would cut it flat.
        clipBehavior: Clip.none,
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
              _slotWidth = slotWidth;
              final _BarCells cells = _BarCells.fit(
                natural: <double>[
                  for (final String label in widget.labels)
                    _labelWidth(context, label),
                ],
                slotWidth: slotWidth,
                barWidth: barWidth,
                iconSize: widget.iconSize,
              );
              // Whether the row has been drawn before. See [_PopIn].
              final bool laidOut = _laidOut;
              _laidOut = true;

              // A Listener, not the gesture callbacks: it hears the touch the
              // moment it lands, before any recognizer has won the arena.
              return Listener(
                onPointerDown: (_) => _onPointerDown(),
                onPointerUp: (_) => _onPointerEnd(),
                onPointerCancel: (_) => _onPointerEnd(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) =>
                      _onTapAt(details.localPosition.dx, barWidth),
                  onPanStart: (DragStartDetails details) =>
                      _onPanStart(details, barWidth),
                  onPanUpdate: (DragUpdateDetails details) =>
                      _onPanUpdate(details, slotWidth, barWidth),
                  onPanEnd: (DragEndDetails details) =>
                      _onPanEnd(details, slotWidth, barWidth),
                  onPanCancel: _onPanCancel,
                  // Held still for long enough, a touch stops being about the
                  // selection and picks the cell up instead. The pan above loses
                  // the arena to it.
                  onLongPressStart: widget.onLiftStart == null
                      ? null
                      : (LongPressStartDetails details) =>
                            _onLongPressStart(details, slotWidth),
                  child: AnimatedBuilder(
                    animation: _frame,
                    builder: (BuildContext context, Widget? child) {
                      final double last = (widget.labels.length - 1).toDouble();
                      final double index = _travel.value.clamp(0.0, last);
                      final double indicatorWidth = _lerpAt(cells.pills, index);
                      final double left =
                          (_lerpAt(cells.centers, index) - indicatorWidth / 2)
                              .clamp(
                                _kEdgeInset,
                                barWidth - indicatorWidth - _kEdgeInset,
                              );
                      final Rect marker = Rect.fromLTWH(
                        left,
                        _kPillInset,
                        indicatorWidth,
                        widget.height - 2 * _kPillInset,
                      );
                      final double press = _press.value.clamp(0.0, 1.0);
                      final bool lens =
                          press > 0.001 && _lensPicture.value != null;

                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          // A plain fill *under* the glyphs, so they stay black
                          // on it. It hands over to the lens as that swells,
                          // and stays out of the lens's photograph.
                          _SelectionPill(
                            rect: marker,
                            radius: radius - _kPillInset,
                            opacity: lens ? 1 - press : 1,
                          ),
                          IgnorePointer(child: child!),
                          if (lens) _lens(marker),
                        ],
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < widget.labels.length;
                          index++
                        )
                          AnimatedPositioned(
                            key: ValueKey<String>(widget.labels[index]),
                            duration: _kReflow,
                            curve: Curves.easeOutCubic,
                            // Centred on its marker, not on its slot: an end
                            // cell's marker is pushed in off the bar's rim, and
                            // its glyph and name go with it rather than being
                            // left half outside it.
                            left: cells.centers[index] - slotWidth / 2,
                            top: 0,
                            bottom: 0,
                            width: slotWidth,
                            child: _PopIn(
                              // A cell that is new to the bar — traded in from
                              // `Daha çox` — pops into its place. The first row
                              // the bar ever draws just appears.
                              enabled: laidOut,
                              child: _tab(index, cells.labels[index]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// The lens over [marker]: swollen by the press, stretched by its speed,
  /// showing the photograph taken as the touch landed.
  Widget _lens(Rect marker) {
    final double press = _press.value;
    final double grown = math.max(press, 0);
    final double stretch = _jelly.value.clamp(0.0, _kJellyMax);
    // Wider and flatter with speed, its area kept.
    final double sx = 1 + stretch;
    final double sy = 1 / sx;
    final double width = (marker.width + 2 * _kLensOutsetX * grown) * sx;
    final double height = (marker.height + 2 * _kLensOutsetY * grown) * sy;
    final Rect lens = Rect.fromCenter(
      center: marker.center,
      width: width,
      height: height,
    );
    return Positioned.fromRect(
      key: const ValueKey<String>('nav-lens'),
      rect: lens,
      child: IgnorePointer(
        // Never in a photograph: a touch landing while the last lens is
        // still shrinking photographs the bar, not the lens.
        child: GlassCaptureHidden(
          child: GlassBackdropScope(
            backdrop: _lensPicture,
            child: GlassBackdropPaint(
              liquid: LiquidGlassSpec(
                cornerRadius: lens.shortestSide / 2,
                tint: kNavLensTint,
                fade: press.clamp(0.0, 1.0),
                optics: kNavLensOptics,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- lens

  void _onPointerDown() {
    _pointers++;
    if (!LiquidGlassShader.ready || widget.liftedIndex != null) return;
    // A fresh photograph unless the last lens is still on screen — then the
    // bar under it has not changed, and its photograph still holds.
    if (_lensPicture.value == null || _press.value < 0.01) _photograph();
    if (_lensPicture.value == null) return;
    _press.target = 1;
    _wake();
  }

  void _onPointerEnd() {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers > 0) return;
    _press.target = 0;
    _fingerSpeed = 0;
    _lastDragStamp = null;
    _wake();
  }

  /// Photographs the bar and the screen round it, sharper than the screen by
  /// as much as the lens magnifies.
  void _photograph() {
    final RenderObject? bar = context.findRenderObject();
    if (bar is! RenderBox || !bar.hasSize) return;
    final double ratio =
        (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) *
        kNavLensOptics.magnification;
    final GlassBackdropImage? picture = captureScreenRegion(
      anchor: bar,
      region: Rect.fromLTRB(
        -_kLensReachX,
        -_kLensReachY,
        bar.size.width + _kLensReachX,
        bar.size.height + _kLensReachY,
      ),
      pixelRatio: ratio,
    );
    if (picture == null) return;
    final GlassBackdropImage? previous = _lensPicture.value;
    _lensPicture.value = picture;
    previous?.dispose();
  }

  void _dropPhotograph() {
    final GlassBackdropImage? previous = _lensPicture.value;
    if (previous == null) return;
    _lensPicture.value = null;
    previous.dispose();
  }

  /// [labelWidth] is as wide as the name may be drawn — its own width, unless
  /// its neighbours leave it less. See [_BarCells].
  Widget _tab(int index, double labelWidth) {
    if (index == widget.liftedIndex) return const SizedBox.shrink();
    Widget glyph = _glyph(widget.icons[index]);
    final Animation<double>? menuOpen = widget.menuOpen;
    final String? menuOpenIcon = widget.menuOpenIcon;
    if (index == widget.menuIndex && menuOpen != null && menuOpenIcon != null) {
      // The filled glyph drains away and leaves only its outlines: the cell
      // empties, and what it held is out on the screen instead.
      glyph = Stack(
        alignment: Alignment.center,
        children: <Widget>[
          FadeTransition(opacity: ReverseAnimation(menuOpen), child: glyph),
          FadeTransition(opacity: menuOpen, child: _glyph(menuOpenIcon)),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        glyph,
        const SizedBox(height: 3),
        // Five cells share the bar's width, and some Azerbaijani names are as
        // wide as a whole cell. An ellipsis would truncate a word — `Əməkdaşl…`
        // — so a name that has to give way is scaled down instead, by exactly
        // as much as its neighbours need, and stays whole.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: labelWidth),
          child: FittedBox(
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
        ),
      ],
    );
  }

  Widget _glyph(String asset) {
    return SvgPicture.asset(
      asset,
      width: widget.iconSize,
      height: widget.iconSize,
      // The exports are not all square — `contain` letterboxes them inside
      // the square box so every cell's glyph keeps its own proportions and
      // still sits on one baseline with the others.
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
    );
  }

  /// How wide [label] wants to be drawn.
  double _labelWidth(BuildContext context, String label) {
    final TextPainter painter = TextPainter(
      // Measured in the style it is drawn in — the ambient one merged with
      // the bar's. Measuring the bar's alone missed the theme's letter
      // spacing, and every marker came out a few points narrower than its
      // name.
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(widget.textStyle),
      ),
      textDirection: Directionality.of(context),
      // Measured at the same scale it is drawn at, now that the app bounds the
      // system font scale centrally instead of pinning this label to 1.
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// [values] read at a fractional cell [index], for a marker in flight.
  double _lerpAt(List<double> values, double index) {
    final int lower = index.floor().clamp(0, values.length - 1);
    final int upper = index.ceil().clamp(0, values.length - 1);
    return values[lower] + (values[upper] - values[lower]) * (index - lower);
  }

  double _indexAtPosition(double dx, double barWidth) {
    final double indicatorFraction = 1 / widget.labels.length;
    final double raw =
        (dx / barWidth - indicatorFraction / 2) / (1 - indicatorFraction);
    final double resisted = rubberBand(raw);
    return resisted * (widget.labels.length - 1);
  }

  // ---------------------------------------------------------------- gestures

  void _onTapAt(double dx, double barWidth) {
    final int next = (dx / (barWidth / widget.labels.length)).floor().clamp(
      0,
      widget.labels.length - 1,
    );
    widget.onSelected(next);
  }

  void _onLongPressStart(LongPressStartDetails details, double slotWidth) {
    final int index = (details.localPosition.dx / slotWidth).floor().clamp(
      0,
      widget.labels.length - 1,
    );
    // The touch is picking the cell up now, not choosing: the lens goes.
    _press.target = 0;
    _wake();
    widget.onLiftStart?.call(index, details.globalPosition);
  }

  void _onPanStart(DragStartDetails details, double barWidth) {
    final double finger = _indexAtPosition(details.localPosition.dx, barWidth);
    // Grab the marker where it stands: it keeps its offset to the finger rather
    // than jumping to it, and a grab from beyond [_kGrabReach] drags it over
    // the remaining distance instead of snapping.
    _grabOffset = (_travel.value - finger).clamp(-_kGrabReach, _kGrabReach);
    _grabbed = true;
    _holdAt(finger);
    _wake();
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    double slotWidth,
    double barWidth,
  ) {
    _holdAt(_indexAtPosition(details.localPosition.dx, barWidth));
    // The finger's speed, for the lens's stretch: the held spring has none.
    final Duration? stamp = details.sourceTimeStamp;
    final Duration? previous = _lastDragStamp;
    if (stamp != null && previous != null && stamp > previous) {
      final double dt =
          (stamp - previous).inMicroseconds / Duration.microsecondsPerSecond;
      final double speed = details.delta.dx.abs() / dt;
      _fingerSpeed = _fingerSpeed * 0.6 + speed * 0.4;
    }
    _lastDragStamp = stamp;
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
    // A tap loses the pan arena here. It never moved the marker, so its
    // target is left alone for the tap handler to set.
    if (!_grabbed) return;
    _release(widget.selectedIndex);
  }

  /// Pins the marker to the finger: a dragged marker sits exactly where the
  /// finger is.
  void _holdAt(double finger) {
    final double last = (widget.labels.length - 1).toDouble();
    _travel.hold((finger + _grabOffset).clamp(-_kOverdrag, last + _kOverdrag));
  }

  void _release(int target) {
    _grabbed = false;
    _travel.target = target.toDouble();
    _wake();
  }

  // ----------------------------------------------------------------- physics

  /// Redraws the marker, and starts the ticker if the spring has work left.
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
      if (!_grabbed) _travel.advance(dt);
      _advanceLens(dt);
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
        _press.isAtRest(0.001) &&
        _jelly.isAtRest(0.001)) {
      _travel.snap();
      _press.snap();
      _jelly.snap();
      if (_press.value == 0) _dropPhotograph();
      _ticker.stop();
      _frame.value++;
    }
  }

  /// Swells or shrinks the lens, and stretches it by the speed it moves at.
  void _advanceLens(double dt) {
    _press.advance(dt);
    if (_grabbed) {
      // A finger that stops sends no more updates: let its speed die away.
      _fingerSpeed *= math.exp(-dt * 10);
    }
    final double speed = _grabbed
        ? _fingerSpeed
        : _travel.velocity.abs() * _slotWidth;
    final double pressed = _press.value.clamp(0.0, 1.0);
    _jelly.target = _kJellyMax * speed / (speed + _kJellySpeed) * pressed;
    _jelly.advance(dt);
  }
}

/// Grows a newly arrived cell into its place.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.enabled, required this.child});

  /// Read once, when the cell first appears.
  final bool enabled;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.enabled ? 0 : 1,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.55,
    end: 1,
  ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_pop);

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _pop.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// The marker under the selected cell: a plain fill.
///
/// Kept out of the lens's photograph: the lens takes its place, so under the
/// lens there is only the bar.
class _SelectionPill extends StatelessWidget {
  const _SelectionPill({
    required this.rect,
    required this.radius,
    required this.opacity,
  });

  final Rect rect;
  final double radius;

  /// 1 resting; less while the lens swells over it.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      key: const ValueKey<String>('nav-selection-pill'),
      rect: rect,
      child: GlassCaptureHidden(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: kNavIndicatorRestFill.withValues(
              alpha: kNavIndicatorRestFill.a * opacity.clamp(0.0, 1.0),
            ),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ),
    );
  }
}
