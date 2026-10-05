import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/stock_filter.dart';
import '../domain/stock_item.dart';
import 'database_filter_source.dart';
import 'stock_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kStockValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
/// One letter finds half the table; the second one is worth waiting for.
const int kStockValueSearchMin = 2;

/// How many balances a typed search reads for its values. A product kept in
/// six warehouses is six rows of one name, so thirty rows still come to a
/// list's worth of names.
const int kStockValueSearchSize = 30;

/// The values the open column of the `Stok` filter offers, for what has been
/// typed into its search.
///
/// Before anything is typed a column offers the values of the balances
/// already on the phone, in the list's order. Typing narrows those, and:
///
/// * `Kod`, `Məhsul` — also ask the bridge, whose `search` reads codes and
///   names, so a product no loaded row carries can still be found;
/// * `Anbar` — offers the warehouse catalogue, asked for once when the
///   column opens: seven names, spelt exactly as the stock rows spell them;
/// * `Miqdar` — offers its two levels;
/// * `Tarix` — offers the days the loaded balances were counted on, newest
///   first. 1C counts the whole table in a sync or two, so these are few
///   (two on 2026-09-25) and the first page already carries them.
class StockFilterValues extends ChangeNotifier implements DatabaseFilterValues {
  StockFilterValues(this._owner, this._api);

  final StockController _owner;
  final DatabaseApi _api;

  StockColumn? _column;

  @override
  StockColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  @override
  bool get isSearching => _searching;

  /// Every column lists what it has at once.
  @override
  String? get progress => null;

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  Timer? _debounce;
  int _serial = 0;
  bool _disposed = false;

  List<String>? _warehouses;
  bool _warehousesAsked = false;

  /// What the bridge answered, by column and query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  final Map<StockColumn, List<String>> _local = <StockColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(StockColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));
    _rebuild();
    notifyListeners();

    if (column == StockColumn.warehouse) _askWarehouses();
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

  @override
  void search(String text) {
    final StockColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        _asksBridge(column) &&
        query.length >= kStockValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kStockValueSearchDelay, () => _ask(column, query));
    }
    notifyListeners();
  }

  static bool _asksBridge(StockColumn column) =>
      column == StockColumn.code || column == StockColumn.product;

  static String _answerKey(StockColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  /// What [item] says in [column], for the columns a value is read off.
  static String? _field(StockColumn column, StockItem item) => switch (column) {
    StockColumn.code => item.code,
    StockColumn.product => item.product,
    StockColumn.warehouse => item.warehouse,
    StockColumn.date => item.date,
    StockColumn.quantity => null,
  };

  /// The codes or names of the balances the bridge finds for [query]. Its
  /// `search` also reads the other two fields, so the answer is narrowed to
  /// the values that actually hold what was typed.
  Future<void> _ask(StockColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<StockItem> page = await _api.stockPage(
        page: 1,
        pageSize: kStockValueSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[_answerKey(column, query)] = <String>[
        for (final StockItem item in page.rows)
          if (_field(column, item) case final String value
              when filterSearchKey(value).contains(key))
            value,
      ];
    } on ApiException {
      // What is on the phone is still listed, and the next letter typed asks
      // again.
    } finally {
      if (!_disposed && serial == _serial) {
        _searching = false;
        if (_column == column) _rebuild();
        notifyListeners();
      }
    }
  }

  Future<void> _askWarehouses() async {
    if (_warehousesAsked) return;
    _warehousesAsked = true;
    try {
      _warehouses = await _api.warehouseNames();
    } on ApiException {
      // The warehouses of the balances on the phone are still listed; the
      // next time the column opens asks again.
      _warehousesAsked = false;
      return;
    }
    if (_disposed) return;
    if (_column == StockColumn.warehouse) {
      _rebuild();
      notifyListeners();
    }
  }

  void _rebuild() {
    final StockColumn? column = _column;
    if (column == null) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = filterSearchKey(_query.trim());
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = _valueOf(column, value);
      if (query.isNotEmpty && !filterSearchKey(item.label).contains(query)) {
        return;
      }
      if (seen.add(_identity(column, value))) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);

    switch (column) {
      case StockColumn.quantity:
        for (final StockLevel level in StockLevel.values) {
          add(level.name);
        }
      case StockColumn.warehouse:
        // The catalogue's order — its own, alphabetical — rather than the
        // order the loaded balances happen to name them in.
        _warehouses?.forEach(add);
        _localValues(column).forEach(add);
      case StockColumn.date:
        _localValues(column).forEach(add);
      case StockColumn.code || StockColumn.product:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(StockColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kStockValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(StockColumn column, String value) => switch (column) {
    StockColumn.quantity || StockColumn.date => value,
    _ => filterKey(value),
  };

  static FilterValue _valueOf(StockColumn column, String value) =>
      switch (column) {
        StockColumn.quantity => FilterValue(
          value,
          StockLevel.byName(value)?.label ?? value,
        ),
        StockColumn.date => FilterValue(value, value),
        _ => FilterValue(value, tidySpaces(value)),
      };

  /// Every value of [column] among the balances on the phone — in the
  /// list's order, days newest first.
  List<String> _localValues(StockColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Set<String> seen = <String>{};
      final List<String> out = <String>[];
      for (final StockItem item in _owner.knownItems) {
        final String? value = _field(column, item);
        if (value == null) continue;
        final String identity = _identity(column, value);
        if (identity.isEmpty) continue;
        if (seen.add(identity)) out.add(value);
      }
      if (column == StockColumn.date) {
        out.sort((String a, String b) => b.compareTo(a));
      }
      return out;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
