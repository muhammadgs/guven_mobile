import 'package:flutter/material.dart';

import '../../../../shared/effects.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../../database/domain/database_filter.dart' show filterSearchKey;
import '../../application/new_task_controller.dart';
import '../../domain/new_task.dart';
import '../new_task_metrics.dart';
import 'task_glass.dart';

/// How long a field's list takes to open. Short: it is the third thing asked
/// for, not the first, and the surface it grows out of is already on screen.
const Duration kPickerOpen = Duration(milliseconds: 320);
const Duration kPickerClose = Duration(milliseconds: 200);

/// A list longer than this gets a search field over it. Shorter ones — a
/// task's three statuses — are read at a glance, and a field there would
/// only push them down.
const int kPickerSearchMin = 6;

/// A field's options, grown out of the field itself.
///
/// Dark, and over the sheet rather than beside it. Both are deliberate: the
/// sheet is as wide as the screen allows, so there is no second column to put
/// this in, and a pale panel over a pale panel would leave the eye nothing to
/// tell them apart by. The darkness doubles as the fix for two lenses stacked
/// — this one keeps so little of what is behind it that there is no double
/// image to see.
///
/// A long list opens with a search field over it (2026-11-08, the user):
/// typing narrows the names the way every `Baza` search does — case, spacing
/// and the letters a keyboard without `ə`, `ş` lacks set aside, so `sadiq`
/// finds `Sadıq`. The panel keeps the height of the whole list while it is
/// typed into, so it does not jump under the finger.
class NewTaskPickerPanel extends StatefulWidget {
  const NewTaskPickerPanel({
    super.key,
    required this.metrics,
    required this.anchor,
    required this.flight,
    required this.emptyMessage,
    required this.list,
    required this.chosen,
    required this.onPick,
  });

  final NewTaskMetrics metrics;

  /// The field row's own global rect, read at the moment it was tapped.
  final Rect anchor;

  final Animation<double> flight;

  /// What this panel says when the list it was given is empty, which is never
  /// the same sentence as "nothing chosen yet" — `İşçi tapılmadı`, not
  /// `İşçi seçin`. A string rather than the field itself, because both task
  /// sheets open this panel and they name their fields with different enums.
  final String emptyMessage;

  final OptionList list;
  final TaskOption? chosen;
  final ValueChanged<TaskOption> onPick;

  @override
  State<NewTaskPickerPanel> createState() => _NewTaskPickerPanelState();
}

class _NewTaskPickerPanelState extends State<NewTaskPickerPanel> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.flight.addStatusListener(_onFlight);
    _query.addListener(_onQuery);
  }

  @override
  void didUpdateWidget(covariant NewTaskPickerPanel old) {
    super.didUpdateWidget(old);
    if (old.flight == widget.flight) return;
    old.flight.removeStatusListener(_onFlight);
    widget.flight.addStatusListener(_onFlight);
  }

  @override
  void dispose() {
    widget.flight.removeStatusListener(_onFlight);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The keyboard goes down with the list, not after it.
  void _onFlight(AnimationStatus status) {
    if (status == AnimationStatus.reverse) _focus.unfocus();
  }

  void _onQuery() => setState(() {});

  bool get _searchable =>
      !widget.list.loading &&
      widget.list.error == null &&
      widget.list.notice == null &&
      widget.list.options.length >= kPickerSearchMin;

  /// The options holding what is typed, in the list's own order.
  List<TaskOption> get _shown {
    final String query = filterSearchKey(_query.text.trim());
    if (query.isEmpty) return widget.list.options;
    return <TaskOption>[
      for (final TaskOption option in widget.list.options)
        if (filterSearchKey(option.name).contains(query)) option,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final NewTaskMetrics metrics = widget.metrics;
    final bool search = _searchable;
    // A message counts as a row: an empty list still has to be a panel, or
    // tapping the field would look like nothing happened.
    final int rows = widget.list.options.isEmpty
        ? 2
        : widget.list.options.length;
    final Rect resting = metrics.pickerPanel(
      anchor: widget.anchor,
      rowCount: rows,
      search: search,
    );

    return AnimatedBuilder(
      animation: widget.flight,
      child: _content(metrics, search),
      builder: (BuildContext context, Widget? child) {
        return DarkPanelSurface(
          frame: resolveGlassMorph(
            progress: widget.flight,
            from: widget.anchor,
            fromRadius: widget.anchor.height / 2,
            to: resting,
            toRadius: metrics.pickerRadius,
          ),
          restingSize: resting.size,
          child: child!,
        );
      },
    );
  }

  Widget _content(NewTaskMetrics metrics, bool search) {
    final OptionList list = widget.list;
    if (list.loading) {
      return _Notice(metrics: metrics, text: 'Yüklənir…', spinner: true);
    }
    final String? error = list.error;
    if (error != null) return _Notice(metrics: metrics, text: error);
    // What the field itself is already saying, repeated here so opening it is
    // not a dead end: "Digər şirkət seçin", not "İşçi tapılmadı".
    final String? notice = list.notice;
    if (notice != null) return _Notice(metrics: metrics, text: notice);
    if (list.options.isEmpty) {
      return _Notice(metrics: metrics, text: widget.emptyMessage);
    }

    final List<TaskOption> shown = search ? _shown : list.options;
    final Widget options = shown.isEmpty
        ? Align(
            alignment: Alignment.topCenter,
            child: _Notice(metrics: metrics, text: 'Heç nə tapılmadı'),
          )
        : ListView.builder(
            padding: EdgeInsets.fromLTRB(
              metrics.pickerPadH,
              search ? 0 : metrics.pickerPadV,
              metrics.pickerPadH,
              metrics.pickerPadV,
            ),
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemExtent: metrics.pickerRowHeight,
            itemCount: shown.length,
            itemBuilder: (BuildContext context, int i) {
              final TaskOption option = shown[i];
              return _Row(
                metrics: metrics,
                label: option.name,
                selected: option == widget.chosen,
                onTap: () {
                  _focus.unfocus();
                  widget.onPick(option);
                },
              );
            },
          );
    if (!search) return options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.pickerPadH,
            metrics.pickerPadV,
            metrics.pickerPadH,
            metrics.pickerSearchGap,
          ),
          child: _SearchField(
            metrics: metrics,
            controller: _query,
            focus: _focus,
          ),
        ),
        Expanded(child: options),
      ],
    );
  }
}

/// The picker's search: a capsule of the chosen row's tint, a magnifier, and
/// a cross to empty it once something is typed.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.metrics,
    required this.controller,
    required this.focus,
  });

  final NewTaskMetrics metrics;
  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final double height = metrics.pickerSearchHeight;
    final TextStyle style = TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w400,
      fontSize: metrics.valueSize,
      height: 1.2,
      color: kNewTaskPickerInk,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: Container(
        height: height,
        decoration: ShapeDecoration(
          color: kNewTaskPickerRowFill,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: metrics.pickerPadH * 1.2),
            Icon(
              Icons.search_rounded,
              size: metrics.valueSize * 1.25,
              color: kNewTaskPickerInkMuted,
            ),
            SizedBox(width: metrics.pickerPadH * 0.8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                style: style,
                cursorColor: kNewTaskPickerInk,
                cursorWidth: 1.6,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 1,
                onSubmitted: (_) => focus.unfocus(),
                decoration: InputDecoration.collapsed(
                  hintText: 'Adla axtar',
                  hintStyle: style.copyWith(color: kNewTaskPickerInkMuted),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, _) {
                if (controller.text.isEmpty) {
                  return SizedBox(width: metrics.pickerPadH * 1.2);
                }
                return Semantics(
                  button: true,
                  label: 'Axtarışı təmizlə',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.clear,
                    child: SizedBox.square(
                      dimension: height,
                      child: Icon(
                        Icons.close_rounded,
                        size: metrics.valueSize * 1.15,
                        color: kNewTaskPickerInkMuted,
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

/// `Son müddət` — the deadline, on the same dark glass as the lists.
///
/// A wheel rather than the framework's calendar dialog: a Material dialog
/// dropped in the middle of this screen would be the one surface on it that
/// belongs to a different app.
class NewTaskDatePanel extends StatefulWidget {
  const NewTaskDatePanel({
    super.key,
    required this.metrics,
    required this.anchor,
    required this.flight,
    required this.initial,
    required this.onPick,
  });

  final NewTaskMetrics metrics;
  final Rect anchor;
  final Animation<double> flight;
  final DateTime? initial;
  final ValueChanged<DateTime> onPick;

  @override
  State<NewTaskDatePanel> createState() => _NewTaskDatePanelState();
}

/// `Yanvar`…`Dekabr`.
///
/// Written out here rather than taken from a localisation: this app declares
/// no locales, so `CupertinoLocalizations` resolves to English and a Cupertino
/// wheel would offer `August` in an application that has not a word of English
/// anywhere else in it.
const List<String> kAzMonths = <String>[
  'Yanvar',
  'Fevral',
  'Mart',
  'Aprel',
  'May',
  'İyun',
  'İyul',
  'Avqust',
  'Sentyabr',
  'Oktyabr',
  'Noyabr',
  'Dekabr',
];

class _NewTaskDatePanelState extends State<NewTaskDatePanel> {
  /// A deadline in the past is a legitimate thing to record — the site marks
  /// such a task `Gecikmiş` rather than refusing it — so only the far ends are
  /// fenced off.
  static final int _firstYear = DateTime.now().year - 1;
  static const int _yearSpan = 7;

  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    final DateTime start = widget.initial ?? DateTime.now();
    _year = start.year.clamp(_firstYear, _firstYear + _yearSpan - 1);
    _month = start.month;
    _day = start.day;
  }

  /// Days in the chosen month, so 31 February can never be picked.
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  DateTime get _picked => DateTime(_year, _month, _day.clamp(1, _daysInMonth));

  @override
  Widget build(BuildContext context) {
    final NewTaskMetrics metrics = widget.metrics;
    final double height = 250 * metrics.scale;
    final Rect resting = metrics.panelAt(anchor: widget.anchor, height: height);

    return AnimatedBuilder(
      animation: widget.flight,
      child: _wheel(metrics),
      builder: (BuildContext context, Widget? child) {
        return DarkPanelSurface(
          frame: resolveGlassMorph(
            progress: widget.flight,
            from: widget.anchor,
            fromRadius: widget.anchor.height / 2,
            to: resting,
            toRadius: metrics.pickerRadius,
          ),
          restingSize: resting.size,
          child: child!,
        );
      },
    );
  }

  Widget _wheel(NewTaskMetrics metrics) {
    final double extent = metrics.pickerRowHeight * 0.86;

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              // The band the chosen row sits in, behind the wheels — the one
              // thing that says which of the three lines is the answer.
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: metrics.pickerPadH),
                  child: Container(
                    height: extent,
                    decoration: ShapeDecoration(
                      color: kNewTaskPickerRowFill,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(extent / 2),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: _Wheel(
                      count: _daysInMonth,
                      selected: _day.clamp(1, _daysInMonth) - 1,
                      extent: extent,
                      fontSize: metrics.valueSize * 1.15,
                      label: (int i) => '${i + 1}',
                      onChanged: (int i) => setState(() => _day = i + 1),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: _Wheel(
                      count: 12,
                      selected: _month - 1,
                      extent: extent,
                      fontSize: metrics.valueSize * 1.15,
                      label: (int i) => kAzMonths[i],
                      onChanged: (int i) => setState(() => _month = i + 1),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _Wheel(
                      count: _yearSpan,
                      selected: _year - _firstYear,
                      extent: extent,
                      fontSize: metrics.valueSize * 1.15,
                      label: (int i) => '${_firstYear + i}',
                      onChanged: (int i) =>
                          setState(() => _year = _firstYear + i),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.pickerPadH * 1.6,
            0,
            metrics.pickerPadH * 1.6,
            metrics.pickerPadV * 1.4,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onPick(_picked),
            child: Container(
              height: metrics.pickerRowHeight,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: kNewTaskPickerRowFill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    metrics.pickerRowHeight / 2,
                  ),
                ),
              ),
              child: Text(
                'Seç',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: metrics.valueSize,
                  height: 1,
                  color: kNewTaskPickerInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One column of the date picker.
///
/// Its own widget because the day wheel's length changes with the month, and a
/// `FixedExtentScrollController` has to be rebuilt when the selection it is
/// holding falls off the end — 31 January becoming February.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.selected,
    required this.extent,
    required this.fontSize,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int selected;
  final double extent;
  final double fontSize;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _scroll = FixedExtentScrollController(
    initialItem: widget.selected,
  );

  @override
  void didUpdateWidget(covariant _Wheel old) {
    super.didUpdateWidget(old);
    if (widget.count >= old.count) return;
    if (!_scroll.hasClients || _scroll.selectedItem < widget.count) return;

    // The month has grown shorter under the day wheel — 31 August became 30
    // September — so the wheel has to snap back to the last day there is.
    //
    // **After the frame, never inside it.** `jumpToItem` moves the scroll
    // position, which dispatches a scroll notification, which calls
    // `onSelectedItemChanged`, which is a `setState` on the panel above. Doing
    // that from `didUpdateWidget` is a `setState` during build: the framework
    // throws, the day column is replaced by an error widget, and the three
    // wheels shuffle along one place — which is exactly what that stray second
    // column of numbers was.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.selectedItem < widget.count) return;
      _scroll.jumpToItem(widget.count - 1);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _scroll,
      itemExtent: widget.extent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.4,
      perspective: 0.004,
      overAndUnderCenterOpacity: 0.45,
      onSelectedItemChanged: widget.onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (BuildContext context, int i) => Center(
          child: Text(
            widget.label(i),
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: widget.fontSize,
              height: 1,
              color: kNewTaskPickerInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark lens both panels are drawn on.
///
/// It starts life wearing the field box's own glass and darkens into its own
/// as it grows, so the flight is glass becoming glass rather than a lens
/// appearing where a fill used to be — the field it came out of is hidden for
/// exactly as long as this is on screen ([NewTaskBox.hidden]).
///
/// Nothing here wraps the glass in an `Opacity` or an `ImageFiltered`: either
/// opens a `saveLayer` over a surface that samples its own backdrop, and the
/// lens renders black. Only what sits *inside* it fades.
class DarkPanelSurface extends StatelessWidget {
  const DarkPanelSurface({
    super.key,
    required this.frame,
    required this.restingSize,
    required this.child,
  });

  final GlassMorphFrame frame;

  /// The panel's size once it has landed. The rows are always laid out against
  /// this and never against the in-flight rect — a list reflowing inside a
  /// 46pt field would overflow on every frame of the opening.
  final Size restingSize;

  final Widget child;

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
          style: lerpAppGlassStyle(
            kNewTaskFieldGlass,
            kNewTaskPickerGlass,
            frame.blend,
            cornerRadius: frame.radius,
          ),
          cornerRadius: frame.radius,
          child: IgnorePointer(
            ignoring: !frame.isSettled,
            child: OverflowBox(
              minWidth: restingSize.width,
              maxWidth: restingSize.width,
              minHeight: restingSize.height,
              maxHeight: restingSize.height,
              child: Opacity(
                opacity: frame.targetOpacity,
                child: blurred(8 * (1 - frame.targetOpacity), child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option.
class _Row extends StatelessWidget {
  const _Row({
    required this.metrics,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final NewTaskMetrics metrics;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: metrics.pickerRowHeight,
        padding: EdgeInsets.symmetric(horizontal: metrics.pickerPadH * 1.2),
        decoration: selected
            ? ShapeDecoration(
                color: kNewTaskPickerRowFill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(
                    metrics.pickerRowHeight / 2,
                  ),
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: metrics.valueSize,
                  height: 1.15,
                  color: selected ? kNewTaskPickerInk : kNewTaskPickerInkMuted,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: metrics.valueSize * 1.2,
                color: kNewTaskPickerInk,
              ),
          ],
        ),
      ),
    );
  }
}

/// What the panel shows instead of a list: loading, a failure, or the honest
/// news that this company has nobody and nothing to offer.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.metrics,
    required this.text,
    this.spinner = false,
  });

  final NewTaskMetrics metrics;
  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.pickerPadH * 1.6,
        vertical: metrics.pickerPadV,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (spinner) ...<Widget>[
            SizedBox.square(
              dimension: metrics.valueSize,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: kNewTaskPickerInkMuted,
              ),
            ),
            SizedBox(width: metrics.pickerPadH),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: metrics.valueSize,
                height: 1.3,
                color: kNewTaskPickerInkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
