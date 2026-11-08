import 'package:flutter/foundation.dart';

import '../../database/application/database_filter_source.dart';
import '../../database/domain/database_filter.dart';
import '../domain/task_filter.dart';
import 'tasks_controller.dart';

/// The task list's filter, as the `Baza` filter panel asks for one.
///
/// The user asked for the two filters to be one and the same (2026-11-08):
/// one pane of glass that turns from the columns into a column's values —
/// back, a search field, `Hamısı`, the values — instead of a second panel
/// opening beside the first, and a span where the column is ordered. The
/// task list has no figures, so its spans are of days: `Tarix` and `Son
/// müddət` open onto a first and a last day, with the days themselves
/// listed under them.
///
/// Everything still works over the rows already loaded, the site's cascade
/// included — this only says it in the panel's words.
class TaskFilterSource implements DatabaseRangeFilterSource {
  TaskFilterSource(this._tasks) : _values = TaskFilterValues(_tasks);

  final TasksController _tasks;
  final TaskFilterValues _values;

  /// What a day span's two fields say while empty.
  static const FilterRangeField dayField = FilterRangeField(
    minHint: 'Min tarix',
    maxHint: 'Maks tarix',
    day: true,
  );

  @override
  void addListener(VoidCallback listener) => _tasks.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _tasks.removeListener(listener);

  @override
  List<DatabaseFilterColumn> get filterColumns => _tasks.filterFields;

  @override
  bool get isFiltered => _tasks.filter.isNotEmpty;

  @override
  int get filterCount => _tasks.filter.activeFieldCount;

  @override
  bool narrows(TaskFilterField column) => _tasks.filter.narrows(column);

  @override
  bool isChosen(TaskFilterField column, String value) =>
      _tasks.filter.isSelected(column, value);

  @override
  Future<void> toggleFilter(TaskFilterField column, String value) async =>
      _tasks.toggleFilter(column, value);

  @override
  Future<void> clearFilterColumn(TaskFilterField column) async =>
      _tasks.clearFilterField(column);

  @override
  Future<void> clearFilter() async => _tasks.clearFilter();

  @override
  DatabaseFilterValues get filterValues => _values;

  @override
  FilterRangeField? rangeFieldOf(TaskFilterField column) =>
      column.isDate ? dayField : null;

  @override
  FilterRange rangeOf(TaskFilterField column) => _tasks.filter.rangeOf(column);

  @override
  Future<void> setRange(TaskFilterField column, FilterRange range) async =>
      _tasks.setFilterRange(column, range);

  void dispose() => _values.dispose();
}

/// The values the open column offers, for what has been typed into its
/// search: the column's values among the rows that survive every *other*
/// column, narrowed to the ones holding what was typed — `sebeke` finds
/// `Şəbəkə`, the way every `Baza` search does.
///
/// Days are listed `25.08.2026`, newest first, as the span's fields write
/// them, and kept as the row writes them.
class TaskFilterValues extends ChangeNotifier implements DatabaseFilterValues {
  TaskFilterValues(this._tasks) {
    _tasks.addListener(_tasksChanged);
  }

  final TasksController _tasks;

  TaskFilterField? _column;

  @override
  TaskFilterField? get column => _column;

  String _query = '';

  List<String> _options = const <String>[];
  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  @override
  bool get isSearching => false;

  @override
  String? get progress => null;

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  @override
  void open(TaskFilterField column) {
    _column = column;
    _query = '';
    _pinned
      ..clear()
      ..addAll(_tasks.filter.valuesOf(column));
    _options = _tasks.filterOptions(column);
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _options = const <String>[];
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  @override
  void search(String text) {
    if (_column == null || text == _query) return;
    _query = text;
    _rebuild();
    notifyListeners();
  }

  /// The rows moved: another column narrowed them, or a pull brought new
  /// ones. Only a column whose values actually changed is rebuilt, so a
  /// value ticked in the open column does not shuffle the list under the
  /// finger.
  void _tasksChanged() {
    final TaskFilterField? column = _column;
    if (column == null) return;
    final List<String> options = _tasks.filterOptions(column);
    if (listEquals(options, _options)) return;
    _options = options;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final TaskFilterField? column = _column;
    if (column == null) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = filterSearchKey(_query.trim());
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = FilterValue(value, labelOf(column, value));
      if (query.isNotEmpty &&
          !filterSearchKey(item.label).contains(query) &&
          !filterSearchKey(value).contains(query)) {
        return;
      }
      if (seen.add(value)) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);
    _options.forEach(add);
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// [value] as the list shows it: a day `25.08.2026`, a name with its
  /// spacing tidied.
  static String labelOf(TaskFilterField column, String value) {
    if (!column.isDate) return tidySpaces(value);
    final List<String> parts = value.split('-');
    if (parts.length != 3) return value;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  @override
  void dispose() {
    _tasks.removeListener(_tasksChanged);
    super.dispose();
  }
}
