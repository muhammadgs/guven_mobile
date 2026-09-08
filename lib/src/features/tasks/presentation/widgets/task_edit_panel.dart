/// `Redaktə`, opened the way `Yeni tapşırıq` is: the button the finger is on
/// stretches into the sheet.
///
/// One flight rather than the new-task panel's two — there is no chooser in
/// front of this form — but the same single pane of glass. The card's
/// `Redaktə` pill and the sheet are never on screen together: one lens travels
/// between their two rects and only what is *inside* it cross-fades, because
/// two stacked lenses read as a double image and an `Opacity` above a lens
/// puts it inside a `saveLayer` and renders it black
/// ([backdrop-filter-black-flash]).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../../auth/application/session_controller.dart';
import '../../application/new_task_controller.dart' show OptionList;
import '../../application/task_edit_controller.dart';
import '../../domain/new_task.dart' show TaskOption;
import '../../domain/task_edit.dart';
import '../../domain/task_item.dart';
import '../../domain/task_status.dart';
import '../new_task_metrics.dart';
import 'new_task_box.dart';
import 'new_task_picker.dart';
import 'task_edit_form.dart';
import 'task_glass.dart';

/// The pill becoming the sheet. The same lengths the new-task sheet's own
/// flight runs at — it is the one move on this screen worth watching.
const Duration _kOpen = Duration(milliseconds: 520);
const Duration _kClose = Duration(milliseconds: 360);

/// Opens `Redaktə` over the task list, growing out of [button].
///
/// Completes once everything has collapsed back into the button, and answers
/// with how the save went — or null when nothing was saved.
Future<TaskEditOutcome?> openTaskEdit(
  BuildContext context, {
  required Rect button,
  required double radius,
  required SessionController session,
  required TaskItem task,
}) async {
  TaskEditOutcome? saved;

  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: radius,
    duration: _kOpen,
    reverseDuration: _kClose,
    // Over the screen, not instead of it.
    opaque: false,
    barrierDismissible: false,
    barrierLabel: 'Bağla',
    // The deep shade is a blur as well as a colour and has to arrive with the
    // flight, so the panel paints it itself.
    barrierColor: Colors.transparent,
    builder: (_) => TaskEditPanel(
      session: session,
      task: task,
      onSaved: (TaskEditOutcome outcome) => saved = outcome,
    ),
  );

  await Navigator.of(context).push<void>(route);
  // `push` completes the moment the pop starts; `completed` waits for the
  // glass to actually be a button again.
  await route.completed;
  return saved;
}

class TaskEditPanel extends StatefulWidget {
  const TaskEditPanel({
    super.key,
    required this.session,
    required this.task,
    required this.onSaved,
    this.controller,
  });

  final SessionController session;
  final TaskItem task;
  final ValueChanged<TaskEditOutcome> onSaved;

  /// Injected by the widget tests, which have no backend to ask.
  @visibleForTesting
  final TaskEditController? controller;

  @override
  State<TaskEditPanel> createState() => _TaskEditPanelState();
}

class _TaskEditPanelState extends State<TaskEditPanel>
    with TickerProviderStateMixin {
  late final TaskEditController _controller =
      widget.controller ?? TaskEditController(widget.session, widget.task);

  /// A field's list, the date wheel or the status list, growing out of its own
  /// box.
  late final AnimationController _picker = AnimationController(
    vsync: this,
    duration: kPickerOpen,
    reverseDuration: kPickerClose,
  )..addStatusListener(_onPickerStatus);

  TaskEditField? _field;
  bool _date = false;
  bool _status = false;
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

  void _onPickerStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {
        _field = null;
        _date = false;
        _status = false;
      });
    }
  }

  /// A list is up, so this closes the list; otherwise it closes the sheet.
  void _back() {
    FocusScope.of(context).unfocus();
    if (_picker.value > 0) {
      _picker.reverse();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  void _open({TaskEditField? field, bool date = false, bool status = false}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _field = field;
      _date = date;
      _status = status;
    });
    _picker.forward(from: 0);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final TaskEditOutcome outcome = await _controller.save();
    if (!mounted || !outcome.saved) return;
    widget.onSaved(outcome);
    Navigator.of(context).maybePop();
  }

  /// The three ends the `Status` field offers, as a picker list.
  OptionList get _statusList => OptionList(
    options: <TaskOption>[
      for (final TaskEditStatus status in TaskEditStatus.values)
        TaskOption(id: status.index, name: status.label),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final NewTaskMetrics metrics = NewTaskMetrics.of(
      context,
      button: morph?.sourceRect ?? Rect.zero,
      // This sheet has no chooser in front of it; the count is only ever read
      // for the new-task menu's height.
      menuRows: 0,
    );

    // A sibling of the shell rather than a screen inside it, so the one
    // `Material` the signed-in app owns is not above this one — and without it
    // every label here would come out in the framework's yellow-striped debug
    // style. `transparency` paints nothing and, at the default `Clip.none`,
    // adds no layer for the lenses to lose their backdrop to.
    return Material(
      type: MaterialType.transparency,
      child: PopScope<Object?>(
        // A list closes before the sheet does. A half-typed note is not
        // something to lose to a stray swipe.
        canPop: _picker.value == 0,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _back();
        },
        child: Stack(
          children: <Widget>[
            _Scrim(flight: morph?.progress),
            // The dimmed screen behind the sheet must not be reachable:
            // tapping it would throw away everything typed so far with no way
            // back.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
            _Surface(metrics: metrics, morph: morph, form: _form(metrics)),
            if (_field != null || _date || _status) ...<Widget>[
              // A tap anywhere off the list closes just the list, not the
              // sheet under it.
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
                    emptyMessage: _field!.emptyMessage,
                    list: _controller.listOf(_field!),
                    chosen: _controller.chosen(_field!),
                    onPick: (TaskOption option) {
                      _controller.choose(_field!, option);
                      _picker.reverse();
                    },
                  ),
                )
              else if (_status)
                NewTaskPickerPanel(
                  metrics: metrics,
                  anchor: _anchor,
                  flight: _picker,
                  emptyMessage: 'Status tapılmadı',
                  list: _statusList,
                  chosen: _controller.status == null
                      ? null
                      : TaskOption(
                          id: _controller.status!.index,
                          name: _controller.status!.label,
                        ),
                  onPick: (TaskOption option) {
                    _controller.setStatus(TaskEditStatus.values[option.id]);
                    _picker.reverse();
                  },
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) => TaskEditForm(
        controller: _controller,
        metrics: metrics,
        openField: _field,
        dateOpen: _date,
        statusOpen: _status,
        onOpenField: (TaskEditField field, Rect rect) {
          _anchor = rect;
          _open(field: field);
        },
        onOpenDate: (Rect rect) {
          _anchor = rect;
          _open(date: true);
        },
        onOpenStatus: (Rect rect) {
          _anchor = rect;
          _open(status: true);
        },
        onBack: _back,
        onCancel: _close,
        onSubmit: _submit,
      ),
    );
  }
}

/// The single lens, and the two things that live inside it.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.metrics,
    required this.morph,
    required this.form,
  });

  final NewTaskMetrics metrics;
  final GlassMorph? morph;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final Rect sheetRect = metrics.sheet;
    final Animation<double>? flight = morph?.progress;

    if (flight == null) {
      return _paint(GlassMorphFrame.settled(sheetRect, metrics.sheetRadius));
    }

    return AnimatedBuilder(
      animation: flight,
      builder: (BuildContext context, _) => _paint(
        resolveGlassMorph(
          progress: flight,
          from: morph!.sourceRect,
          fromRadius: morph!.sourceRadius,
          to: sheetRect,
          toRadius: metrics.sheetRadius,
        ),
      ),
    );
  }

  Widget _paint(GlassMorphFrame frame) {
    return Positioned.fromRect(
      rect: frame.rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(frame.radius),
          boxShadow: BoxShadow.lerpList(
            kTaskCardLift,
            kTaskFilterLift,
            frame.blend,
          ),
        ),
        child: AppGlassSurface(
          // Pinned to `liquid_glass_easy`, like every other surface on this
          // screen, and wearing the filter's own Figma settings once it has
          // landed — the same glass the `Yeni tapşırıq` sheet is made of.
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
                    // What the glass carries while it is still pill-shaped:
                    // the button the finger pressed, fading out as the sheet
                    // opens.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: TaskAction.edit.gradient,
                        ),
                        borderRadius: BorderRadius.circular(frame.radius),
                      ),
                    ),
                  ),
                ),
              _Layer(
                size: metrics.sheet.size,
                opacity: frame.targetOpacity,
                child: form,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The form, laid out at the size it has when it has landed.
///
/// Always against that size and never against the in-flight rect: a form
/// reflowing inside a 40pt pill would overflow on every frame of the opening,
/// and a `ListView` would rebuild its whole viewport each time.
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

/// What the screen behind the sheet looks like: darkened, and pushed out of
/// focus.
///
/// Painted below the lens, so the glass samples an already-dimmed backdrop,
/// and through an `IgnorePointer` so it swallows nothing.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.flight});

  final Animation<double>? flight;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? flight = this.flight;
    if (flight == null) return _paint(1);

    return AnimatedBuilder(
      animation: flight,
      builder: (BuildContext context, _) =>
          _paint(flight.value.clamp(0.0, 1.0)),
    );
  }

  Widget _paint(double t) {
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
  }
}
