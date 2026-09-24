/// `Detallar` — the `Baza` tab's menu, opened exactly the way the task filter
/// opens: the button the finger is on stretches into the menu, and choosing a
/// heading grows a second panel out of that heading's own row.
///
/// One lens the whole way, as there (`task_filter_panel.dart`): the button's
/// glass *becomes* the menu, nothing cross-fades between two surfaces, and
/// only what is inside the glass fades. Two panels are never both growing —
/// a heading's panel is let out before the next one comes in.
///
/// Unlike the filter, this menu pushes the page back behind a blur, the way
/// the design draws it: it is a way somewhere else, and the page it is over is
/// no longer the subject.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../domain/database_metric.dart' show kDatabaseIconDir;
import '../../domain/database_section.dart';
import '../database_menu_metrics.dart';
import 'database_glass.dart';

/// The list glyph on the menu button.
const String kDatabaseMenuIcon = '${kDatabaseIconDir}kateqoriyalar.svg';

/// The filter's timings: a menu that takes three quarters of a second to
/// arrive reads as broken rather than liquid.
const Duration _kOpen = Duration(milliseconds: 460);
const Duration _kClose = Duration(milliseconds: 300);

/// A heading's panel is a smaller move, and the second thing asked for.
const Duration _kGroupOpen = Duration(milliseconds: 360);
const Duration _kGroupClose = Duration(milliseconds: 220);

/// Opens the menu over the `Baza` tab, growing out of [button].
///
/// [button] is the menu button's rect in global coordinates and [radius] its
/// corner. [onSelect] hears the page chosen the moment it is tapped — so the
/// page behind is already changing while the glass collapses — and the future
/// completes once the menu is a button again.
Future<void> openDatabaseMenu(
  BuildContext context, {
  required Rect button,
  required double radius,
  required DatabaseSection current,
  required ValueChanged<DatabaseSection> onSelect,
}) async {
  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: radius,
    duration: _kOpen,
    reverseDuration: _kClose,
    // Over the page, not instead of it.
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Menyunu bağla',
    // No barrier colour. The design's backdrop is a blur as well as a tint,
    // and a barrier can only tint, so the panel paints its own.
    builder: (_) => DatabaseMenuPanel(current: current, onSelect: onSelect),
  );

  await Navigator.of(context).push<void>(route);
  // `push` completes the moment the pop starts; `completed` waits for the
  // menu to actually be a button again.
  await route.completed;
}

/// The glyph on the menu button, and on the menu for the first few frames of
/// it growing out of that button — one drawing for both, so the hand-over is
/// seamless.
class DatabaseMenuGlyph extends StatelessWidget {
  const DatabaseMenuGlyph({super.key, required this.button});

  /// The button's side.
  final double button;

  /// The design sets the 28pt glyph on a 42pt button.
  static const double _share = 28 / 42;

  @override
  Widget build(BuildContext context) {
    final double side = button * _share;
    return SvgPicture.asset(
      kDatabaseMenuIcon,
      width: side,
      height: side,
      colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
    );
  }
}

/// The menu itself. Reads the morph when it was pushed through one, and
/// simply sits at rest when it was not.
class DatabaseMenuPanel extends StatefulWidget {
  const DatabaseMenuPanel({
    super.key,
    required this.current,
    required this.onSelect,
  });

  /// The page on screen now, which the menu marks.
  final DatabaseSection current;

  final ValueChanged<DatabaseSection> onSelect;

  @override
  State<DatabaseMenuPanel> createState() => _DatabaseMenuPanelState();
}

class _DatabaseMenuPanelState extends State<DatabaseMenuPanel>
    with SingleTickerProviderStateMixin {
  /// A heading's panel, flying out of its row.
  ///
  /// Built in [initState] rather than lazily: a panel disposed before it ever
  /// built would otherwise create its ticker from inside `dispose`.
  late final AnimationController _group;

  /// The heading whose panel is showing.
  DatabaseGroup? _open;

  /// A heading tapped while another's panel is still collapsing.
  DatabaseGroup? _queued;

  /// Set by the first choice. The glass is on its way home, and a second tap
  /// in the frames before it stops taking them would pop the page under it.
  bool _chosen = false;

  Animation<double>? _flight;

  @override
  void initState() {
    super.initState();
    _group = AnimationController(
      vsync: this,
      duration: _kGroupOpen,
      reverseDuration: _kGroupClose,
    )..addStatusListener(_onGroupStatus);
  }

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
    _group.dispose();
    super.dispose();
  }

  /// The whole menu is going home, so whatever hangs off it goes too.
  void _onFlightStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && _group.value > 0) {
      _queued = null;
      _group.reverse();
    }
  }

  void _onGroupStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    final DatabaseGroup? next = _queued;
    _queued = null;
    if (!mounted) return;
    setState(() => _open = next);
    if (next != null) _group.forward();
  }

  void _tapGroup(DatabaseGroup group) {
    if (_open == group) {
      _group.reverse();
      return;
    }
    if (_open == null) {
      setState(() => _open = group);
      _group.forward();
      return;
    }
    _queued = group;
    _group.reverse();
  }

  void _choose(DatabaseSection section) {
    if (_chosen) return;
    _chosen = true;
    widget.onSelect(section);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final DatabaseMenuMetrics metrics = DatabaseMenuMetrics.of(
      context,
      button: morph?.sourceRect ?? Rect.zero,
    );

    // This route is a *sibling* of the shell, so the one `Material` the
    // signed-in app owns is not above it; `transparency` supplies the text
    // style without painting anything or adding a layer for the lenses to
    // lose their backdrop to.
    //
    // The `Stack` is deliberately bare: everywhere the panels are not is where
    // the barrier has to stay reachable, and a full-bleed hit target here
    // would swallow the tap that closes the menu.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          _Scrim(flight: morph?.progress),
          _MainPanel(
            metrics: metrics,
            current: widget.current,
            open: _open,
            onOverview: () => _choose(DatabaseSection.overview),
            onGroup: _tapGroup,
          ),
          if (_open != null)
            _GroupPanel(
              metrics: metrics,
              group: _open!,
              current: widget.current,
              flight: _group,
              onChoose: _choose,
            ),
        ],
      ),
    );
  }
}

/// The page behind the menu, pushed out of focus.
///
/// Rides the route's own flight, so it comes and goes with the glass. Painted
/// under the lenses, so they sample an already-softened page, and through an
/// `IgnorePointer`, so the tap that closes the menu still reaches the barrier.
/// The blur and the tint are animated on the filter and the colour
/// themselves: an `Opacity` over a `BackdropFilter` would hand it an empty
/// layer to sample.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.flight});

  final Animation<double>? flight;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? flight = this.flight;
    if (flight == null) return _veil(1);
    return AnimatedBuilder(
      animation: flight,
      builder: (BuildContext context, _) =>
          _veil(Curves.easeOut.transform(flight.value.clamp(0.0, 1.0))),
    );
  }

  Widget _veil(double t) {
    if (t <= 0.01) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: kDatabaseMenuBlur * t,
            sigmaY: kDatabaseMenuBlur * t,
          ),
          child: ColoredBox(
            color: kDatabaseMenuScrim.withValues(
              alpha: kDatabaseMenuScrim.a * t,
            ),
          ),
        ),
      ),
    );
  }
}

/// `Detallar` itself: `Əsas panel`, then the headings.
class _MainPanel extends StatelessWidget {
  const _MainPanel({
    required this.metrics,
    required this.current,
    required this.open,
    required this.onOverview,
    required this.onGroup,
  });

  final DatabaseMenuMetrics metrics;
  final DatabaseSection current;
  final DatabaseGroup? open;
  final VoidCallback onOverview;
  final ValueChanged<DatabaseGroup> onGroup;

  @override
  Widget build(BuildContext context) {
    final Rect resting = metrics.mainPanel;
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final Widget content = _entries();

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

  /// What the glass carries while it is still button-shaped: the glyph the
  /// finger pressed, fading out as the menu opens.
  Widget _sourceGlyph() {
    final double side = metrics.button.shortestSide;
    return Center(
      child: SizedBox.square(
        dimension: side,
        child: Center(child: DatabaseMenuGlyph(button: side)),
      ),
    );
  }

  Widget _entries() {
    // One row wears the capsule: the heading whose panel is open or, with
    // none open, wherever the tab is now — `Əsas panel`, or the heading the
    // current page is filed under.
    final DatabaseGroup? marked = open ?? current.group;

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
            height: metrics.titleHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: metrics.titleInset - metrics.padH,
                right: metrics.titleInset - metrics.padH,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detallar',
                  maxLines: 1,
                  style: TextStyle(
                    color: kGlassInk,
                    // CalSans, the app's display face: this menu's title is a
                    // title like the page's own.
                    fontFamily: 'CalSans',
                    fontSize: metrics.titleSize,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _MenuRow(
                    metrics: metrics,
                    label: DatabaseSection.overview.title,
                    height: metrics.rowHeight,
                    marked: open == null && current == DatabaseSection.overview,
                    onTap: onOverview,
                  ),
                  for (final DatabaseGroup group in DatabaseGroup.values)
                    _MenuRow(
                      metrics: metrics,
                      label: group.title,
                      height: metrics.rowHeight,
                      marked: marked == group,
                      onTap: () => onGroup(group),
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

/// One heading's pages, grown out of that heading's row.
class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.metrics,
    required this.group,
    required this.current,
    required this.flight,
    required this.onChoose,
  });

  final DatabaseMenuMetrics metrics;
  final DatabaseGroup group;
  final DatabaseSection current;
  final Animation<double> flight;
  final ValueChanged<DatabaseSection> onChoose;

  @override
  Widget build(BuildContext context) {
    final Rect from = metrics.entryCapsule(1 + group.index);
    final Rect resting = metrics.groupPanel(group);

    return AnimatedBuilder(
      animation: flight,
      child: _sections(),
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
          // The row it grew out of is still drawn in the menu behind it, so
          // this glass leaves its source empty rather than printing the same
          // heading twice.
          source: const SizedBox.shrink(),
          content: child!,
        );
      },
    );
  }

  Widget _sections() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.padH,
        vertical: metrics.groupPadV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final DatabaseSection section in group.sections)
            _MenuRow(
              metrics: metrics,
              label: section.title,
              height: metrics.groupRowHeight,
              marked: section == current,
              onTap: () => onChoose(section),
            ),
        ],
      ),
    );
  }
}

/// One lens, two contents — the filter panel's surface, on this menu's
/// geometry.
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

  /// The panel's size once it has landed. The rows are always laid out
  /// against this and never against the in-flight rect — a menu reflowing
  /// inside a 42pt button would overflow on every frame of the opening.
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
          // Pinned to `liquid_glass_easy`, like the button it grew out of and
          // like the filter it copies — see `kTaskFilterGlass`.
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

/// A row of either panel: a label, and a grey capsule under it when it is
/// marked or under a finger — the press is the design's highlighted row, and
/// what says the tap landed before anything moves.
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.metrics,
    required this.label,
    required this.height,
    required this.marked,
    required this.onTap,
  });

  final DatabaseMenuMetrics metrics;
  final String label;
  final double height;

  /// Wears the capsule: the open heading, or where the tab is now.
  final bool marked;

  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed == down) return;
    setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseMenuMetrics metrics = widget.metrics;
    final double capsule = metrics.capsuleHeight(widget.height);
    final bool lit = widget.marked || _pressed;

    return Semantics(
      button: true,
      selected: widget.marked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: SizedBox(
          height: widget.height,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: (widget.height - capsule) / 2,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: metrics.textInset),
              decoration: ShapeDecoration(
                color: lit
                    ? kDatabaseMenuRowFill
                    : kDatabaseMenuRowFill.withValues(alpha: 0),
                shape: const StadiumBorder(),
              ),
              // A name longer than its panel is set smaller rather than cut:
              // `Menecer Statistikası` has to fit beside the menu on the
              // narrowest phone, and Azerbaijani labels are not cut here.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  style: metrics.labelStyle.copyWith(color: kGlassInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
