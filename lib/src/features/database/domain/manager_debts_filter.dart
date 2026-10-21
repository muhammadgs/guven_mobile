import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'manager_debt.dart';

/// A column of the `Menecer Borcları` filter: every field the card shows, in
/// the card's order.
enum ManagerDebtsColumn implements DatabaseFilterColumn {
  manager('Menecer'),
  orders('Sifariş'),
  sales('Satış'),
  debt('Debet'),
  collected('Yığılmış'),
  share('Statistika');

  const ManagerDebtsColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-21): `search` is one
  /// case-insensitive substring of the manager's name — `MÜHASİB` finds
  /// three, `_s1` five — and nothing else.
  bool get searchable => this == ManagerDebtsColumn.manager;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's rule for every
  /// figure on the tab since `Məhsullar`' price. The share is a figure too.
  bool get takesRange => this != ManagerDebtsColumn.manager;
}

/// What `Menecer Borcları` is narrowed to: at most one manager, and a span
/// for any of the figures.
///
/// A name is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class ManagerDebtsFilter {
  const ManagerDebtsFilter._(this._chosen, this._ranges);

  static const ManagerDebtsFilter none = ManagerDebtsFilter._(
    <ManagerDebtsColumn, String>{},
    <ManagerDebtsColumn, FilterRange>{},
  );

  final Map<ManagerDebtsColumn, String> _chosen;
  final Map<ManagerDebtsColumn, FilterRange> _ranges;

  bool get isEmpty => _chosen.isEmpty && _ranges.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<ManagerDebtsColumn> get columns => <ManagerDebtsColumn>[
    for (final ManagerDebtsColumn column in ManagerDebtsColumn.values)
      if (has(column)) column,
  ];

  bool has(ManagerDebtsColumn column) =>
      _chosen.containsKey(column) || _ranges.containsKey(column);

  /// The column's value, or null.
  String? valueOf(ManagerDebtsColumn column) => _chosen[column];

  List<String> valuesOf(ManagerDebtsColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(ManagerDebtsColumn column, String value) =>
      _chosen[column] == value;

  /// The column's span — open at both ends when it has none.
  FilterRange rangeOf(ManagerDebtsColumn column) =>
      _ranges[column] ?? FilterRange.any;

  /// The column worth sending to the bridge as `search`: the manager.
  ManagerDebtsColumn? get searchColumn {
    for (final ManagerDebtsColumn column in ManagerDebtsColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  ManagerDebtsFilter toggle(ManagerDebtsColumn column, String value) {
    final Map<ManagerDebtsColumn, String> chosen =
        Map<ManagerDebtsColumn, String>.of(_chosen);
    final Map<ManagerDebtsColumn, FilterRange> ranges =
        Map<ManagerDebtsColumn, FilterRange>.of(_ranges);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
      ranges.remove(column);
    }
    return ManagerDebtsFilter._freeze(chosen, ranges);
  }

  /// [column] narrowed to [range]; an empty span lets go of it.
  ManagerDebtsFilter withRange(ManagerDebtsColumn column, FilterRange range) {
    final Map<ManagerDebtsColumn, FilterRange> ranges =
        Map<ManagerDebtsColumn, FilterRange>.of(_ranges);
    if (range.isEmpty) {
      if (!ranges.containsKey(column)) return this;
      ranges.remove(column);
    } else {
      ranges[column] = range;
    }
    return ManagerDebtsFilter._freeze(
      Map<ManagerDebtsColumn, String>.of(_chosen)..remove(column),
      ranges,
    );
  }

  /// [column] let go: `Hamısı`.
  ManagerDebtsFilter cleared(ManagerDebtsColumn column) {
    if (!has(column)) return this;
    return ManagerDebtsFilter._freeze(
      Map<ManagerDebtsColumn, String>.of(_chosen)..remove(column),
      Map<ManagerDebtsColumn, FilterRange>.of(_ranges)..remove(column),
    );
  }

  static ManagerDebtsFilter _freeze(
    Map<ManagerDebtsColumn, String> chosen,
    Map<ManagerDebtsColumn, FilterRange> ranges,
  ) => ManagerDebtsFilter._(
    Map<ManagerDebtsColumn, String>.unmodifiable(chosen),
    Map<ManagerDebtsColumn, FilterRange>.unmodifiable(ranges),
  );

  /// The figure [column] shows for [row], or null — a column of names has
  /// none. The share is the one the card prints, so a span typed off a card
  /// holds that card.
  static double? figureOf(ManagerDebtsColumn column, ManagerDebt row) =>
      switch (column) {
        ManagerDebtsColumn.manager => null,
        ManagerDebtsColumn.orders => row.orders?.toDouble(),
        ManagerDebtsColumn.sales => row.sales,
        ManagerDebtsColumn.debt => row.debt,
        ManagerDebtsColumn.collected => row.collected,
        ManagerDebtsColumn.share => row.collectedPercent,
      };

  /// Whether [row] survives every column. A figure 1C does not give is in no
  /// span.
  bool matches(ManagerDebt row) {
    for (final MapEntry<ManagerDebtsColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, row)) return false;
    }
    for (final MapEntry<ManagerDebtsColumn, FilterRange> entry
        in _ranges.entries) {
      final double? figure = figureOf(entry.key, row);
      if (figure == null || !entry.value.contains(figure)) return false;
    }
    return true;
  }

  static bool _matches(
    ManagerDebtsColumn column,
    String value,
    ManagerDebt row,
  ) {
    final String? manager = row.manager;
    return switch (column) {
      ManagerDebtsColumn.manager =>
        manager != null && filterKey(manager) == filterKey(value),
      // A figure is narrowed by a span, never by a value.
      _ => true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ManagerDebtsFilter &&
      mapEquals(other._chosen, _chosen) &&
      mapEquals(other._ranges, _ranges);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ManagerDebtsColumn, String> entry in _chosen.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ManagerDebtsColumn, FilterRange> entry
          in _ranges.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => 'ManagerDebtsFilter($_chosen, $_ranges)';
}
