import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/customer.dart';
import '../domain/customers_filter.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../presentation/database_format.dart';
import 'customers_controller.dart';
import 'database_filter_source.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kCustomersValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
/// One letter finds most of the directory; the second one is worth waiting
/// for.
const int kCustomersValueSearchMin = 2;

/// How many customers a typed search reads for its values: the list shows
/// five or six at a time, and another letter narrows it further.
const int kCustomersValueSearchSize = 20;

/// The values the open column of the `Müştərilər` filter offers, for what
/// has been typed into its search — each column its own, and all of them:
///
/// * `Kod / VÖEN`, `Müştəri` — the ones on the phone, and while typing the
///   ones the bridge finds, since its `search` reads names, codes and VÖENs;
/// * `Növ` — `Hüquqi` and `Fiziki`;
/// * `Ödəniş müddəti` — every term in the directory, shortest first. The
///   bridge cannot list them, so the first time the column opens the rest
///   of the directory is read ([CustomersController.readAll]) and the
///   column says how far that has got rather than listing values that
///   would still move under a finger.
class CustomersFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  CustomersFilterValues(this._owner, this._api) {
    _owner.addListener(_ownerChanged);
  }

  final CustomersController _owner;
  final DatabaseApi _api;

  CustomersColumn? _column;

  @override
  CustomersColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  /// True while the open column waits for every customer before it lists
  /// anything.
  bool _waiting = false;

  @override
  bool get isSearching => _searching || _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    if (total == null || total == 0) return 'Müştərilər oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} müştəri oxundu';
  }

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  Timer? _debounce;
  int _serial = 0;
  bool _disposed = false;

  /// What the bridge answered, by column and query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  final Map<CustomersColumn, List<String>> _local =
      <CustomersColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(CustomersColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));

    _waiting = false;
    if (column.needsEveryCustomer && !_owner.hasEveryCustomer) {
      // Returns at once if the reading is already under way.
      _owner.readAll();
      _waiting = _owner.isReadingAll;
    }
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _waiting = false;
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text], and asks the bridge once typing pauses.
  @override
  void search(String text) {
    final CustomersColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column.searchable &&
        !_owner.hasEveryCustomer &&
        query.length >= kCustomersValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kCustomersValueSearchDelay, () => _ask(column, query));
    }
    notifyListeners();
  }

  static String _answerKey(CustomersColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  /// What [customer] says in [column], for the columns a value is read off.
  static String? _field(CustomersColumn column, Customer customer) =>
      switch (column) {
        CustomersColumn.code => customer.taxIdOrCode,
        CustomersColumn.name => customer.name,
        CustomersColumn.payment =>
          customer.paymentTerm == null ? null : '${customer.paymentDays}',
        CustomersColumn.type => null,
      };

  /// The codes or names of the customers the bridge finds for [query]. Its
  /// `search` reads both, so the answer is narrowed to the values that
  /// actually hold what was typed.
  Future<void> _ask(CustomersColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<Customer> page = await _api.customersPage(
        page: 1,
        pageSize: kCustomersValueSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[_answerKey(column, query)] = <String>[
        for (final Customer customer in page.rows)
          if (_field(column, customer) case final String value
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

  /// The owner has moved on: rows arrived, or the directory has been read.
  void _ownerChanged() {
    final CustomersColumn? column = _column;
    if (column == null || !_waiting || _owner.isReadingAll) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final CustomersColumn? column = _column;
    if (column == null || _waiting) {
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
      case CustomersColumn.code || CustomersColumn.name:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
      case CustomersColumn.payment:
        _localValues(column).forEach(add);
      case CustomersColumn.type:
        for (final CustomerType type in CustomerType.values) {
          add(type.name);
        }
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(CustomersColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kCustomersValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(CustomersColumn column, String value) =>
      switch (column) {
        CustomersColumn.type || CustomersColumn.payment => value,
        _ => filterKey(value),
      };

  static FilterValue _valueOf(CustomersColumn column, String value) =>
      switch (column) {
        CustomersColumn.type => FilterValue(
          value,
          CustomerType.byName(value)?.label ?? value,
        ),
        CustomersColumn.payment => FilterValue(value, '$value gün'),
        _ => FilterValue(value, tidySpaces(value)),
      };

  /// Every value of [column] among the customers on the phone: codes and
  /// names in the list's order, terms shortest first.
  List<String> _localValues(CustomersColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Map<String, String> first = <String, String>{};
      for (final Customer customer in _owner.knownCustomers) {
        final String? value = _field(column, customer);
        if (value == null) continue;
        final String identity = _identity(column, value);
        if (identity.isEmpty) continue;
        first.putIfAbsent(identity, () => value);
      }
      final List<String> identities = first.keys.toList();
      if (column == CustomersColumn.payment) {
        identities.sort(
          (String a, String b) => int.parse(a).compareTo(int.parse(b)),
        );
      }
      return <String>[
        for (final String identity in identities) first[identity]!,
      ];
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _owner.removeListener(_ownerChanged);
    super.dispose();
  }
}
