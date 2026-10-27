import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/database_filter.dart';
import '../domain/debt_allocation.dart';
import '../domain/debt_allocations_filter.dart';
import '../domain/manager_debt.dart';
import 'database_filter_source.dart';
import 'debt_allocations_controller.dart';

/// The values the open column of the `Borc Bölgüsü` filter offers, for
/// what has been typed into its search.
///
/// Only `Menecer` lists values: every manager with a share, the most
/// collected first — read once from `Menecer Borcları`' thirteen rows
/// ([DebtAllocationsController.managers]) rather than out of thousands of
/// shares — and any other manager on the phone after them. What is typed
/// narrows that list on the phone; it is the whole of it. `Tarix` is a run
/// of months and `Bölgü` a span of amounts, and list nothing.
class DebtAllocationsFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  DebtAllocationsFilterValues(this._owner);

  final DebtAllocationsController _owner;

  DebtAllocationsColumn? _column;

  @override
  DebtAllocationsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _asking = false;

  /// True while the managers are on their way.
  @override
  bool get isSearching => _asking;

  /// Thirteen names come in one request; nothing is counted out.
  @override
  String? get progress => null;

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  /// Every manager with a share, once read. Null until then, and again
  /// after a failure, so the next opening asks again.
  List<String>? _managers;

  bool _disposed = false;

  List<String>? _local;
  int _localStamp = -1;

  @override
  void open(DebtAllocationsColumn column) {
    _column = column;
    _query = '';
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));
    if (column == DebtAllocationsColumn.manager && _managers == null) {
      _ask();
    }
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text].
  @override
  void search(String text) {
    if (_column == null || text == _query) return;
    _query = text;
    _rebuild();
    notifyListeners();
  }

  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    try {
      _managers = <String>[
        for (final ManagerDebt row in await _owner.managers())
          if (row.manager case final String manager
              when filterKey(manager).isNotEmpty)
            manager,
      ];
    } on ApiException {
      // The managers on the phone are still listed, and the next opening
      // asks again.
    } finally {
      _asking = false;
      if (!_disposed) {
        if (_column != null) _rebuild();
        notifyListeners();
      }
    }
  }

  void _rebuild() {
    final DebtAllocationsColumn? column = _column;
    if (column != DebtAllocationsColumn.manager) {
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
    _managers?.forEach(add);
    _localValues().forEach(add);
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// Every manager among the rows on the phone, in the list's order.
  List<String> _localValues() {
    if (_localStamp != _owner.rowsStamp) {
      _local = null;
      _localStamp = _owner.rowsStamp;
    }
    return _local ??= <String>[
      for (final DebtAllocation row in _owner.knownRows)
        if (row.manager case final String manager
            when filterKey(manager).isNotEmpty)
          manager,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
