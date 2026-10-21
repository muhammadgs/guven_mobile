import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/debt.dart';
import '../domain/debts_filter.dart';
import '../presentation/database_format.dart';
import 'database_filter_source.dart';
import 'debts_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kDebtsValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
const int kDebtsValueSearchMin = 2;

/// How many rows a typed search reads for its values.
const int kDebtsValueSearchSize = 20;

/// The values the open column of the `Kreditorlar` or `Debitorlar` filter
/// offers, for what has been typed into its search — each column its own:
///
/// * `Kontraqent` — the ones on the phone, and while typing the ones the
///   bridge finds;
/// * `Təşkilat`, `Müqavilə` — every one in the list, the most common first.
///   The bridge cannot list them, so the first time one of them opens the
///   rest of the list is read ([DebtsController.readAll]) and the column
///   says how far that has got rather than listing values that would still
///   move under a finger;
/// * `Status` — `Açıq borc` and `Ödənilib`. The amounts are only spans, and
///   list nothing.
class DebtsFilterValues extends ChangeNotifier implements DatabaseFilterValues {
  DebtsFilterValues(this._owner) {
    _owner.addListener(_ownerChanged);
  }

  final DebtsController _owner;

  DebtsColumn? _column;

  @override
  DebtsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  /// True while the open column waits for every row before it lists
  /// anything.
  bool _waiting = false;

  @override
  bool get isSearching => _searching || _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    final String unit = _owner.kind.unit;
    if (total == null || total == 0) return '${unit.capitalized}lar oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} $unit oxundu';
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

  final Map<DebtsColumn, List<String>> _local = <DebtsColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(DebtsColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));

    _waiting = false;
    if (column.needsEveryone && !_owner.hasEveryone) {
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
    final DebtsColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column.searchable &&
        !_owner.hasEveryone &&
        query.length >= kDebtsValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kDebtsValueSearchDelay, () => _ask(column, query));
    }
    notifyListeners();
  }

  static String _answerKey(DebtsColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  /// What [debt] says in [column], for the columns a value is read off.
  static String? _field(DebtsColumn column, Debt debt) => switch (column) {
    DebtsColumn.contractor => debt.contractor,
    DebtsColumn.organization => debt.organization,
    DebtsColumn.contract => debt.contract,
    DebtsColumn.debt ||
    DebtsColumn.ourDebt ||
    DebtsColumn.settlement ||
    DebtsColumn.status => null,
  };

  /// The values of [column] among the rows the bridge finds for [query]. Its
  /// `search` reads two fields at once, so the answer is narrowed to the
  /// values that actually hold what was typed.
  Future<void> _ask(DebtsColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<Debt> page = await _owner.fetch(
        page: 1,
        pageSize: kDebtsValueSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[_answerKey(column, query)] = <String>[
        for (final Debt debt in page.rows)
          if (_field(column, debt) case final String value
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

  /// The owner has moved on: rows arrived, or the list has been read.
  void _ownerChanged() {
    final DebtsColumn? column = _column;
    if (column == null || !_waiting || _owner.isReadingAll) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final DebtsColumn? column = _column;
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
      case DebtsColumn.contractor:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
      case DebtsColumn.organization || DebtsColumn.contract:
        _localValues(column).forEach(add);
      case DebtsColumn.status:
        for (final DebtStatus status in DebtStatus.values) {
          add(status.name);
        }
      case DebtsColumn.debt || DebtsColumn.ourDebt || DebtsColumn.settlement:
        break;
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(DebtsColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kDebtsValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(DebtsColumn column, String value) =>
      column == DebtsColumn.status ? value : filterKey(value);

  static FilterValue _valueOf(DebtsColumn column, String value) =>
      column == DebtsColumn.status
      ? FilterValue(value, DebtStatus.byName(value)?.label ?? value)
      : FilterValue(value, tidySpaces(value));

  /// Every value of [column] among the rows on the phone: counterparties in
  /// the list's order — the largest debt first — organisations and
  /// contracts most common first.
  List<String> _localValues(DebtsColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Map<String, String> first = <String, String>{};
      final Map<String, int> counts = <String, int>{};
      for (final Debt debt in _owner.knownDebts) {
        final String? value = _field(column, debt);
        if (value == null) continue;
        final String identity = _identity(column, value);
        if (identity.isEmpty) continue;
        first.putIfAbsent(identity, () => value);
        counts[identity] = (counts[identity] ?? 0) + 1;
      }
      final List<String> identities = first.keys.toList();
      if (column.needsEveryone) {
        // Stable: equally common values keep the order they were met in.
        final Map<String, int> met = <String, int>{
          for (int i = 0; i < identities.length; i++) identities[i]: i,
        };
        identities.sort((String a, String b) {
          final int byCount = counts[b]!.compareTo(counts[a]!);
          return byCount != 0 ? byCount : met[a]!.compareTo(met[b]!);
        });
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

extension on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
