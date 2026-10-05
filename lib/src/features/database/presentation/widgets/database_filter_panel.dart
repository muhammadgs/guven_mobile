/// `Filter` over a `Baza` list: the funnel's glass grows into the list of
/// columns, and choosing a column turns that same pane into the column's
/// values — a back button, a search field, `Hamısı` and the values.
///
/// One panel for every page with a funnel — `Satışlar`' and `Məhsullar`'
/// nine columns, `Stok`'s and `Sifarişlər`' five alike. It knows nothing
/// about the rows it narrows: the page hands it a [DatabaseFilterSource],
/// which says what the columns are, which values are chosen, and where each
/// column's values come from. A column of figures a
/// [DatabaseRangeFilterSource] says takes a span opens onto a minimum and a
/// maximum instead of a list.
///
/// The task filter opens a second panel beside the first. This one does
/// not: the design keeps one pane and changes what is in it, which leaves the
/// whole width for long customer names and room for a keyboard under it. It
/// is still one lens the whole way — the funnel's glass *becomes* the panel,
/// and the panel's glass stretches from one page to the other — and nothing
/// above a lens ever fades: only what is inside it does.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../../tasks/presentation/widgets/task_tools.dart' show FunnelPainter;
import '../../application/database_filter_source.dart';
import '../../domain/database_filter.dart';
import '../database_filter_metrics.dart';
import 'database_glass.dart';
import 'database_menu.dart' show DatabaseScrim;

/// The filter's and `Detallar`'s timings: a menu that takes three quarters
/// of a second to arrive reads as broken rather than liquid.
const Duration _kOpen = Duration(milliseconds: 460);
const Duration _kClose = Duration(milliseconds: 300);

/// Columns to values and back: a smaller move, inside a panel already open.
const Duration _kPageOpen = Duration(milliseconds: 380);
const Duration _kPageClose = Duration(milliseconds: 300);

/// The values panel following its list as it is typed into.
const Duration _kResize = Duration(milliseconds: 220);

/// How long typing a span has to pause before the list is narrowed to it.
const Duration _kRangeDelay = Duration(milliseconds: 450);

/// Opens [source]'s filter, growing out of the funnel at [button].
///
/// [origin] is where the panel's top-left corner wants to be — the left of
/// the page's buttons, at their top. Completes once the panel is a button
/// again.
Future<void> openDatabaseFilter(
  BuildContext context, {
  required Rect button,
  required double radius,
  required Offset origin,
  required DatabaseFilterSource source,
}) async {
  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: radius,
    duration: _kOpen,
    reverseDuration: _kClose,
    // Over the page, not instead of it: the list narrows behind the glass
    // as values are chosen.
    opaque: false,
    barrierDismissible: true,
    barrierLabel: 'Filtri bağla',
    // No barrier colour: the design blurs the page as well as tinting it,
    // and a barrier can only tint, so the panel paints its own.
    builder: (_) => DatabaseFilterPanel(source: source, origin: origin),
  );

  await Navigator.of(context).push<void>(route);
  // `push` completes the moment the pop starts; `completed` waits for the
  // panel to actually be a button again.
  await route.completed;
}

/// The panel. Reads the morph when it was pushed through one, and sits at
/// rest when it was not.
class DatabaseFilterPanel extends StatefulWidget {
  const DatabaseFilterPanel({
    super.key,
    required this.source,
    required this.origin,
  });

  final DatabaseFilterSource source;
  final Offset origin;

  @override
  State<DatabaseFilterPanel> createState() => _DatabaseFilterPanelState();
}

class _DatabaseFilterPanelState extends State<DatabaseFilterPanel>
    with SingleTickerProviderStateMixin {
  /// 0 is the columns, 1 a column's values.
  ///
  /// Built in [initState] rather than lazily: a panel disposed before it
  /// ever built would otherwise create its ticker from inside `dispose`.
  late final AnimationController _page;

  /// The column whose values are showing — kept while they fade out, so
  /// there is something to fade.
  DatabaseFilterColumn? _column;

  final TextEditingController _query = TextEditingController();
  final FocusNode _search = FocusNode();

  /// The open column's span fields, when it is narrowed by a span rather
  /// than by one of its values — and null otherwise.
  FilterRangeField? _field;
  final TextEditingController _min = TextEditingController();
  final TextEditingController _max = TextEditingController();
  final FocusNode _minFocus = FocusNode();
  final FocusNode _maxFocus = FocusNode();

  /// A span typed but not yet handed to the list: typing is let pause
  /// before the list is narrowed, so `150` is not first narrowed to `1`
  /// and then to `15`.
  Timer? _rangeDebounce;

  /// Set while the fields are filled in or cleared from here, which is not
  /// somebody typing.
  bool _quiet = false;

  Animation<double>? _flight;

  DatabaseFilterValues get _values => widget.source.filterValues;

  /// The source, when some of its columns take a span.
  DatabaseRangeFilterSource? get _ranges {
    final DatabaseFilterSource source = widget.source;
    return source is DatabaseRangeFilterSource ? source : null;
  }

  @override
  void initState() {
    super.initState();
    _page = AnimationController(
      vsync: this,
      duration: _kPageOpen,
      reverseDuration: _kPageClose,
    )..addStatusListener(_onPageStatus);
    _query.addListener(_onQuery);
    _min.addListener(_onRange);
    _max.addListener(_onRange);
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
    // A span typed a moment before the glass was closed still narrows the
    // list: closing is not taking it back.
    _flushRange();
    _flight?.removeStatusListener(_onFlightStatus);
    _page.dispose();
    _query.dispose();
    _search.dispose();
    _min.dispose();
    _max.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    _values.close();
    super.dispose();
  }

  void _onFlightStatus(AnimationStatus status) {
    // The keyboard goes down with the glass, not after it.
    if (status == AnimationStatus.reverse) {
      _unfocus();
      _flushRange();
    }
    // Settling decides whether the panel eases into a new size or jumps
    // with the flight.
    if (mounted) setState(() {});
  }

  void _onPageStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.dismissed) {
      _values.close();
      _column = null;
      _field = null;
    }
    setState(() {});
  }

  void _unfocus() {
    _search.unfocus();
    _minFocus.unfocus();
    _maxFocus.unfocus();
  }

  void _onQuery() => _values.search(_query.text);

  void _openColumn(DatabaseFilterColumn column) {
    if (_page.value > 0) return;
    final FilterRangeField? field = _ranges?.rangeFieldOf(column);
    _values.open(column);
    _query.clear();
    if (field != null) _fillRange(_ranges!.rangeOf(column));
    setState(() {
      _column = column;
      _field = field;
    });
    _page.forward();
  }

  void _back() {
    _unfocus();
    _flushRange();
    _page.reverse();
  }

  void _choose(FilterValue value) {
    final DatabaseFilterColumn? column = _column;
    if (column == null) return;
    _unfocus();
    // A value and a span are one or the other: `ƏDV yoxdur` empties the
    // fields, and the source keeps the value when told the span is empty.
    if (_field != null) _fillRange(FilterRange.any);
    _values.remember(value.value);
    widget.source.toggleFilter(column, value.value);
  }

  void _chooseAll() {
    final DatabaseFilterColumn? column = _column;
    if (column == null) return;
    _unfocus();
    if (_field != null) _fillRange(FilterRange.any);
    widget.source.clearFilterColumn(column);
  }

  // ── A span ─────────────────────────────────────────────────────────────

  /// Writes [range] into the fields without it counting as typing.
  void _fillRange(FilterRange range) {
    _rangeDebounce?.cancel();
    _rangeDebounce = null;
    _quiet = true;
    _min.text = range.min == null ? '' : writeFilterFigure(range.min!);
    _max.text = range.max == null ? '' : writeFilterFigure(range.max!);
    _quiet = false;
  }

  void _onRange() {
    if (_quiet || _field == null) return;
    _rangeDebounce?.cancel();
    _rangeDebounce = Timer(_kRangeDelay, _flushRange);
  }

  /// Hands what is typed to the list now, if it has not been yet.
  void _flushRange() {
    final Timer? pending = _rangeDebounce;
    if (pending == null) return;
    pending.cancel();
    _rangeDebounce = null;
    final DatabaseRangeFilterSource? ranges = _ranges;
    final DatabaseFilterColumn? column = _column;
    if (ranges == null || column == null) return;
    ranges.setRange(
      column,
      FilterRange(
        min: parseFilterFigure(_min.text),
        max: parseFilterFigure(_max.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final DatabaseFilterMetrics metrics = DatabaseFilterMetrics.of(
      context,
      origin: widget.origin,
      columnCount: widget.source.filterColumns.length,
    );

    // This route is a *sibling* of the shell, so the one `Material` the
    // signed-in app owns is not above it; `transparency` supplies the text
    // style without painting anything or adding a layer for the lens to
    // lose its backdrop to.
    //
    // The `Stack` is deliberately bare: everywhere the panel is not is where
    // the barrier has to stay reachable, and a full-bleed hit target here
    // would swallow the tap that closes the filter.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          DatabaseScrim(flight: morph?.progress),
          ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[widget.source, _values]),
            builder: (BuildContext context, _) =>
                _panel(context, metrics, morph),
          ),
        ],
      ),
    );
  }

  Widget _panel(
    BuildContext context,
    DatabaseFilterMetrics metrics,
    GlassMorph? morph,
  ) {
    final DatabaseFilterColumn? column = _column;
    final FilterRangeField? field = _field;
    final List<FilterValue> values = column == null
        ? const <FilterValue>[]
        : _values.values;
    final double measured = metrics.valuesContentHeight(<String>[
      for (final FilterValue value in values) value.label,
    ]);
    final Rect valuesTarget = field != null
        // A span lists nothing but what it offers beside the span.
        ? metrics.rangePanel(measured)
        : metrics.valuesPanel(values.isEmpty ? metrics.valueRowMin : measured);
    final bool settled =
        _page.isCompleted && (morph == null || morph.progress.isCompleted);

    final Widget columns = _ColumnsPage(
      metrics: metrics,
      source: widget.source,
      onColumn: _openColumn,
    );

    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: valuesTarget),
      // A new list eases the panel to its new height; while the glass is
      // flying it follows the flight exactly.
      duration: settled ? _kResize : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Rect? valuesRect, _) {
        final Rect shown = valuesRect ?? valuesTarget;
        final Widget valuesPage = column == null
            ? const SizedBox.shrink()
            : field != null
            ? _RangePage(
                metrics: metrics,
                column: column,
                field: field,
                values: values,
                source: widget.source,
                min: _min,
                max: _max,
                minFocus: _minFocus,
                maxFocus: _maxFocus,
                onBack: _back,
                onAll: _chooseAll,
                onValue: _choose,
                onDone: _flushRange,
              )
            : _ValuesPage(
                metrics: metrics,
                column: column,
                values: values,
                source: widget.source,
                searching: _values.isSearching,
                progress: _values.progress,
                query: _query,
                focus: _search,
                onBack: _back,
                onAll: _chooseAll,
                onValue: _choose,
              );

        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_page, ?morph?.progress]),
          builder: (BuildContext context, _) => _surface(
            metrics: metrics,
            morph: morph,
            columnsRect: metrics.columnsPanel,
            valuesRect: shown,
            valuesSize: valuesTarget.size,
            columns: columns,
            values: valuesPage,
          ),
        );
      },
    );
  }

  Widget _surface({
    required DatabaseFilterMetrics metrics,
    required GlassMorph? morph,
    required Rect columnsRect,
    required Rect valuesRect,
    required Size valuesSize,
    required Widget columns,
    required Widget values,
  }) {
    // Columns to values, inside the panel.
    final GlassMorphFrame page = resolveGlassMorph(
      progress: _page,
      from: columnsRect,
      fromRadius: metrics.columnsRadius,
      to: valuesRect,
      toRadius: metrics.valuesRadius,
    );
    // The funnel to the panel, whichever page it is on.
    final GlassMorphFrame frame = morph == null
        ? GlassMorphFrame.settled(page.rect, page.radius)
        : resolveGlassMorph(
            progress: morph.progress,
            from: morph.sourceRect,
            fromRadius: morph.sourceRadius,
            to: page.rect,
            toRadius: page.radius,
          );

    final bool open = frame.isSettled;
    final double shown = frame.targetOpacity;
    final double pageT = _page.value;

    // `Filter` is one title for both pages: it stays, and only slides to
    // where the values page sets it.
    final double titleInset = lerpDouble(
      metrics.columnsTitleInset,
      metrics.valuesTitleInset,
      page.blend,
    )!;
    // Measured against the page's own width, not the flight's: the title
    // must not shrink while the glass is still button-sized.
    final bool resetShows = widget.source.isFiltered;
    final double titleRoom =
        (page.rect.width - titleInset - metrics.padH) -
        (resetShows ? (1 - page.blend) * metrics.resetRoom : 0);

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
          // Pinned to `liquid_glass_easy`, like the funnel it grew out of —
          // see `kTaskFilterGlass`.
          backend: AppGlassBackend.easy,
          style: lerpAppGlassStyle(
            kTaskToolGlass,
            kTaskFilterGlass,
            frame.blend,
            cornerRadius: frame.radius,
          ),
          cornerRadius: frame.radius,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(frame.radius),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (frame.sourceOpacity > 0.01)
                  Opacity(
                    opacity: frame.sourceOpacity,
                    child: blurred(
                      6 * (1 - frame.sourceOpacity),
                      Center(
                        child: CustomPaint(
                          painter: FunnelPainter(
                            morph?.sourceRect.shortestSide ?? 0,
                          ),
                          size: Size.square(
                            morph?.sourceRect.shortestSide ?? 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (shown > 0.01 && page.sourceOpacity > 0.01)
                  _Layer(
                    size: columnsRect.size,
                    opacity: shown * page.sourceOpacity,
                    lift: 1 - shown,
                    // Taps only once the panel has landed on this page.
                    active: open && pageT == 0,
                    child: columns,
                  ),
                if (shown > 0.01 && page.targetOpacity > 0.01)
                  _Layer(
                    size: valuesSize,
                    opacity: shown * page.targetOpacity,
                    lift: 1 - shown,
                    active: open && pageT == 1,
                    child: values,
                  ),
                if (shown > 0.01)
                  Positioned(
                    left: titleInset,
                    top: metrics.padTop,
                    height: metrics.titleHeight,
                    width: math.max(0, titleRoom),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: shown,
                        child: _Title(metrics: metrics),
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

/// One page's content, laid out against the size it lands at — never the
/// in-flight rect, or the rows would reflow inside a 42pt button on every
/// frame of the opening — and anchored top-left, where both pages begin.
class _Layer extends StatelessWidget {
  const _Layer({
    required this.size,
    required this.opacity,
    required this.lift,
    required this.active,
    required this.child,
  });

  final Size size;
  final double opacity;

  /// How far the content still has to condense in, 0 once it has.
  final double lift;

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: blurred(
            10 * lift,
            Transform.translate(offset: Offset(0, 14 * lift), child: child),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.metrics});

  final DatabaseFilterMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        'Filter',
        maxLines: 1,
        style: TextStyle(
          color: kGlassInk,
          // CalSans, the app's display face — `Detallar`'s title, at
          // `Detallar`'s size.
          fontFamily: 'CalSans',
          fontSize: metrics.titleSize,
          height: 1.05,
          letterSpacing: -0.8,
        ),
      ),
    );
  }
}

/// The columns: the design's first panel.
class _ColumnsPage extends StatelessWidget {
  const _ColumnsPage({
    required this.metrics,
    required this.source,
    required this.onColumn,
  });

  final DatabaseFilterMetrics metrics;
  final DatabaseFilterSource source;
  final ValueChanged<DatabaseFilterColumn> onColumn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.padH,
        metrics.padTop,
        metrics.padH,
        metrics.columnsPadBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: metrics.titleHeight,
            child: Align(
              alignment: Alignment.centerRight,
              // `Sıfırla` sits in the title's line rather than under the last
              // column, the task filter's reason: it comes and goes with the
              // choices, and a row that came and went would resize the panel
              // under the finger that had just tapped.
              child: source.isFiltered
                  ? _ResetChip(metrics: metrics, onTap: source.clearFilter)
                  : const SizedBox.shrink(),
            ),
          ),
          for (final DatabaseFilterColumn column in source.filterColumns)
            _Row(
              height: metrics.rowHeight,
              capsuleHeight: metrics.capsuleHeight,
              inset: metrics.textInset,
              marked: source.narrows(column),
              markFill: kDatabaseFilterRowFill,
              pressFill: kDatabaseFilterPressFill,
              onTap: () => onColumn(column),
              semanticsSelected: source.narrows(column),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  column.label,
                  maxLines: 1,
                  softWrap: false,
                  style: metrics.labelStyle.copyWith(
                    color: kGlassInk,
                    height: 1.15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A column's values: back, search, `Hamısı`, and the values — five and a
/// half of them at a time.
class _ValuesPage extends StatelessWidget {
  const _ValuesPage({
    required this.metrics,
    required this.column,
    required this.values,
    required this.source,
    required this.searching,
    required this.progress,
    required this.query,
    required this.focus,
    required this.onBack,
    required this.onAll,
    required this.onValue,
  });

  final DatabaseFilterMetrics metrics;
  final DatabaseFilterColumn column;
  final List<FilterValue> values;
  final DatabaseFilterSource source;
  final bool searching;

  /// Said in place of the list while its values are still being gathered.
  final String? progress;

  final TextEditingController query;
  final FocusNode focus;
  final VoidCallback onBack;
  final VoidCallback onAll;
  final ValueChanged<FilterValue> onValue;

  @override
  Widget build(BuildContext context) {
    final double control = metrics.controlSize;

    return Padding(
      padding: EdgeInsets.only(
        top: metrics.padTop + metrics.titleHeight + metrics.controlGap,
        bottom: metrics.valuesPadBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.controlInset),
            child: SizedBox(
              height: control,
              child: Row(
                children: <Widget>[
                  _BackButton(side: control, onTap: onBack),
                  SizedBox(width: metrics.controlSpacing),
                  Expanded(
                    child: _SearchField(
                      metrics: metrics,
                      hint: column.label,
                      controller: query,
                      focus: focus,
                      searching: searching,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: metrics.listGap),
          _ValueRow(
            metrics: metrics,
            label: 'Hamısı',
            chosen: !source.narrows(column),
            onTap: onAll,
          ),
          // Whatever the panel leaves under `Hamısı`: the metrics sized the
          // panel for five and a half rows, and the list takes exactly that.
          Expanded(
            child: values.isEmpty
                ? _Nothing(
                    metrics: metrics,
                    searching: searching,
                    progress: progress,
                  )
                : ScrollConfiguration(
                    // A stretch at the ends would draw the list into a layer
                    // of its own inside the glass; the list simply stops.
                    behavior: const MaterialScrollBehavior().copyWith(
                      overscroll: false,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: values.length,
                      itemBuilder: (BuildContext context, int index) {
                        final FilterValue value = values[index];
                        return _ValueRow(
                          key: ValueKey<String>(value.value),
                          metrics: metrics,
                          label: value.label,
                          chosen: source.isChosen(column, value.value),
                          onTap: () => onValue(value),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A column narrowed by a span: back, the minimum's field beside it and the
/// maximum's under that, then `Hamısı` and whatever the column offers
/// beside its span.
///
/// The values page's own parts, rearranged — the search field's capsule
/// becomes the two fields, and the list is only what is left over — so the
/// two read as one panel. The user asked for exactly this in place of a list
/// of every price (2026-09-29): nobody picks a price out of hundreds.
class _RangePage extends StatelessWidget {
  const _RangePage({
    required this.metrics,
    required this.column,
    required this.field,
    required this.values,
    required this.source,
    required this.min,
    required this.max,
    required this.minFocus,
    required this.maxFocus,
    required this.onBack,
    required this.onAll,
    required this.onValue,
    required this.onDone,
  });

  final DatabaseFilterMetrics metrics;
  final DatabaseFilterColumn column;
  final FilterRangeField field;

  /// Offered beside the span: `ƏDV yoxdur`, or nothing.
  final List<FilterValue> values;

  final DatabaseFilterSource source;
  final TextEditingController min;
  final TextEditingController max;
  final FocusNode minFocus;
  final FocusNode maxFocus;
  final VoidCallback onBack;
  final VoidCallback onAll;
  final ValueChanged<FilterValue> onValue;

  /// Typing is finished: the list is narrowed at once.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final double control = metrics.controlSize;

    return Padding(
      padding: EdgeInsets.only(
        top: metrics.padTop + metrics.titleHeight + metrics.controlGap,
        bottom: metrics.valuesPadBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.controlInset),
            child: SizedBox(
              height: control,
              child: Row(
                children: <Widget>[
                  _BackButton(side: control, onTap: onBack),
                  SizedBox(width: metrics.controlSpacing),
                  Expanded(
                    child: _FigureField(
                      metrics: metrics,
                      hint: field.minHint,
                      suffix: field.suffix,
                      signed: field.signed,
                      controller: min,
                      focus: minFocus,
                      action: TextInputAction.next,
                      onSubmitted: maxFocus.requestFocus,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: metrics.controlSpacing),
          Padding(
            padding: EdgeInsets.only(
              // Under the minimum, not under the back button: the two
              // fields line up as a pair.
              left: metrics.controlInset + control + metrics.controlSpacing,
              right: metrics.controlInset,
            ),
            child: SizedBox(
              height: control,
              child: _FigureField(
                metrics: metrics,
                hint: field.maxHint,
                suffix: field.suffix,
                signed: field.signed,
                controller: max,
                focus: maxFocus,
                action: TextInputAction.done,
                onSubmitted: () {
                  maxFocus.unfocus();
                  onDone();
                },
              ),
            ),
          ),
          SizedBox(height: metrics.listGap),
          // Only a keyboard on a short phone leaves this less room than it
          // needs; then it scrolls rather than spilling off the glass.
          Expanded(
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                overscroll: false,
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: <Widget>[
                  _ValueRow(
                    metrics: metrics,
                    label: 'Hamısı',
                    chosen: !source.narrows(column),
                    onTap: onAll,
                  ),
                  for (final FilterValue value in values)
                    _ValueRow(
                      key: ValueKey<String>(value.value),
                      metrics: metrics,
                      label: value.label,
                      chosen: source.isChosen(column, value.value),
                      onTap: () => onValue(value),
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

/// One end of a span: a figure typed on the number keys, what it is in
/// (`₼`, `%`) after it while it is empty, and a way to clear it once it is
/// not.
class _FigureField extends StatelessWidget {
  const _FigureField({
    required this.metrics,
    required this.hint,
    required this.suffix,
    required this.signed,
    required this.controller,
    required this.focus,
    required this.action,
    required this.onSubmitted,
  });

  final DatabaseFilterMetrics metrics;
  final String hint;
  final String? suffix;
  final bool signed;
  final TextEditingController controller;
  final FocusNode focus;
  final TextInputAction action;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final double side = metrics.controlSize;
    final TextStyle style = metrics.labelStyle.copyWith(
      color: kGlassInk,
      height: 1.2,
    );
    final String? suffix = this.suffix;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: Container(
        height: side,
        decoration: const ShapeDecoration(
          color: kDatabaseFilterControlFill,
          shape: StadiumBorder(),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: side * 0.42),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                style: style,
                cursorColor: kGlassInk,
                cursorWidth: 1.6,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: signed,
                ),
                inputFormatters: <TextInputFormatter>[
                  _FigureFormatter(signed: signed),
                ],
                textInputAction: action,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: style.copyWith(color: kGlassInkMuted),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, _) {
                if (controller.text.isNotEmpty) {
                  return Semantics(
                    button: true,
                    label: '$hint təmizlə',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: controller.clear,
                      child: SizedBox.square(
                        dimension: side,
                        child: Icon(
                          Icons.close_rounded,
                          size: side * 0.45,
                          color: kGlassInkMuted,
                        ),
                      ),
                    ),
                  );
                }
                if (suffix == null) return SizedBox(width: side * 0.42);
                return Padding(
                  padding: EdgeInsets.only(
                    left: side * 0.2,
                    right: side * 0.42,
                  ),
                  child: Text(
                    suffix,
                    maxLines: 1,
                    style: style.copyWith(color: kGlassInkMuted),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets through only what can still become a figure: digits, one point or
/// comma, and — where [signed] — a minus in front. Anything else typed or
/// pasted leaves the field as it was.
class _FigureFormatter extends TextInputFormatter {
  _FigureFormatter({required bool signed})
    : _shape = signed
          ? RegExp(r'^-?\d*([.,]\d*)?$')
          : RegExp(r'^\d*([.,]\d*)?$');

  final RegExp _shape;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _shape.hasMatch(newValue.text) ? newValue : oldValue;
}

/// What the list says when it has nothing to list.
class _Nothing extends StatelessWidget {
  const _Nothing({
    required this.metrics,
    required this.searching,
    required this.progress,
  });

  final DatabaseFilterMetrics metrics;
  final bool searching;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.valueCapsuleInset + metrics.valueTextInset,
        vertical: metrics.valuePadV,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          progress ?? (searching ? 'Axtarılır…' : 'Dəyər tapılmadı.'),
          maxLines: 2,
          style: metrics.labelStyle.copyWith(color: kGlassInkMuted),
        ),
      ),
    );
  }
}

/// One value: every line its name needs, and a capsule when it is chosen.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.metrics,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final DatabaseFilterMetrics metrics;
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.valueCapsuleInset),
      child: _Row(
        height: null,
        minHeight: metrics.valueRowMin,
        inset: metrics.valueTextInset,
        padV: metrics.valuePadV,
        marked: chosen,
        markFill: kDatabaseFilterControlFill,
        pressFill: kDatabaseFilterRowFill,
        onTap: onTap,
        semanticsSelected: chosen,
        child: Text(
          label,
          maxLines: DatabaseFilterMetrics.kValueMaxLines,
          overflow: TextOverflow.ellipsis,
          style: metrics.labelStyle.copyWith(color: kGlassInk),
        ),
      ),
    );
  }
}

/// A row of either page: its content, and a capsule under it when it is
/// marked or under a finger — the press is what says the tap landed before
/// anything moves.
class _Row extends StatefulWidget {
  const _Row({
    required this.height,
    required this.inset,
    required this.marked,
    required this.markFill,
    required this.pressFill,
    required this.onTap,
    required this.semanticsSelected,
    required this.child,
    this.capsuleHeight,
    this.minHeight,
    this.padV = 0,
  });

  /// A fixed height, or null for as tall as the content needs.
  final double? height;
  final double? capsuleHeight;
  final double? minHeight;
  final double padV;
  final double inset;
  final bool marked;
  final Color markFill;
  final Color pressFill;
  final VoidCallback onTap;
  final bool semanticsSelected;
  final Widget child;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed == down) return;
    setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = _pressed && !widget.marked
        ? widget.pressFill
        : widget.marked
        ? widget.markFill
        : widget.markFill.withValues(alpha: 0);

    Widget capsule = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.centerLeft,
      constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
      padding: EdgeInsets.symmetric(
        horizontal: widget.inset,
        vertical: widget.padV,
      ),
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: widget.child,
    );

    final double? height = widget.height;
    if (height != null) {
      final double capsuleHeight = widget.capsuleHeight ?? height;
      capsule = SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: (height - capsuleHeight) / 2),
          child: capsule,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: widget.semanticsSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: capsule,
      ),
    );
  }
}

/// `Sıfırla` — lets go of every column at once.
class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.metrics, required this.onTap});

  final DatabaseFilterMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filtri sıfırla',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: metrics.resetHeight,
          margin: EdgeInsets.only(right: metrics.resetRight),
          padding: EdgeInsets.symmetric(horizontal: metrics.resetPadH),
          decoration: const ShapeDecoration(
            color: kDatabaseFilterControlFill,
            shape: StadiumBorder(),
          ),
          // Centred in its height and only as wide as the word: a
          // container told to align its child fills the line instead.
          child: Center(
            widthFactor: 1,
            child: Text(
              'Sıfırla',
              maxLines: 1,
              softWrap: false,
              style: metrics.resetStyle.copyWith(color: kGlassInkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's round back button: a bold chevron on the controls' grey.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.side, required this.onTap});

  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Geri',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: side,
          height: side,
          decoration: const ShapeDecoration(
            color: kDatabaseFilterControlFill,
            shape: CircleBorder(),
          ),
          child: CustomPaint(painter: _ChevronPainter(side)),
        ),
      ),
    );
  }
}

/// The search field: a magnifier, what is typed, and a way to clear it.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.metrics,
    required this.hint,
    required this.controller,
    required this.focus,
    required this.searching,
  });

  final DatabaseFilterMetrics metrics;

  /// The column's name, so the field says what it searches without a word
  /// more than the design has.
  final String hint;

  final TextEditingController controller;
  final FocusNode focus;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final double side = metrics.controlSize;
    final TextStyle style = metrics.labelStyle.copyWith(
      color: kGlassInk,
      height: 1.2,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: Container(
        height: side,
        decoration: const ShapeDecoration(
          color: kDatabaseFilterControlFill,
          shape: StadiumBorder(),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: side * 0.24),
            CustomPaint(
              painter: _MagnifierPainter(side),
              size: Size.square(side * 0.48),
            ),
            SizedBox(width: side * 0.18),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                style: style,
                cursorColor: kGlassInk,
                cursorWidth: 1.6,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                onSubmitted: (_) => focus.unfocus(),
                decoration: InputDecoration.collapsed(
                  hintText: hint,
                  hintStyle: style.copyWith(color: kGlassInkMuted),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, _) {
                if (searching) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: side * 0.3),
                    child: SizedBox.square(
                      dimension: side * 0.36,
                      child: const CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: kGlassInkMuted,
                      ),
                    ),
                  );
                }
                if (controller.text.isEmpty) {
                  return SizedBox(width: side * 0.3);
                }
                return Semantics(
                  button: true,
                  label: 'Axtarışı təmizlə',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.clear,
                    child: SizedBox.square(
                      dimension: side,
                      child: Icon(
                        Icons.close_rounded,
                        size: side * 0.45,
                        color: kGlassInkMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's chevron: bold, a little narrower than it is tall.
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.side);

  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double w = side * 0.29;
    final double h = side * 0.35;
    final Path path = Path()
      ..moveTo(centre.dx + w * 0.4, centre.dy - h / 2)
      ..lineTo(centre.dx - w * 0.5, centre.dy)
      ..lineTo(centre.dx + w * 0.4, centre.dy + h / 2);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = kGlassInk,
    );
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.side != side;
}

/// The design's magnifier: a ring and a short handle.
class _MagnifierPainter extends CustomPainter {
  const _MagnifierPainter(this.side);

  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final double box = size.shortestSide;
    final double radius = box * 0.36;
    final Offset centre = Offset(box * 0.42, box * 0.42);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.062
      ..strokeCap = StrokeCap.round
      ..color = kGlassInk;
    canvas.drawCircle(centre, radius, paint);
    final Offset edge =
        centre + Offset(radius * math.sqrt1_2, radius * math.sqrt1_2);
    canvas.drawLine(edge, Offset(box * 0.94, box * 0.94), paint);
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter oldDelegate) =>
      oldDelegate.side != side;
}
