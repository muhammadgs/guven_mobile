import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/sale.dart';
import '../domain/sales_filter.dart';
import 'database_filter_source.dart';
import 'sales_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kSalesValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
/// One letter finds half the catalogue; the second one is worth waiting for.
const int kSalesValueSearchMin = 2;

/// How many documents a number search asks for: the list shows five or six
/// values at a time, and a longer number narrows it further.
const int kSalesNumberSearchSize = 12;

/// The values the open column of the filter offers, for what has been typed
/// into its search.
///
/// Before anything is typed a column offers the values of the documents
/// already on the phone, newest first — the design's list, and free. Typing
/// narrows those, and for the columns the bridge has a catalogue of it also
/// asks the bridge, so a value no loaded document carries can still be
/// found:
///
/// * `Sənəd` — the documents whose number holds what was typed;
/// * `Müştəri`, `Məhsul` — the customer and product catalogues;
/// * `Menecer` — every manager, asked for once when the column opens;
/// * `Tarix` — every day from the newest document back to the oldest, which
///   is one one-row request away.
///
/// The rest — `Təşkilat`, `Anbar`, `Növ` — have no catalogue on the bridge
/// and offer what the documents on the phone carry. `Status` offers its four
/// flags.
class SalesFilterValues extends ChangeNotifier implements DatabaseFilterValues {
  SalesFilterValues(this._owner, this._api);

  final SalesController _owner;
  final DatabaseApi _api;

  SalesColumn? _column;

  @override
  SalesColumn? get column => _column;

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

  List<String>? _managers;
  bool _managersAsked = false;

  /// What the bridge answered, by column and query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  String? _oldest;
  bool _oldestAsked = false;

  final Map<SalesColumn, List<String>> _local = <SalesColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(SalesColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));
    _rebuild();
    notifyListeners();

    if (column == SalesColumn.manager) _askManagers();
    if (column == SalesColumn.date) _askOldest();
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
    final SalesColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        _asksBridge(column) &&
        query.length >= kSalesValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kSalesValueSearchDelay, () => _ask(column, query));
    }
    notifyListeners();
  }

  static bool _asksBridge(SalesColumn column) =>
      column == SalesColumn.number ||
      column == SalesColumn.customer ||
      column == SalesColumn.product;

  static String _answerKey(SalesColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  Future<void> _ask(SalesColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final List<String> names = switch (column) {
        SalesColumn.number => await _numbers(query),
        SalesColumn.customer => await _api.customerNames(search: query),
        SalesColumn.product => await _api.productNames(search: query),
        _ => const <String>[],
      };
      _answers[_answerKey(column, query)] = names;
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

  /// The numbers of the documents whose number holds [query]. The bridge's
  /// `search` also reads customers and managers, so its answer is narrowed to
  /// the numbers that actually match.
  Future<List<String>> _numbers(String query) async {
    final DatabasePage<Sale> page = await _api.salesPage(
      page: 1,
      pageSize: kSalesNumberSearchSize,
      search: query,
    );
    final String key = filterSearchKey(query);
    return <String>[
      for (final Sale sale in page.rows)
        if (sale.number != null && filterSearchKey(sale.number!).contains(key))
          sale.number!,
    ];
  }

  Future<void> _askManagers() async {
    if (_managersAsked) return;
    _managersAsked = true;
    try {
      _managers = await _api.managerNames();
    } on ApiException {
      // The managers of the documents on the phone are still listed; the
      // next time the column opens asks again.
      _managersAsked = false;
      return;
    }
    if (_disposed) return;
    if (_column == SalesColumn.manager) {
      _rebuild();
      notifyListeners();
    }
  }

  /// The date of the oldest document, which is where the list of days ends.
  Future<void> _askOldest() async {
    final int? total = _owner.total;
    if (_oldestAsked || total == null || total == 0) return;
    _oldestAsked = true;
    try {
      final DatabasePage<Sale> page = await _api.salesPage(
        page: total,
        pageSize: 1,
      );
      _oldest = page.rows.isEmpty ? null : page.rows.first.date;
    } on ApiException {
      _oldestAsked = false;
      return;
    }
    if (_disposed) return;
    if (_column == SalesColumn.date) {
      _rebuild();
      notifyListeners();
    }
  }

  void _rebuild() {
    final SalesColumn? column = _column;
    if (column == null) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = filterSearchKey(_query.trim());
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = _valueOf(column, value);
      if (query.isNotEmpty && !_hits(column, item, query)) return;
      if (seen.add(_identity(column, value))) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);

    switch (column) {
      case SalesColumn.status:
        for (final SaleFlag flag in SaleFlag.values) {
          add(flag.name);
        }
      case SalesColumn.date:
        _days().forEach(add);
      case SalesColumn.manager:
        _localValues(column).forEach(add);
        _managers?.forEach(add);
      default:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(SalesColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kSalesValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(SalesColumn column, String value) => switch (column) {
    SalesColumn.kind || SalesColumn.status || SalesColumn.date => value,
    _ => filterKey(value),
  };

  static FilterValue _valueOf(SalesColumn column, String value) =>
      switch (column) {
        SalesColumn.kind => FilterValue(value, Sale.kindLabel(value)),
        SalesColumn.status => FilterValue(
          value,
          SaleFlag.byName(value)?.label ?? value,
        ),
        _ => FilterValue(value, tidySpaces(value)),
      };

  static bool _hits(SalesColumn column, FilterValue item, String query) {
    if (filterSearchKey(item.label).contains(query)) return true;
    if (column == SalesColumn.date) {
      // `18.09`, `18.09.2026` and `1809` find `2026-09-18` too.
      final List<String> parts = item.value.split('-');
      if (parts.length == 3) {
        final String dotted = '${parts[2]}.${parts[1]}.${parts[0]}';
        if (dotted.contains(query)) return true;
        final String digits = query.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty &&
            (dotted.replaceAll('.', '').contains(digits) ||
                item.value.replaceAll('-', '').contains(digits))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Every value of [column] among the documents on the phone, newest first.
  List<String> _localValues(SalesColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Set<String> seen = <String>{};
      final List<String> out = <String>[];
      void add(String? value) {
        if (value == null) return;
        final String identity = _identity(column, value);
        if (identity.isEmpty) return;
        if (seen.add(identity)) out.add(value);
      }

      for (final Sale sale in _owner.knownSales) {
        switch (column) {
          case SalesColumn.number:
            add(sale.number);
          case SalesColumn.date:
            add(sale.date);
          case SalesColumn.customer:
            add(sale.customer);
          case SalesColumn.organization:
            add(sale.organization);
          case SalesColumn.manager:
            add(sale.manager);
          case SalesColumn.warehouse:
            add(sale.warehouse);
          case SalesColumn.kind:
            add(sale.docType?.toLowerCase());
          case SalesColumn.status:
            break;
          case SalesColumn.product:
            for (final SaleLine line in sale.lines ?? const <SaleLine>[]) {
              add(line.product);
            }
        }
      }
      return out;
    });
  }

  /// Every day from the newest document back to the oldest.
  ///
  /// A day on which nothing was sold is still listed — the list says which
  /// days exist, not which were busy, and finding out would mean reading
  /// every document. Choosing one costs a few one-row requests and says
  /// `tapılmadı`.
  List<String> _days() {
    final List<String> seen = _localValues(SalesColumn.date);
    String? newest;
    String? oldest = _oldest;
    for (final String day in seen) {
      if (newest == null || day.compareTo(newest) > 0) newest = day;
      if (oldest == null || day.compareTo(oldest) < 0) oldest = day;
    }
    final DateTime? from = newest == null ? null : DateTime.tryParse(newest);
    final DateTime? to = oldest == null ? null : DateTime.tryParse(oldest);
    if (from == null || to == null) return seen;

    final List<String> days = <String>[];
    DateTime day = DateTime.utc(from.year, from.month, from.day);
    final DateTime end = DateTime.utc(to.year, to.month, to.day);
    // Ten years of days at most, whatever a stray date says.
    while (!day.isBefore(end) && days.length < 3660) {
      days.add(
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}',
      );
      day = day.subtract(const Duration(days: 1));
    }
    return days;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
