/// `Yeni tapşırıq`, opened the way the filter is: the `+` button the finger is
/// on stretches into the chooser, and the chooser stretches into the form.
///
/// It is **one** pane of glass the whole way. The `+` button, the `Yeni` menu
/// and the sheet are never on screen together — a single lens travels between
/// their three rects and only what is *inside* it cross-fades. That is not a
/// stylistic preference: two stacked lenses refract each other and read as a
/// double image, and an `Opacity` above a lens puts it inside a `saveLayer`,
/// leaves it sampling an empty backdrop, and renders it black
/// ([backdrop-filter-black-flash]).
///
/// The chain is built by feeding one morph into the other. The chooser→sheet
/// flight produces a rect, and *that rect* is handed to the button→chooser
/// flight as its destination. So the destination itself moves: opening runs
/// the outer flight, choosing a kind runs the inner one, `geri` reverses the
/// inner one, and closing from the sheet collapses the whole thing straight
/// back into the `+` button without a seam anywhere.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../../auth/application/session_controller.dart';
import '../../application/new_task_controller.dart';
import '../../domain/new_task.dart';
import '../new_task_metrics.dart';
import 'new_task_form.dart';
import 'new_task_picker.dart';
import 'new_task_box.dart';
import 'task_glass.dart';
import 'task_tools.dart';

/// The `+` becoming the chooser. Same length as the filter's: a menu that
/// takes three quarters of a second to arrive reads as broken, not liquid.
const Duration _kOpen = Duration(milliseconds: 460);
const Duration _kClose = Duration(milliseconds: 320);

/// The chooser becoming the form. Longer — it is a far bigger move, and it is
/// the one flight on this screen that is worth watching.
const Duration _kSheetOpen = Duration(milliseconds: 560);
const Duration _kSheetClose = Duration(milliseconds: 380);

/// Opens the chooser over the task list, growing out of [button].
///
/// Completes once everything has collapsed back into the button, and answers
/// with the kind of task that was created — or null when nothing was.
Future<NewTaskKind?> openNewTask(
  BuildContext context, {
  required Rect button,
  required double radius,
  required SessionController session,
}) async {
  NewTaskKind? created;

  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: radius,
    duration: _kOpen,
    reverseDuration: _kClose,
    // Over the screen, not instead of it.
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Bağla',
    // The chooser's own shade. The sheet wants a far deeper one, but that is a
    // blur as well as a colour and it has to come and go with the *second*
    // flight, so the panel paints it itself.
    barrierColor: kNewTaskMenuScrim,
    builder: (_) => NewTaskPanel(
      session: session,
      onCreated: (NewTaskKind kind) => created = kind,
    ),
  );

  await Navigator.of(context).push<void>(route);
  // `push` completes the moment the pop starts; `completed` waits for the
  // glass to actually be a button again.
  await route.completed;
  return created;
}

class NewTaskPanel extends StatefulWidget {
  const NewTaskPanel({
    super.key,
    required this.session,
    required this.onCreated,
    this.controller,
  });

  final SessionController session;
  final ValueChanged<NewTaskKind> onCreated;

  /// Injected by the widget tests, which have no backend to ask.
  @visibleForTesting
  final NewTaskController? controller;

  @override
  State<NewTaskPanel> createState() => _NewTaskPanelState();
}

class _NewTaskPanelState extends State<NewTaskPanel>
    with TickerProviderStateMixin {
  late final NewTaskController _controller =
      widget.controller ?? NewTaskController(widget.session);

  /// The chooser→sheet flight.
  late final AnimationController _sheet = AnimationController(
    vsync: this,
    duration: _kSheetOpen,
    reverseDuration: _kSheetClose,
  )..addStatusListener(_onSheetStatus);

  /// A field's list, or the date wheel, growing out of its own box.
  late final AnimationController _picker = AnimationController(
    vsync: this,
    duration: kPickerOpen,
    reverseDuration: kPickerClose,
  )..addStatusListener(_onPickerStatus);

  /// The kind being filled in. Kept through the closing flight so the form is
  /// still drawn while it shrinks, and cleared when that flight lands.
  NewTaskKind? _kind;

  NewTaskField? _field;
  bool _date = false;
  Rect _anchor = Rect.zero;

  Animation<double>? _flight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? flight = GlassMorph.maybeOf(context)?.progress;
    if (flight == _flight) return;
    _flight?.removeStatusListener(_onFlightStatus);
    _flight = flight?..addStatusListener(_onFlightStatus);
  }

  @override
  void dispose() {
    _flight?.removeStatusListener(_onFlightStatus);
    _picker.dispose();
    _sheet.dispose();
    // Only the one this panel made. An injected controller belongs to whoever
    // injected it.
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// The whole surface is going home, so everything hanging off it goes too.
  void _onFlightStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) return;
    if (_picker.value > 0) _picker.reverse();
  }

  void _onSheetStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() => _kind = null);
    }
  }

  void _onPickerStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {
        _field = null;
        _date = false;
      });
    }
  }

  void _choose(NewTaskKind kind) {
    setState(() => _kind = kind);
    _controller.begin(kind);
    _sheet.forward();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_picker.value > 0) {
      _picker.reverse();
      return;
    }
    _sheet.reverse();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  void _openField(NewTaskField field, Rect anchor) {
    FocusScope.of(context).unfocus();
    setState(() {
      _date = false;
      _field = field;
      _anchor = anchor;
    });
    _picker.forward(from: 0);
  }

  void _openDate(Rect anchor) {
    FocusScope.of(context).unfocus();
    setState(() {
      _field = null;
      _date = true;
      _anchor = anchor;
    });
    _picker.forward(from: 0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final NewTaskKind? kind = _kind;
    if (kind == null) return;

    final NewTaskOutcome outcome = await _controller.submit();
    if (!mounted || !outcome.created) return;
    widget.onCreated(kind);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final NewTaskMetrics metrics = NewTaskMetrics.of(
      context,
      button: morph?.sourceRect ?? Rect.zero,
      menuRows: NewTaskKind.values.length,
    );

    // This route is a *sibling* of the shell, not a screen inside it, so the
    // one `Material` the signed-in app owns is not above it — and without one
    // every label here would come out in the framework's yellow-striped debug
    // style. `transparency` paints nothing and, at the default `Clip.none`,
    // adds no layer for the lenses to lose their backdrop to.
    return Material(
      type: MaterialType.transparency,
      child: PopScope<Object?>(
        // Back out of the form to the chooser first; only the chooser closes
        // the whole thing. A half-filled form is not something to lose to a
        // stray swipe.
        canPop: _kind == null && _picker.value == 0,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _back();
        },
        child: Stack(
          children: <Widget>[
            _Scrim(sheet: _sheet, flight: morph?.progress),
            // While the form is up, the barrier behind it must not be
            // reachable: tapping the dimmed screen would throw away everything
            // typed so far, with no way back. The chooser has nothing to lose,
            // so it leaves the barrier alone.
            if (_kind != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
            _Surface(
              metrics: metrics,
              morph: morph,
              sheet: _sheet,
              menu: _Menu(metrics: metrics, onChoose: _choose),
              form: _form(metrics),
            ),
            if (_field != null || _date) ...<Widget>[
              // A tap anywhere off the list closes just the list, not the
              // form under it.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _picker.reverse,
                ),
              ),
              if (_field != null)
                ListenableBuilder(
                  listenable: _controller,
                  builder: (BuildContext context, _) => NewTaskPickerPanel(
                    metrics: metrics,
                    anchor: _anchor,
                    flight: _picker,
                    field: _field!,
                    kind: _kind ?? NewTaskKind.internal,
                    list: _controller.listOf(_field!),
                    chosen: _controller.chosen(_field!),
                    onPick: (TaskOption option) {
                      _controller.choose(_field!, option);
                      _picker.reverse();
                    },
                  ),
                )
              else
                NewTaskDatePanel(
                  metrics: metrics,
                  anchor: _anchor,
                  flight: _picker,
                  initial: _controller.dueDate,
                  onPick: (DateTime day) {
                    _controller.setDueDate(day);
                    _picker.reverse();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _form(NewTaskMetrics metrics) {
    final NewTaskKind? kind = _kind;
    if (kind == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) => NewTaskForm(
        controller: _controller,
        metrics: metrics,
        kind: kind,
        openField: _field,
        dateOpen: _date,
        onOpenField: _openField,
        onOpenDate: _openDate,
        onBack: _back,
        onCancel: _close,
        onSubmit: _submit,
      ),
    );
  }
}

/// The single lens, and the three things that live inside it.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.metrics,
    required this.morph,
    required this.sheet,
    required this.menu,
    required this.form,
  });

  final NewTaskMetrics metrics;
  final GlassMorph? morph;
  final Animation<double> sheet;
  final Widget menu;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final Rect menuRect = metrics.menuPanel;
    final Rect sheetRect = metrics.sheet;
    final Animation<double>? flight = morph?.progress;

    return AnimatedBuilder(
      animation: flight == null
          ? sheet
          : Listenable.merge(<Listenable>[flight, sheet]),
      builder: (BuildContext context, _) {
        // Where the surface *wants* to be this frame: the chooser, the form,
        // or somewhere on the spring between them.
        final GlassMorphFrame inner = resolveGlassMorph(
          progress: sheet,
          from: menuRect,
          fromRadius: metrics.menuRadius,
          to: sheetRect,
          toRadius: metrics.sheetRadius,
        );

        // …and where it actually is, given how far it has got out of the
        // button. At rest this is exactly `inner`.
        final GlassMorphFrame frame = flight == null
            ? GlassMorphFrame.settled(inner.rect, inner.radius)
            : resolveGlassMorph(
                progress: flight,
                from: morph!.sourceRect,
                fromRadius: morph!.sourceRadius,
                to: inner.rect,
                toRadius: inner.radius,
              );

        return Positioned.fromRect(
          rect: frame.rect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(frame.radius),
              boxShadow: BoxShadow.lerpList(
                kGlassLift,
                kTaskFilterLift,
                frame.blend,
              ),
            ),
            child: AppGlassSurface(
              // Pinned to `liquid_glass_easy`, like the button it grew out of
              // and like the filter — and the user asked for the filter's glass
              // exactly, so it wears the filter's own settings.
              backend: AppGlassBackend.easy,
              style: lerpAppGlassStyle(
                kTaskToolGlass,
                kTaskFilterGlass,
                frame.blend,
                cornerRadius: frame.radius,
              ),
              cornerRadius: frame.radius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (frame.sourceOpacity > 0.01)
                    Opacity(
                      opacity: frame.sourceOpacity,
                      child: blurred(
                        6 * (1 - frame.sourceOpacity),
                        _plus(metrics),
                      ),
                    ),
                  _Layer(
                    size: menuRect.size,
                    opacity: frame.targetOpacity * inner.sourceOpacity,
                    child: menu,
                  ),
                  _Layer(
                    size: sheetRect.size,
                    opacity: frame.targetOpacity * inner.targetOpacity,
                    child: form,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// What the glass carries while it is still button-shaped: the `+` the
  /// finger pressed, fading out as the chooser opens.
  Widget _plus(NewTaskMetrics metrics) {
    final double side = metrics.button.shortestSide;
    return Center(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: PlusPainter(side)),
      ),
    );
  }
}

/// One of the two contents, laid out at the size it has when it has landed.
///
/// Always against that size and never against the in-flight rect: a form
/// reflowing inside a 42pt button would overflow on every frame of the
/// opening, and a `ListView` would rebuild its whole viewport each time.
class _Layer extends StatelessWidget {
  const _Layer({
    required this.size,
    required this.opacity,
    required this.child,
  });

  final Size size;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.004) return const SizedBox.shrink();

    // The one thing the contents need to know about the flight. The boxes on
    // the form are lenses, and while this layer is fading they are inside an
    // `Opacity` — a `saveLayer`, which a lens under it samples instead of the
    // screen and comes out black. They draw as a flat fill until this is true.
    return NewTaskGlass(
      settled: opacity >= 0.999,
      child: IgnorePointer(
        ignoring: opacity < 0.99,
        child: OverflowBox(
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: blurred(
              10 * (1 - opacity),
              Transform.translate(
                offset: Offset(0, 14 * (1 - opacity)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `Yeni` — the three kinds of task.
class _Menu extends StatelessWidget {
  const _Menu({required this.metrics, required this.onChoose});

  final NewTaskMetrics metrics;
  final ValueChanged<NewTaskKind> onChoose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.menuPadH,
        NewTaskMetrics.kMenuPadTop * metrics.scale,
        metrics.menuPadH,
        NewTaskMetrics.kMenuPadBottom * metrics.scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: metrics.menuTitleHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.menuPadH),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Yeni',
                  maxLines: 1,
                  style: TextStyle(
                    color: kGlassInk,
                    fontFamily: 'CalSans',
                    fontSize: metrics.menuTitleSize,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
          ),
          for (final NewTaskKind kind in NewTaskKind.values)
            _MenuRow(metrics: metrics, kind: kind, onTap: () => onChoose(kind)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.metrics,
    required this.kind,
    required this.onTap,
  });

  final NewTaskMetrics metrics;
  final NewTaskKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: kind.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: metrics.menuRowHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.menuPadH),
            child: Row(
              children: <Widget>[
                // A fixed gutter, wide enough for the widest of the three, so
                // every glyph is centred in the same column and every label
                // starts at the same x â the icons differ in size, the rows
                // must not.
                SizedBox(
                  width: metrics.labelSize * 1.25 * NewTaskKind.maxIconScale,
                  child: Center(
                    child: SvgPicture.asset(
                      kind.icon,
                      width: metrics.labelSize * 1.25 * kind.iconScale,
                      height: metrics.labelSize * 1.25 * kind.iconScale,
                      colorFilter: const ColorFilter.mode(
                        kGlassInk,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10 * metrics.scale),
                Flexible(
                  child: Text(
                    kind.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: metrics.labelSize,
                      height: 1.15,
                      color: kGlassInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the screen behind the form looks like: darkened, and pushed out of
/// focus.
///
/// It rides the *sheet's* flight, not the route's, because the chooser is a
/// menu — the list behind it is still the subject — while the form is a page
/// of its own and the design puts the task list well back behind it. Painted
/// below the lens, so the glass samples an already-dimmed backdrop; painted
/// through an `IgnorePointer`, so the tap that closes the chooser still
/// reaches the route's barrier underneath.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.sheet, required this.flight});

  final Animation<double> sheet;
  final Animation<double>? flight;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? flight = this.flight;

    return AnimatedBuilder(
      animation: flight == null
          ? sheet
          : Listenable.merge(<Listenable>[flight, sheet]),
      builder: (BuildContext context, _) {
        final double t = (sheet.value * (flight?.value ?? 1)).clamp(0.0, 1.0);
        if (t <= 0.01) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: kNewTaskSheetBlur * t,
                sigmaY: kNewTaskSheetBlur * t,
              ),
              child: ColoredBox(
                color: kNewTaskSheetScrim.withValues(
                  alpha: kNewTaskSheetScrim.a * t,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
