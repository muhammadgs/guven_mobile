import 'package:flutter/foundation.dart';

import '../domain/database_filter.dart';
import '../domain/manager_stat.dart';
import '../domain/manager_stats_filter.dart';
import '../presentation/database_format.dart';
import 'database_filter_source.dart';
import 'manager_stats_controller.dart';

/// The values the open column of the `Menecer statistikası` filter offers,
/// for what has been typed into its search:
///
/// * `Menecer` — every manager in the table, in the bridge's order, which
///   puts whoever had the largest month first. The bridge cannot list them,
///   so the first time the column opens the rest of the table is read
///   ([ManagerStatsController.readAll]) — one request, the table being a
///   few dozen rows — and the column says how far that has got rather than
///   listing values that would still move under a finger;
/// * `Dövr` lists nothing: it is a start and an end, set on a calendar. It
///   reads the table too, so that the calendar knows which months have
///   figures;
/// * `Sifariş` and `Cəmi məbləğ` are spans, and list nothing either.
class ManagerStatsFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  ManagerStatsFilterValues(this._owner) {
    _owner.addListener(_ownerChanged);
  }

  final ManagerStatsController _owner;

  ManagerStatsColumn? _column;

  @override
  ManagerStatsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  /// True while the open column waits for every row before it lists
  /// anything.
  bool _waiting = false;

  @override
  bool get isSearching => _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    if (total == null || total == 0) return 'Qeydlər oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} qeyd oxundu';
  }

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  List<String>? _managers;
  int _managersStamp = -1;

  @override
  void open(ManagerStatsColumn column) {
    _column = column;
    _query = '';
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));

    _waiting = false;
    if (column.needsEveryone && !_owner.hasEveryone) {
      // Returns at once if the reading is already under way.
      _owner.readAll();
      // The calendar works with whatever months are known meanwhile; only a
      // list of names waits for all of them.
      _waiting = !column.takesPeriod && _owner.isReadingAll;
    }
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _waiting = false;
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text]. Every manager is on the phone by then, so
  /// nothing is asked of the bridge.
  @override
  void search(String text) {
    if (_column == null || text == _query) return;
    _query = text;
    _rebuild();
    notifyListeners();
  }

  /// The owner has moved on: rows arrived, or the table has been read.
  void _ownerChanged() {
    if (_column == null || !_waiting || _owner.isReadingAll) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final ManagerStatsColumn? column = _column;
    if (column != ManagerStatsColumn.manager || _waiting) {
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
    _knownManagers().forEach(add);
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// Every manager among the rows on the phone, in the order they were met.
  List<String> _knownManagers() {
    if (_managersStamp != _owner.rowsStamp || _managers == null) {
      _managersStamp = _owner.rowsStamp;
      final Set<String> seen = <String>{};
      _managers = <String>[
        for (final ManagerStat stat in _owner.knownStats)
          if (stat.manager case final String name
              when filterKey(name).isNotEmpty && seen.add(filterKey(name)))
            name,
      ];
    }
    return _managers!;
  }

  @override
  void dispose() {
    _owner.removeListener(_ownerChanged);
    super.dispose();
  }
}
