import 'package:flutter/foundation.dart';

import 'cash_desk.dart';
import 'database_filter.dart';

/// A column of the `Kassalar` filter: every field the card shows, in the
/// card's order.
enum CashDesksColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Kassa adı'),
  currency('Valyuta'),
  status('Status');

  const CashDesksColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-05): `search` on `/cash-desks/` is
  /// one case-insensitive substring over the desk's code and name — `0002`
  /// finds `NT0000002`, `KASSA` all three — and nothing else: not the
  /// currency (`AZN` finds none), not the guid, and with no folding of `ə`
  /// (`nerimanov` finds none).
  bool get searchable =>
      this == CashDesksColumn.code || this == CashDesksColumn.name;

  /// Whether the column's values can only all be known by reading every
  /// desk: the bridge cannot list the currencies.
  bool get needsEveryone => this == CashDesksColumn.currency;
}

/// The `Status` column's two values: the website's `Aktiv` and `Deaktiv`.
///
/// Every desk was active on 2026-10-05, but 1C can switch one off and the
/// website has a word for it, so both are offered.
enum CashDeskStatus {
  active('Aktiv'),
  inactive('Deaktiv');

  const CashDeskStatus(this.label);

  final String label;

  /// A desk whose status 1C does not say is neither.
  bool matches(CashDesk desk) =>
      desk.active != null && desk.active == (this == CashDeskStatus.active);

  static CashDeskStatus? byName(String name) {
    for (final CashDeskStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// What `Kassalar` is narrowed to: at most one value a column.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class CashDesksFilter {
  const CashDesksFilter._(this._chosen);

  static const CashDesksFilter none = CashDesksFilter._(
    <CashDesksColumn, String>{},
  );

  final Map<CashDesksColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the card's order.
  List<CashDesksColumn> get columns => <CashDesksColumn>[
    for (final CashDesksColumn column in CashDesksColumn.values)
      if (has(column)) column,
  ];

  bool has(CashDesksColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(CashDesksColumn column) => _chosen[column];

  List<String> valuesOf(CashDesksColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(CashDesksColumn column, String value) =>
      _chosen[column] == value;

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one desk, then the name.
  CashDesksColumn? get searchColumn {
    for (final CashDesksColumn column in CashDesksColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  CashDesksFilter toggle(CashDesksColumn column, String value) {
    final Map<CashDesksColumn, String> chosen = Map<CashDesksColumn, String>.of(
      _chosen,
    );
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
    }
    return CashDesksFilter._(Map<CashDesksColumn, String>.unmodifiable(chosen));
  }

  /// [column] let go: `Hamısı`.
  CashDesksFilter cleared(CashDesksColumn column) {
    if (!has(column)) return this;
    return CashDesksFilter._(
      Map<CashDesksColumn, String>.unmodifiable(
        Map<CashDesksColumn, String>.of(_chosen)..remove(column),
      ),
    );
  }

  /// Whether [desk] survives every column.
  bool matches(CashDesk desk) {
    for (final MapEntry<CashDesksColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, desk)) return false;
    }
    return true;
  }

  static bool _matches(CashDesksColumn column, String value, CashDesk desk) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      CashDesksColumn.code => same(desk.code),
      CashDesksColumn.name => same(desk.name),
      CashDesksColumn.currency => same(desk.currency),
      CashDesksColumn.status =>
        CashDeskStatus.byName(value)?.matches(desk) ?? true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CashDesksFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<CashDesksColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'CashDesksFilter($_chosen)';
}
