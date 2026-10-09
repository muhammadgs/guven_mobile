import 'package:flutter/foundation.dart';

import 'bank_account.dart';
import 'database_filter.dart';

/// A column of the `Bank Hesabları` filter: every field a row carries, in
/// the card's order. The figures only an account's own answer has — the
/// payments, what came in and went out, the balance — are not columns:
/// filtering by them would ask for every account on its own.
enum BankAccountsColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Hesab adı'),
  bank('Bank'),
  number('Hesab nömrəsi'),
  currency('Valyuta'),
  kind('Növ'),
  status('Status');

  const BankAccountsColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-08): `search` on `/bank-accounts/`
  /// is one case-insensitive substring over the account's code, name and
  /// number — `0003` finds `NT0000003`, `PAHA` the three Pasha IBANs — and
  /// nothing else: not the bank (`Pasha Bank Biznes` finds none, though two
  /// accounts are held there), not the currency, and with no folding of `ı`
  /// (`yapi` finds none).
  bool get searchable =>
      this == BankAccountsColumn.code ||
      this == BankAccountsColumn.name ||
      this == BankAccountsColumn.number;

  /// Whether the column's values can only all be known by reading every
  /// account: the bridge cannot list the banks or the currencies.
  bool get needsEveryone =>
      this == BankAccountsColumn.bank || this == BankAccountsColumn.currency;
}

/// The `Növ` column's two values: the website's `Əsas` and `Əlavə`.
///
/// No account was the default on 2026-10-08, but 1C can make one so and the
/// website has a word for it, so both are offered.
enum BankAccountKind {
  main('Əsas'),
  extra('Əlavə');

  const BankAccountKind(this.label);

  final String label;

  /// An account whose kind 1C does not say is neither.
  bool matches(BankAccount account) =>
      account.isDefault != null &&
      account.isDefault == (this == BankAccountKind.main);

  static BankAccountKind? byName(String name) {
    for (final BankAccountKind kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// The `Status` column's two values: the website's `Aktiv` and `Deaktiv`.
enum BankAccountStatus {
  active('Aktiv'),
  inactive('Deaktiv');

  const BankAccountStatus(this.label);

  final String label;

  /// An account whose status 1C does not say is neither.
  bool matches(BankAccount account) =>
      account.active != null &&
      account.active == (this == BankAccountStatus.active);

  static BankAccountStatus? byName(String name) {
    for (final BankAccountStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// What `Bank Hesabları` is narrowed to: at most one value a column.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class BankAccountsFilter {
  const BankAccountsFilter._(this._chosen);

  static const BankAccountsFilter none = BankAccountsFilter._(
    <BankAccountsColumn, String>{},
  );

  final Map<BankAccountsColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the card's order.
  List<BankAccountsColumn> get columns => <BankAccountsColumn>[
    for (final BankAccountsColumn column in BankAccountsColumn.values)
      if (has(column)) column,
  ];

  bool has(BankAccountsColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(BankAccountsColumn column) => _chosen[column];

  List<String> valuesOf(BankAccountsColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(BankAccountsColumn column, String value) =>
      _chosen[column] == value;

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one account, then the name, then the number.
  BankAccountsColumn? get searchColumn {
    for (final BankAccountsColumn column in BankAccountsColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  BankAccountsFilter toggle(BankAccountsColumn column, String value) {
    final Map<BankAccountsColumn, String> chosen =
        Map<BankAccountsColumn, String>.of(_chosen);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
    }
    return BankAccountsFilter._(
      Map<BankAccountsColumn, String>.unmodifiable(chosen),
    );
  }

  /// [column] let go: `Hamısı`.
  BankAccountsFilter cleared(BankAccountsColumn column) {
    if (!has(column)) return this;
    return BankAccountsFilter._(
      Map<BankAccountsColumn, String>.unmodifiable(
        Map<BankAccountsColumn, String>.of(_chosen)..remove(column),
      ),
    );
  }

  /// Whether [account] survives every column.
  bool matches(BankAccount account) {
    for (final MapEntry<BankAccountsColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, account)) return false;
    }
    return true;
  }

  static bool _matches(
    BankAccountsColumn column,
    String value,
    BankAccount account,
  ) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      BankAccountsColumn.code => same(account.code),
      BankAccountsColumn.name => same(account.name),
      BankAccountsColumn.bank => same(account.bankName),
      BankAccountsColumn.number => same(account.number),
      BankAccountsColumn.currency => same(account.currency),
      BankAccountsColumn.kind =>
        BankAccountKind.byName(value)?.matches(account) ?? true,
      BankAccountsColumn.status =>
        BankAccountStatus.byName(value)?.matches(account) ?? true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BankAccountsFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<BankAccountsColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'BankAccountsFilter($_chosen)';
}
