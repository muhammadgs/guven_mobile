import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'warehouse.dart';

/// A column of the `Anbarlar` filter: every field the card shows, in the
/// card's order.
enum WarehousesColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Anbar adı'),
  type('Növü'),
  status('Status');

  const WarehousesColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-09): `search` on `/warehouses/` is a
  /// case-insensitive substring of the name — `anbar` finds five, `Səməd`
  /// one — with no folding of `ə` (`nerimanov` finds none), and not of the
  /// kind (`Standart`, `default` find none). Whether it reads the code
  /// could not be seen, every code being blank, so a code is looked for on
  /// the phone, never sent.
  bool get searchable => this == WarehousesColumn.name;

  /// Whether the column's values can only all be known by reading every
  /// warehouse: the bridge cannot list the kinds, and is not trusted with
  /// the codes.
  bool get needsEveryone =>
      this == WarehousesColumn.code || this == WarehousesColumn.type;
}

/// The `Status` column's two values: the website's `Aktiv` and `Deaktiv`.
///
/// Every warehouse was active on 2026-10-09, but 1C can switch one off and
/// the website has a word for it, so both are offered.
enum WarehouseStatus {
  active('Aktiv'),
  inactive('Deaktiv');

  const WarehouseStatus(this.label);

  final String label;

  /// A warehouse whose status 1C does not say is neither.
  bool matches(Warehouse warehouse) =>
      warehouse.active != null &&
      warehouse.active == (this == WarehouseStatus.active);

  static WarehouseStatus? byName(String name) {
    for (final WarehouseStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// What `Anbarlar` is narrowed to: at most one value a column.
///
/// A value is kept exactly as the bridge wrote it — a kind as the card words
/// it, `Standart` — and compared through [filterKey].
@immutable
class WarehousesFilter {
  const WarehousesFilter._(this._chosen);

  static const WarehousesFilter none = WarehousesFilter._(
    <WarehousesColumn, String>{},
  );

  final Map<WarehousesColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the card's order.
  List<WarehousesColumn> get columns => <WarehousesColumn>[
    for (final WarehousesColumn column in WarehousesColumn.values)
      if (has(column)) column,
  ];

  bool has(WarehousesColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(WarehousesColumn column) => _chosen[column];

  List<String> valuesOf(WarehousesColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(WarehousesColumn column, String value) =>
      _chosen[column] == value;

  /// The column worth sending to the bridge as `search`: the name, the one
  /// it is known to read.
  WarehousesColumn? get searchColumn {
    for (final WarehousesColumn column in WarehousesColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  WarehousesFilter toggle(WarehousesColumn column, String value) {
    final Map<WarehousesColumn, String> chosen =
        Map<WarehousesColumn, String>.of(_chosen);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
    }
    return WarehousesFilter._(
      Map<WarehousesColumn, String>.unmodifiable(chosen),
    );
  }

  /// [column] let go: `Hamısı`.
  WarehousesFilter cleared(WarehousesColumn column) {
    if (!has(column)) return this;
    return WarehousesFilter._(
      Map<WarehousesColumn, String>.unmodifiable(
        Map<WarehousesColumn, String>.of(_chosen)..remove(column),
      ),
    );
  }

  /// Whether [warehouse] survives every column.
  bool matches(Warehouse warehouse) {
    for (final MapEntry<WarehousesColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, warehouse)) return false;
    }
    return true;
  }

  static bool _matches(
    WarehousesColumn column,
    String value,
    Warehouse warehouse,
  ) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      WarehousesColumn.code => same(warehouse.code),
      WarehousesColumn.name => same(warehouse.name),
      WarehousesColumn.type => same(warehouse.typeLabel),
      WarehousesColumn.status =>
        WarehouseStatus.byName(value)?.matches(warehouse) ?? true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is WarehousesFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<WarehousesColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'WarehousesFilter($_chosen)';
}
