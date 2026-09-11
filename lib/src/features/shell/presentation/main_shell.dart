import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/layout.dart';
import '../../../shared/widgets/app_background.dart';
import '../../home/presentation/home_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../data/nav_layout_store.dart';
import '../domain/shell_destination.dart';
import 'more_menu_metrics.dart';
import 'widgets/coming_soon_tab.dart';
import 'widgets/guven_glass_bottom_bar.dart';
import 'widgets/more_menu.dart';

/// The signed-in app: one background, every page, and the glass bar over them.
///
/// The bar holds four page buttons around `Daha çox`; `Daha çox` fans the
/// other eight out over a dimmed screen. Any page button can be picked up with
/// a long press and put somewhere else — along the bar, around the fan, or
/// traded between the two — and the arrangement is kept between launches.
///
/// The page sits under the app-owned glass bar so both the bar and its moving
/// selection lens can refract the actual tab artwork behind them.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.store, this.pageBuilder});

  /// Where the button arrangement is kept. A file, unless a test says
  /// otherwise.
  final NavLayoutStore? store;

  /// Stands in for the real pages, so a test can drive the shell without
  /// the home and task screens going to the network.
  @visibleForTesting
  final Widget Function(ShellDestination page, double bottomReserve)?
  pageBuilder;

  /// Distance from the screen edge to the bar capsule. Down from 18 on
  /// 2026-09-11: every page can sit in the bar now, and the long names need
  /// the room more than the margin does.
  static const double _barSideInset = 12;

  /// Gap between the capsule and the bottom safe area.
  static const double _barBottomGap = 10;

  /// Smallest distance the capsule keeps from the physical screen edge when
  /// there is no system inset to sit above — which is every Android phone now
  /// that `MainActivity` hides the navigation bar.
  static const double _barMinBottomMargin = 16;

  static const double _barHeight = 64;

  /// The bar capsule, in the shell's coordinates — the one measured edge the
  /// `Daha çox` fan is anchored to.
  static Rect barRect(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double side = scaled(context, _barSideInset);
    // `MainActivity` hides Android's navigation bar, so on those phones the
    // bottom inset is now zero and the capsule would sit ten points off the
    // physical edge. A floor keeps it floating rather than resting on the
    // rim, and never shortens the gesture-navigation inset it used to follow.
    final double floor = math.max(
      MediaQuery.paddingOf(context).bottom,
      scaled(context, _barMinBottomMargin),
    );
    final double bottom = screen.height - floor - scaled(context, _barBottomGap);
    return Rect.fromLTRB(
      side,
      bottom - scaled(context, _barHeight),
      screen.width - side,
      bottom,
    );
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

/// A page button being carried by a finger, and then flown home.
class _NavDrag {
  _NavDrag({
    required this.item,
    required this.origin,
    required this.pointer,
    required this.grab,
    required this.pointerId,
  });

  final ShellDestination item;

  /// Where it was picked up from, in the committed layout.
  final NavSlot origin;
  final int? pointerId;

  /// The finger, in the shell's coordinates.
  Offset pointer;

  /// From the finger to the disc's centre, kept for the whole carry so the
  /// disc does not jump to sit under the fingertip.
  final Offset grab;

  /// The slot it would land in if let go now.
  NavSlot? target;

  /// Set once the finger is gone: the disc is flying from here to there.
  Offset? landFrom;
  Offset? landTo;
  bool landsInBar = false;

  bool get landing => landTo != null;
  Offset get carried => pointer + grab;
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late final NavLayoutStore _store = widget.store ?? FileNavLayoutStore();
  ShellNavLayout _layout = ShellNavLayout.defaults;

  /// Set by the first rearrangement, so a saved layout that arrives late
  /// does not overwrite one the user has just made.
  bool _rearranged = false;

  /// The page on screen, wherever its button is.
  ShellDestination _current = ShellDestination.home;

  bool _menuOpen = false;

  late final AnimationController _menu = AnimationController(
    vsync: this,
    duration: MoreMenu.openDuration(ShellNavLayout.defaults.more.length),
    reverseDuration: MoreMenu.closeDuration,
  );

  /// `Daha çox`'s glyph empties in the first stretch of the opening, before
  /// the first button is far from it.
  /// Played backwards, it fills again only once they are nearly all home.
  late final Animation<double> _menuGlyph = CurvedAnimation(
    parent: _menu,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );

  /// The disc swelling off the surface as it is picked up.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  /// The disc's flight to wherever it was let go over.
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  final GlobalKey _stackKey = GlobalKey();
  _NavDrag? _drag;
  int? _lastPointer;

  /// Bumped as the finger moves. Only the carried disc listens; the shell
  /// itself rebuilds only when the slot under the disc changes.
  final ValueNotifier<int> _carry = ValueNotifier<int>(0);

  /// The bar's glyphs. Raised from 22 on 2026-09-11 to the design's own
  /// proportion — the glyph is a little under half the bar's height.
  static const double _barIconSize = 28;

  /// The bar's labels. Down from 10 on 2026-09-11, once the glyphs had grown:
  /// the name is the glyph's caption, not its equal. The marker is sized from
  /// the measured label, so it narrows with it. Any name that still does not
  /// fit beside its neighbours is scaled down further by the bar itself.
  static const double _barLabelSize = 8.5;

  /// How far the disc swells while it is carried.
  static const double _liftScale = 1.12;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final ShellNavLayout? saved = await _store.load();
    if (!mounted || saved == null || _rearranged) return;
    setState(() => _layout = saved);
  }

  @override
  void dispose() {
    _menu.dispose();
    _lift.dispose();
    _land.dispose();
    _carry.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- geometry

  Rect _barRect(BuildContext context) => MainShell.barRect(context);

  MoreMenuMetrics _metrics(BuildContext context) => MoreMenuMetrics.of(
    context,
    bar: _barRect(context),
    count: _layout.more.length,
  );

  Offset _cellCenter(Rect bar, int cell) => Offset(
    bar.left + bar.width / ShellNavLayout.cellCount * (cell + 0.5),
    bar.center.dy,
  );

  /// Where a button sitting in [slot] is drawn.
  Offset _slotCenter(NavSlot slot) => slot.shelf == NavShelf.bar
      ? _cellCenter(_barRect(context), ShellNavLayout.cellOf(slot.index))
      : _metrics(context).center(slot.index);

  Offset _toLocal(Offset global) {
    final RenderObject? box = _stackKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  // ------------------------------------------------------------------ layout

  /// What is drawn: the committed layout, or — while a button is carried
  /// over a slot — the layout it would make if it were dropped there.
  ShellNavLayout get _shown {
    final _NavDrag? drag = _drag;
    final NavSlot? target = drag?.target;
    if (drag == null || target == null) return _layout;
    return _layout.moved(drag.origin, target);
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final Rect bar = _barRect(context);
    final MoreMenuMetrics metrics = _metrics(context);
    // What the page has to keep clear at the bottom. The bar floats over the
    // content, so nothing in the layout knows about it unless it is told.
    final double reserve =
        MediaQuery.sizeOf(context).height - bar.top + scaled(context, 12);
    final ShellNavLayout shown = _shown;
    final _NavDrag? drag = _drag;

    final List<String> labels = <String>[];
    final List<String> icons = <String>[];
    for (int cell = 0; cell < ShellNavLayout.cellCount; cell++) {
      final int? page = ShellNavLayout.barIndexOfCell(cell);
      labels.add(page == null ? kMenuTitle : shown.bar[page].title);
      icons.add(page == null ? kMenuIcon : shown.bar[page].icon);
    }

    // A page whose button is in the fan is marked by `Daha çox` — the button
    // that leads to it.
    final int selected = _menuOpen
        ? ShellNavLayout.menuCell
        : shown.cellOfDestination(_current) ?? ShellNavLayout.menuCell;

    // A disc flying home to the bar hands straight back to the cell's own
    // glyph; one flying home to the fan becomes the button it lands on.
    final int? liftedCell = drag == null || (drag.landing && drag.landsInBar)
        ? null
        : shown.cellOfDestination(drag.item);

    return AppBackground(
      // The tabs are not Scaffolds — the background and the nav bar are shared
      // and live out here — so this is the only Material in the signed-in
      // tree. Without one, `Text` falls back to the framework's yellow-striped
      // debug style and `RefreshIndicator`/`TextButton` have no ink surface.
      // `transparency` paints nothing and, at the default `Clip.none`, adds no
      // layer for the lenses below to lose their backdrop to.
      child: Material(
        type: MaterialType.transparency,
        child: PopScope<Object?>(
          // Back shuts the fan before it leaves anything.
          canPop: !_menuOpen,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop && _menuOpen) _closeMenu();
          },
          // A carried button is followed from up here rather than by the
          // widget it was picked up from: mid-drag that widget can leave the
          // tree — a fan button traded into the bar is no longer a fan button
          // — and its own recognizer would go with it.
          child: Listener(
            onPointerDown: (PointerDownEvent event) =>
                _lastPointer = event.pointer,
            onPointerMove: _onPointerMove,
            onPointerUp: (PointerUpEvent event) => _onPointerEnd(event.pointer),
            onPointerCancel: (PointerCancelEvent event) =>
                _onPointerEnd(event.pointer),
            child: Stack(
              key: _stackKey,
              fit: StackFit.expand,
              children: <Widget>[
                _pages(reserve),
                MoreMenu(
                  metrics: metrics,
                  open: _menu,
                  items: shown.more,
                  lifted: drag == null || (drag.landing && drag.landsInBar)
                      ? null
                      : drag.item,
                  interactive: _menuOpen,
                  onChoose: _choose,
                  onLift: _liftFromMenu,
                  onDismiss: _closeMenu,
                ),
                Positioned.fromRect(
                  rect: bar,
                  child: GuvenGlassBottomBar(
                    labels: labels,
                    icons: icons,
                    selectedIndex: selected,
                    onSelected: _onBarSelected,
                    height: bar.height,
                    iconSize: scaled(context, _barIconSize),
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: scaled(context, _barLabelSize),
                      height: 1.1,
                      // Set here rather than left to the theme, whose body
                      // style tracks out by 0.25 — two or three points on a
                      // long name, which this bar does not have to spare.
                      letterSpacing: 0,
                    ),
                    menuIndex: ShellNavLayout.menuCell,
                    menuOpenIcon: kMenuOpenIcon,
                    menuOpen: _menuGlyph,
                    liftedIndex: liftedCell,
                    onLiftStart: _liftFromBar,
                  ),
                ),
                if (drag != null) _carriedDisc(drag, metrics),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Every page is kept alive once built, in declaration order — never in
  /// button order, so rearranging the buttons cannot rebuild a page or send
  /// the home screen back to the network.
  Widget _pages(double reserve) {
    return IndexedStack(
      index: _current.index,
      children: <Widget>[
        for (final ShellDestination page in ShellDestination.values)
          _page(page, reserve),
      ],
    );
  }

  Widget _page(ShellDestination page, double reserve) {
    final Widget Function(ShellDestination, double)? builder =
        widget.pageBuilder;
    if (builder != null) return builder(page, reserve);
    return switch (page) {
      ShellDestination.home => HomeScreen(bottomReserve: reserve),
      ShellDestination.tasks => TasksScreen(
        bottomReserve: reserve,
        active: _current == ShellDestination.tasks,
      ),
      // Every other page is a button for now; its screen comes later.
      _ => ComingSoonTab(title: page.title, bottomReserve: reserve),
    };
  }

  Widget _carriedDisc(_NavDrag drag, MoreMenuMetrics metrics) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_lift, _land, _carry]),
      builder: (BuildContext context, Widget? child) {
        final Offset center;
        final double scale;
        double opacity = 1;
        if (drag.landing) {
          final double t = Curves.easeOutCubic.transform(_land.value);
          center = Offset.lerp(drag.landFrom, drag.landTo, t)!;
          // Into the fan it settles to a button's size; into the bar it
          // shrinks away over the glyph that is taking its place.
          scale = lerpDouble(_liftScale, drag.landsInBar ? 0.5 : 1, t)!;
          if (drag.landsInBar) opacity = 1 - t;
        } else {
          center = drag.carried;
          scale = lerpDouble(
            1,
            _liftScale,
            Curves.easeOutBack.transform(_lift.value),
          )!;
        }
        final double disc = metrics.bubble;
        return Positioned(
          left: center.dx - disc / 2,
          top: center.dy - disc / 2,
          width: disc,
          height: disc,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: MoreMenuDisc(item: drag.item, metrics: metrics, lifted: true),
    );
  }

  // ------------------------------------------------------------- navigation

  void _onBarSelected(int cell) {
    if (_drag != null) return;
    final int? page = ShellNavLayout.barIndexOfCell(cell);
    if (page == null) {
      _menuOpen ? _closeMenu() : _openMenu();
      return;
    }
    final ShellDestination next = _shown.bar[page];
    if (next == _current && !_menuOpen) return;
    setState(() => _current = next);
    if (_menuOpen) _closeMenu();
  }

  void _choose(ShellDestination page) {
    if (_drag != null) return;
    setState(() => _current = page);
    _closeMenu();
  }

  void _openMenu() {
    if (_menuOpen) return;
    setState(() => _menuOpen = true);
    _menu.forward();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    // A button still under a finger goes back where it came from.
    final _NavDrag? drag = _drag;
    if (drag != null && !drag.landing) {
      _land.stop();
      _drag = null;
    }
    setState(() => _menuOpen = false);
    _menu.reverse();
  }

  // ------------------------------------------------------------------- drag

  void _liftFromBar(int cell, Offset global) {
    final int? page = ShellNavLayout.barIndexOfCell(cell);
    // `Daha çox` stays where it is: the fan grows out of it.
    if (page == null) return;
    _beginDrag(
      item: _layout.bar[page],
      origin: NavSlot(NavShelf.bar, page),
      global: global,
      center: _cellCenter(_barRect(context), cell),
    );
  }

  void _liftFromMenu(ShellDestination item, Offset global) {
    if (!_menuOpen) return;
    final int index = _layout.more.indexOf(item);
    if (index < 0) return;
    _beginDrag(
      item: item,
      origin: NavSlot(NavShelf.more, index),
      global: global,
      center: _metrics(context).center(index),
    );
  }

  void _beginDrag({
    required ShellDestination item,
    required NavSlot origin,
    required Offset global,
    required Offset center,
  }) {
    // A disc still flying home from the last drop is simply put down.
    if (_drag != null) {
      _land.stop();
      _drag = null;
    }
    final Offset pointer = _toLocal(global);
    HapticFeedback.mediumImpact();
    setState(() {
      _drag = _NavDrag(
        item: item,
        origin: origin,
        pointer: pointer,
        grab: center - pointer,
        pointerId: _lastPointer,
      );
    });
    _lift.forward(from: 0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final _NavDrag? drag = _drag;
    if (drag == null || drag.landing) return;
    if (drag.pointerId != null && event.pointer != drag.pointerId) return;
    drag.pointer = _toLocal(event.position);
    final NavSlot? target = _targetFor(drag.carried);
    if (target == drag.target) {
      _carry.value++;
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => drag.target = target);
  }

  /// The slot a disc at [point] would drop into, if any.
  ///
  /// Over the bar — or anywhere below its top edge — it is the nearest page
  /// cell, so crossing `Daha çox` on the way along the bar moves past it
  /// rather than dropping out. Over the open fan it is the nearest slot.
  /// Anywhere else, nothing: let go there and the button goes back.
  NavSlot? _targetFor(Offset point) {
    final Rect bar = _barRect(context);
    final double reach = scaled(context, 20);
    if (point.dy >= bar.top - reach &&
        point.dx >= bar.left - reach &&
        point.dx <= bar.right + reach) {
      int best = 0;
      double bestDistance = double.infinity;
      for (int page = 0; page < ShellNavLayout.barPageCount; page++) {
        final double distance =
            (_cellCenter(bar, ShellNavLayout.cellOf(page)).dx - point.dx)
                .abs();
        if (distance < bestDistance) {
          best = page;
          bestDistance = distance;
        }
      }
      return NavSlot(NavShelf.bar, best);
    }
    if (_menuOpen) {
      final int? slot = _metrics(context).slotAt(point);
      if (slot != null) return NavSlot(NavShelf.more, slot);
    }
    return null;
  }

  void _onPointerEnd(int pointer) {
    final _NavDrag? drag = _drag;
    if (drag == null || drag.landing) return;
    if (drag.pointerId != null && pointer != drag.pointerId) return;

    final NavSlot? target = drag.target;
    final ShellNavLayout next = target == null
        ? _layout
        : _layout.moved(drag.origin, target);
    final NavSlot home = target ?? drag.origin;
    final bool changed = next != _layout;

    setState(() {
      _layout = next;
      drag
        ..target = null
        ..landFrom = drag.carried
        ..landTo = _slotCenter(home)
        ..landsInBar = home.shelf == NavShelf.bar;
    });
    if (changed) {
      _rearranged = true;
      unawaited(_store.save(next));
    }
    _land.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && _drag == drag) setState(() => _drag = null);
    });
  }
}
