import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'stock_item.dart';

/// A column of the `Stok` filter: the website's five, in its order.
enum StockColumn implements DatabaseFilterColumn {
  code('Kod'),
  product('Məhsul'),
  warehouse('Anbar'),
  quantity('Miqdar'),
  date('Tarix');

  const StockColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-09-25): `search` on `/onec-data/stock/`
  /// is one case-insensitive substring over the product's code, its name and
  /// the warehouse — `istehsalat` finds all 336 of that warehouse's rows —
  /// and nothing else: not a date, not a quantity.
  bool get searchable =>
      this == StockColumn.code ||
      this == StockColumn.product ||
      this == StockColumn.warehouse;
}

/// Where the website's stock badge turns from green to amber: more than this
/// is plenty, this or less is running low.
const double kStockLowThreshold = 10;

/// The values of the `Miqdar` column: the two colours the website's badge
/// gives a balance.
///
/// Its third — red, `Bitib` — is left out on purpose: 1C keeps no row for a
/// balance of nothing, so the bridge's table has none (not one of 799 on
/// 2026-09-25), and a filter that could never find one would read as "no
/// product has run out".
enum StockLevel {
  plenty('10-dan çox'),
  low('10 və daha az');

  const StockLevel(this.label);

  final String label;

  bool matches(double? quantity) {
    if (quantity == null) return false;
    return switch (this) {
      StockLevel.plenty => quantity > kStockLowThreshold,
      StockLevel.low => quantity <= kStockLowThreshold,
    };
  }

  static StockLevel? byName(String name) {
    for (final StockLevel level in values) {
      if (level.name == name) return level;
    }
    return null;
  }
}

/// What `Stok` is narrowed to: at most one value a column.
///
/// A value is kept exactly as the bridge wrote it — spacing included — and
/// compared through [filterKey], so a warehouse picked from the catalogue
/// matches the same warehouse on a row even where one of the two has a
/// trailing space.
@immutable
class StockFilter {
  const StockFilter._(this._chosen);

  static const StockFilter none = StockFilter._(<StockColumn, String>{});

  final Map<StockColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => _chosen.isNotEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the website's order.
  List<StockColumn> get columns => <StockColumn>[
    for (final StockColumn column in StockColumn.values)
      if (_chosen.containsKey(column)) column,
  ];

  bool has(StockColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(StockColumn column) => _chosen[column];

  List<String> valuesOf(StockColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(StockColumn column, String value) => _chosen[column] == value;

  /// The `Miqdar` value, when one is chosen.
  StockLevel? get level {
    final String? value = _chosen[StockColumn.quantity];
    return value == null ? null : StockLevel.byName(value);
  }

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one product; then the product's name, which names about as few;
  /// then the warehouse, which narrows 799 rows to a few hundred at most.
  StockColumn? get searchColumn {
    for (final StockColumn column in StockColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held: one warehouse at a time.
  StockFilter toggle(StockColumn column, String value) {
    final Map<StockColumn, String> next = Map<StockColumn, String>.of(_chosen);
    if (next[column] == value) {
      next.remove(column);
    } else {
      next[column] = value;
    }
    return StockFilter._(Map<StockColumn, String>.unmodifiable(next));
  }

  /// [column] let go: `Hamısı`.
  StockFilter cleared(StockColumn column) {
    if (!_chosen.containsKey(column)) return this;
    final Map<StockColumn, String> next = Map<StockColumn, String>.of(_chosen)
      ..remove(column);
    return StockFilter._(Map<StockColumn, String>.unmodifiable(next));
  }

  /// Whether [item] survives every column.
  bool matches(StockItem item) {
    for (final MapEntry<StockColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, item)) return false;
    }
    return true;
  }

  static bool _matches(StockColumn column, String value, StockItem item) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      StockColumn.code => same(item.code),
      StockColumn.product => same(item.product),
      StockColumn.warehouse => same(item.warehouse),
      StockColumn.quantity =>
        StockLevel.byName(value)?.matches(item.quantity) ?? true,
      StockColumn.date => item.date == value,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StockFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<StockColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'StockFilter($_chosen)';
}
