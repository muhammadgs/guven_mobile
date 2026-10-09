import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/bank_account.dart';
import '../domain/bank_accounts_filter.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../presentation/database_format.dart';
import 'bank_accounts_controller.dart';
import 'database_filter_source.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kBankAccountsValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
const int kBankAccountsValueSearchMin = 2;

/// How many accounts a typed search reads for its values.
const int kBankAccountsValueSearchSize = 20;

/// The values the open column of the `Bank Hesabları` filter offers, for
/// what has been typed into its search — each column its own, and all of
/// them:
///
/// * `Kod`, `Hesab adı`, `Hesab nömrəsi` — the ones on the phone, and while
///   typing the ones the bridge finds;
/// * `Bank`, `Valyuta` — every one in the catalogue, the most common first.
///   The bridge cannot list them, so the first time either column opens the
///   rest of the catalogue is read ([BankAccountsController.readAll]) and
///   the column says how far that has got rather than listing values that
///   would still move under a finger;
/// * `Növ` — `Əsas` and `Əlavə`; `Status` — `Aktiv` and `Deaktiv`.
class BankAccountsFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  BankAccountsFilterValues(this._owner, this._api) {
    _owner.addListener(_ownerChanged);
  }

  final BankAccountsController _owner;
  final DatabaseApi _api;

  BankAccountsColumn? _column;

  @override
  BankAccountsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  /// True while the open column waits for everyone before it lists anything.
  bool _waiting = false;

  @override
  bool get isSearching => _searching || _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    if (total == null || total == 0) return 'Bank hesabları oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} hesab oxundu';
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

  final Map<BankAccountsColumn, List<String>> _local =
      <BankAccountsColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(BankAccountsColumn column) {
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
    final BankAccountsColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column.searchable &&
        !_owner.hasEveryone &&
        query.length >= kBankAccountsValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(
        kBankAccountsValueSearchDelay,
        () => _ask(column, query),
      );
    }
    notifyListeners();
  }

  static String _answerKey(BankAccountsColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  /// What [account] says in [column], for the columns a value is read off.
  static String? _field(BankAccountsColumn column, BankAccount account) =>
      switch (column) {
        BankAccountsColumn.code => account.code,
        BankAccountsColumn.name => account.name,
        BankAccountsColumn.bank => account.bankName,
        BankAccountsColumn.number => account.number,
        BankAccountsColumn.currency => account.currency,
        BankAccountsColumn.kind || BankAccountsColumn.status => null,
      };

  /// The values of [column] among the accounts the bridge finds for
  /// [query]. Its `search` reads three fields at once, so the answer is
  /// narrowed to the values that actually hold what was typed.
  Future<void> _ask(BankAccountsColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<BankAccount> page = await _api.bankAccountsPage(
        page: 1,
        pageSize: kBankAccountsValueSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[_answerKey(column, query)] = <String>[
        for (final BankAccount account in page.rows)
          if (_field(column, account) case final String value
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

  /// The owner has moved on: rows arrived, or the catalogue has been read.
  void _ownerChanged() {
    final BankAccountsColumn? column = _column;
    if (column == null || !_waiting || _owner.isReadingAll) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final BankAccountsColumn? column = _column;
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
      case BankAccountsColumn.code ||
          BankAccountsColumn.name ||
          BankAccountsColumn.number:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
      case BankAccountsColumn.bank || BankAccountsColumn.currency:
        _localValues(column).forEach(add);
      case BankAccountsColumn.kind:
        for (final BankAccountKind kind in BankAccountKind.values) {
          add(kind.name);
        }
      case BankAccountsColumn.status:
        for (final BankAccountStatus status in BankAccountStatus.values) {
          add(status.name);
        }
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(BankAccountsColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kBankAccountsValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(BankAccountsColumn column, String value) =>
      switch (column) {
        BankAccountsColumn.kind || BankAccountsColumn.status => value,
        _ => filterKey(value),
      };

  static FilterValue _valueOf(BankAccountsColumn column, String value) =>
      switch (column) {
        BankAccountsColumn.kind => FilterValue(
          value,
          BankAccountKind.byName(value)?.label ?? value,
        ),
        BankAccountsColumn.status => FilterValue(
          value,
          BankAccountStatus.byName(value)?.label ?? value,
        ),
        _ => FilterValue(value, tidySpaces(value)),
      };

  /// Every value of [column] among the accounts on the phone: codes, names
  /// and numbers in the list's order, banks and currencies most common
  /// first.
  List<String> _localValues(BankAccountsColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Map<String, String> first = <String, String>{};
      final Map<String, int> counts = <String, int>{};
      for (final BankAccount account in _owner.knownAccounts) {
        final String? value = _field(column, account);
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
