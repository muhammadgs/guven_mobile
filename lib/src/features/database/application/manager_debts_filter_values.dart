import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/manager_debt.dart';
import '../domain/manager_debts_filter.dart';
import 'database_filter_source.dart';
import 'manager_debts_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kManagerDebtsValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
const int kManagerDebtsValueSearchMin = 2;

/// How many rows a typed search reads for its values.
const int kManagerDebtsValueSearchSize = 20;

/// The values the open column of the `Menecer Borcları` filter offers, for
/// what has been typed into its search.
///
/// Only `Menecer` lists values: the managers on the phone in the list's
/// order — the largest debt first — and while typing the ones the bridge
/// finds. Every other column is a span of figures, and lists nothing.
class ManagerDebtsFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  ManagerDebtsFilterValues(this._owner);

  final ManagerDebtsController _owner;

  ManagerDebtsColumn? _column;

  @override
  ManagerDebtsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  @override
  bool get isSearching => _searching;

  /// The list is small enough to be on the phone whole, so a column never
  /// waits for it.
  @override
  String? get progress => null;

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  Timer? _debounce;
  int _serial = 0;
  bool _disposed = false;

  /// What the bridge answered, by query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  List<String>? _local;
  int _localStamp = -1;

  @override
  void open(ManagerDebtsColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text], and asks the bridge once typing pauses.
  @override
  void search(String text) {
    final ManagerDebtsColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column.searchable &&
        !_owner.hasEveryone &&
        query.length >= kManagerDebtsValueSearchMin &&
        !_answers.containsKey(filterSearchKey(query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kManagerDebtsValueSearchDelay, () => _ask(query));
    }
    notifyListeners();
  }

  /// The managers the bridge finds for [query].
  Future<void> _ask(String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<ManagerDebt> page = await _owner.fetch(
        page: 1,
        pageSize: kManagerDebtsValueSearchSize,
        search: query,
      );
      _answers[filterSearchKey(query)] = <String>[
        for (final ManagerDebt row in page.rows)
          if (row.manager case final String manager) manager,
      ];
    } on ApiException {
      // What is on the phone is still listed, and the next letter typed asks
      // again.
    } finally {
      if (!_disposed && serial == _serial) {
        _searching = false;
        if (_column != null) _rebuild();
        notifyListeners();
      }
    }
  }

  void _rebuild() {
    final ManagerDebtsColumn? column = _column;
    if (column == null || column.takesRange) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = filterSearchKey(_query.trim());
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = FilterValue(value, tidySpaces(value));
      if (query.isNotEmpty && !filterSearchKey(item.label).contains(query)) {
        return;
      }
      if (seen.add(filterKey(value))) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);
    _localValues().forEach(add);
    _answered()?.forEach(add);
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered() {
    final String query = _query.trim();
    for (int end = query.length; end >= kManagerDebtsValueSearchMin; end--) {
      final List<String>? answer =
          _answers[filterSearchKey(query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  /// Every manager among the rows on the phone, in the list's order.
  List<String> _localValues() {
    if (_localStamp != _owner.rowsStamp) {
      _local = null;
      _localStamp = _owner.rowsStamp;
    }
    return _local ??= <String>[
      for (final ManagerDebt row in _owner.knownRows)
        if (row.manager case final String manager
            when filterKey(manager).isNotEmpty)
          manager,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
