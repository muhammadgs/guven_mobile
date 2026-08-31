/// The filter, opened the way Apple opens a context menu: the button the
/// finger is on stretches into the menu.
///
/// It is one lens the whole way — the funnel button's glass grows into the
/// panel's, exactly as the start button grows into the login card
/// (`glass_morph.dart`) — and choosing a column grows a second panel out of
/// that column's own row. Nothing cross-fades between two surfaces; the glass
/// travels, and only what is *inside* it fades.
///
/// The route is deliberately not opaque: this floats over the task list rather
/// than replacing it, so the list can be seen narrowing behind it as values
/// are ticked, and a tap anywhere off the glass lands on the barrier and
/// closes it.
library;

import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../application/tasks_controller.dart';
import '../../domain/task_filter.dart';
import '../task_filter_metrics.dart';
import 'task_glass.dart';
import 'task_tools.dart';

/// How long the panel takes to open. Shorter than a page morph — a menu that
/// takes three quarters of a second to arrive reads as broken rather than
/// liquid.
const Duration _kOpen = Duration(milliseconds: 460);
const Duration _kClose = Duration(milliseconds: 300);

/// A values panel opens faster still: a smaller move, and the second thing
/// asked for rather than the first.
const Duration _kSubOpen = Duration(milliseconds: 360);
const Duration _kSubClose = Duration(milliseconds: 220);

/// Opens the filter over the task list, growing out of [button].
///
/// [button] is the filter button's rect in global coordinates and [radius] its
/// corner — where the panel's glass starts life. Completes once the panel has
/// finished collapsing back into it.
Future<void> openTaskFilter(
  BuildContext context, {
  required Rect button,
  required double radius,
  required TasksController controller,
}) async {
  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: radius,
    duration: _kOpen,
    reverseDuration: _kClose,
    // Over the screen, not instead of it.
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Filtri bağla',
    // Barely a shade. The design shows the task list at full strength behind
    // the panel, so this exists to say the panel is in front — not to hide
    // what it is in front of.
    barrierColor: const Color(0x14101826),
    builder: (_) => TaskFilterPanel(controller: controller),
  );

  await Navigator.of(context).push<void>(route);
  // `push` completes the moment the pop starts; `completed` waits for the
  // panel to actually be a button again.
  await route.completed;
}

/// The panel itself. Reads the morph when it was pushed through one, and
/// simply sits at rest when it was not.
class TaskFilterPanel extends StatefulWidget {
  const TaskFilterPanel({super.key, required this.controller});

  final TasksController controller;

  @override
  State<TaskFilterPanel> createState() => _TaskFilterPanelState();
}

class _TaskFilterPanelState extends State<TaskFilterPanel>
    with SingleTickerProviderStateMixin {
  /// The values panel's own flight, from a column's row out to its list.
  ///
  /// Built in [initState] rather than lazily on a `late final`: a panel that
  /// is disposed before it ever builds would otherwise create its ticker from
  /// inside `dispose`, looking up a `TickerMode` that is no longer there.
  late final AnimationController _sub;

  @override
  void initState() {
    super.initState();
    _sub = AnimationController(
      vsync: this,
      duration: _kSubOpen,
      reverseDuration: _kSubClose,
    )..addStatusListener(_onSubStatus);
  }

  /// The column whose values are showing.
  TaskFilterField? _column;

  /// A column tapped while another is still collapsing.
  ///
  /// Two values panels on screen at once would be two lenses refracting each
  /// other, so the first is always let out before the second comes in.
  TaskFilterField? _queued;

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
    _sub.dispose();
    super.dispose();
  }

  /// The whole panel is going home, so whatever hangs off it goes too.
  void _onFlightStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && _sub.value > 0) {
      _queued = null;
      _sub.reverse();
    }
  }

  void _onSubStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    final TaskFilterField? next = _queued;
    _queued = null;
    if (!mounted) return;
    setState(() => _column = next);
    if (next != null) _sub.forward();
  }

  void _tapColumn(TaskFilterField field) {
    if (_column == field) {
      _sub.reverse();
      return;
    }
    if (_column == null) {
      setState(() => _column = field);
      _sub.forward();
      return;
    }
    _queued = field;
    _sub.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final TasksController tasks = widget.controller;

    return ListenableBuilder(
      listenable: tasks,
      builder: (BuildContext context, _) {
        final List<TaskFilterField> fields = tasks.filterFields;
        final TaskFilterMetrics metrics = TaskFilterMetrics.of(
          context,
          button: GlassMorph.maybeOf(context)?.sourceRect ?? Rect.zero,
          columnCount: fields.length,
        );

        // This route is a *sibling* of the shell, not a screen inside it, so
        // the one `Material` the signed-in app owns is not above it — and
        // without one every label here would come out in the framework's
        // yellow-striped debug style. `transparency` paints nothing and, at
        // the default `Clip.none`, adds no layer for the lenses to lose their
        // backdrop to.
        //
        // The `Stack` inside it is deliberately bare: everywhere the panels
        // are not is where the barrier has to stay reachable, and a full-bleed
        // child here would swallow the tap that closes this.
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: <Widget>[
              _ColumnPanel(
                metrics: metrics,
                fields: fields,
                controller: tasks,
                openColumn: _column,
                onColumn: _tapColumn,
              ),
              if (_column != null)
                _ValuePanel(
                  metrics: metrics,
                  field: _column!,
                  index: fields.indexOf(_column!),
                  controller: tasks,
                  flight: _sub,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The list of columns — the design's `Filter` panel.
class _ColumnPanel extends StatelessWidget {
  const _ColumnPanel({
    required this.metrics,
    required this.fields,
    required this.controller,
    required this.openColumn,
    required this.onColumn,
  });

  final TaskFilterMetrics metrics;
  final List<TaskFilterField> fields;
  final TasksController controller;
  final TaskFilterField? openColumn;
  final ValueChanged<TaskFilterField> onColumn;

  @override
  Widget build(BuildContext context) {
    final Rect resting = metrics.columnPanel;
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final Widget content = _columns();

    if (morph == null) {
      return _PanelSurface(
        frame: GlassMorphFrame.settled(resting, metrics.radius),
        restingSize: resting.size,
        source: _sourceGlyph(),
        content: content,
      );
    }

    return AnimatedBuilder(
      animation: morph.progress,
      // The rows are built once; only the wrappers around them move.
      child: content,
      builder: (BuildContext context, Widget? child) {
        return _PanelSurface(
          frame: resolveGlassMorph(
            progress: morph.progress,
            from: morph.sourceRect,
            fromRadius: morph.sourceRadius,
            to: resting,
            toRadius: metrics.radius,
          ),
          restingSize: resting.size,
          source: _sourceGlyph(),
          content: child!,
        );
      },
    );
  }

  /// What the glass carries while it is still button-shaped: the funnel the
  /// finger pressed, fading out as the panel opens.
  Widget _sourceGlyph() {
    final double side = metrics.button.shortestSide;
    return Center(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: FunnelPainter(side)),
      ),
    );
  }

  Widget _columns() {
    final TaskFilter filter = controller.filter;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.padH,
        metrics.padTop,
        metrics.padH,
        metrics.padBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: metrics.headerHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.padH),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filter',
                        maxLines: 1,
                        style: TextStyle(
                          color: kGlassInk,
                          // CalSans, the app's display face: this panel's
                          // title is a title like the screen's own.
                          fontFamily: 'CalSans',
                          fontSize: metrics.titleSize,
                          height: 1.05,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ),
                  if (filter.isNotEmpty)
                    _ResetChip(metrics: metrics, onTap: controller.clearFilter),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final TaskFilterField field in fields)
                    _PanelRow(
                      metrics: metrics,
                      label: field.label,
                      selected: field == openColumn,
                      count: filter.valuesOf(field).length,
                      onTap: () => onColumn(field),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One column's values, grown out of that column's row.
class _ValuePanel extends StatelessWidget {
  const _ValuePanel({
    required this.metrics,
    required this.field,
    required this.index,
    required this.controller,
    required this.flight,
  });

  final TaskFilterMetrics metrics;
  final TaskFilterField field;
  final int index;
  final TasksController controller;
  final Animation<double> flight;

  @override
  Widget build(BuildContext context) {
    final List<String> options = controller.filterOptions(field);
    final Rect from = metrics.columnRow(index);
    final Rect resting = metrics.valuePanel(
      index: index,
      // `Hamısı` is a row like any other and takes a row's height.
      valueCount: options.length + 1,
    );

    return AnimatedBuilder(
      animation: flight,
      child: _values(options),
      builder: (BuildContext context, Widget? child) {
        return _PanelSurface(
          frame: resolveGlassMorph(
            progress: flight,
            from: from,
            fromRadius: from.height / 2,
            to: resting,
            toRadius: metrics.radius,
          ),
          restingSize: resting.size,
          // The row it grew out of is still drawn in the panel behind it, so
          // this glass leaves its source empty rather than printing the same
          // label twice.
          source: const SizedBox.shrink(),
          content: child!,
        );
      },
    );
  }

  Widget _values(List<String> options) {
    final Set<String> chosen = controller.filter.valuesOf(field);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        metrics.padH,
        metrics.padTop,
        metrics.padH,
        metrics.padBottom,
      ),
      physics: const ClampingScrollPhysics(),
      itemExtent: metrics.rowHeight,
      itemCount: options.length + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          // `Hamısı` is not a value — it is the column not narrowing
          // anything, which is why it reads as chosen exactly when nothing
          // else is.
          return _PanelRow(
            metrics: metrics,
            label: 'Hamısı',
            selected: chosen.isEmpty,
            count: 0,
            onTap: () => controller.clearFilterField(field),
          );
        }
        final String value = options[i - 1];
        return _PanelRow(
          metrics: metrics,
          label: value,
          selected: chosen.contains(value),
          ticked: chosen.contains(value),
          count: 0,
          onTap: () => controller.toggleFilter(field, value),
        );
      },
    );
  }
}

/// One lens, two contents — the panel's version of the login card's surface.
///
/// Nothing here wraps the glass in an `Opacity` or an `ImageFiltered`: either
/// would open a `saveLayer` over a surface that samples its own backdrop, and
/// the lens would render black. Only what sits *inside* the glass fades.
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.frame,
    required this.restingSize,
    required this.source,
    required this.content,
  });

  final GlassMorphFrame frame;

  /// The panel's size once it has landed.
  ///
  /// The rows are always laid out against this and never against the
  /// in-flight rect — a menu reflowing inside a 42pt button would overflow on
  /// every frame of the opening.
  final Size restingSize;

  final Widget source;
  final Widget content;

  @override
  Widget build(BuildContext context) {
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
          // Pinned to `liquid_glass_easy`, like the button it grew out of —
          // see [kTaskFilterGlass].
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
                  child: blurred(6 * (1 - frame.sourceOpacity), source),
                ),
              IgnorePointer(
                ignoring: !frame.isSettled,
                child: OverflowBox(
                  minWidth: restingSize.width,
                  maxWidth: restingSize.width,
                  minHeight: restingSize.height,
                  maxHeight: restingSize.height,
                  child: Opacity(
                    opacity: frame.targetOpacity,
                    child: blurred(
                      10 * (1 - frame.targetOpacity),
                      Transform.translate(
                        offset: Offset(0, 14 * (1 - frame.targetOpacity)),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of either panel: a label, and a white capsule under it when it is
/// doing something.
class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.metrics,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
    this.ticked = false,
  });

  final TaskFilterMetrics metrics;
  final String label;

  /// Wears the capsule: the open column, or a chosen value.
  final bool selected;

  /// A chosen value also carries a tick. The capsule alone cannot say whether
  /// a row is *open* or *on*, and in a values panel it is on.
  final bool ticked;

  /// How many values this column is narrowing by, drawn as a badge.
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: metrics.rowHeight,
        padding: EdgeInsets.symmetric(horizontal: metrics.padH),
        decoration: selected
            ? ShapeDecoration(
                color: kTaskFilterRowFill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(metrics.rowHeight / 2),
                ),
              )
            : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: metrics.labelSize,
                  height: 1.1,
                  color: selected ? kGlassInk : kTaskFilterRowInk,
                ),
              ),
            ),
            if (ticked)
              Icon(
                Icons.check_rounded,
                size: metrics.labelSize * 1.15,
                color: kGlassInk,
              )
            else if (count > 0)
              _Badge(count: count, size: metrics.labelSize),
          ],
        ),
      ),
    );
  }
}

/// The count on a column that is narrowing the list.
///
/// The site marks an active column the same way and for the same reason: the
/// panel has to say which columns are doing something without being opened
/// one by one first.
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: size * 1.3),
      height: size * 1.3,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.25),
      decoration: const ShapeDecoration(
        color: kTaskFilterBadge,
        shape: StadiumBorder(),
      ),
      child: Text(
        '$count',
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: size * 0.72,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// `Sıfırla` — drops every column at once.
///
/// A chip in the title bar rather than a row in the list: it comes and goes
/// with the selections, and anything that comes and goes below the columns
/// would resize the panel while the user is reading it.
class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.metrics, required this.onTap});

  final TaskFilterMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: metrics.labelSize * 1.9,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: metrics.labelSize * 0.62),
        decoration: const ShapeDecoration(
          color: kTaskFilterRowFill,
          shape: StadiumBorder(),
        ),
        child: Text(
          'Sıfırla',
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: metrics.labelSize * 0.78,
            height: 1,
            color: kGlassInkMuted,
          ),
        ),
      ),
    );
  }
}
