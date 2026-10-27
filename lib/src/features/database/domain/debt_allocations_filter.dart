import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'debt_allocation.dart';

/// A column of the `Borc Bölgüsü` filter: every field the card shows, in
/// the card's order.
enum DebtAllocationsColumn implements DatabaseFilterColumn {
  manager('Menecer'),
  date('Tarix'),
  share('Bölgü');

  const DebtAllocationsColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-22): `search` is one
  /// case-insensitive substring of the manager's name or the sale's guid —
  /// `MÜHASİB` finds 659 rows, `gf20` 79 — and not of the date (`2026-10`,
  /// `07.10.2026`) or the amount. No other parameter (`manager_id`,
  /// `date_from`, `sort`, `min_allocated`) is honoured.
  bool get searchable => this == DebtAllocationsColumn.manager;

  /// Whether the column is narrowed by a run of months — a start and an
  /// end, each a month and a year — as `Menecer Statistikası`' `Dövr` is.
  bool get takesPeriod => this == DebtAllocationsColumn.date;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's rule for every
  /// figure on the tab since `Məhsullar`' price.
  bool get takesRange => this == DebtAllocationsColumn.share;
}

/// What `Borc Bölgüsü` is narrowed to: at most one manager, a run of months
/// and a span of amounts.
///
/// A manager is kept exactly as the bridge wrote them and compared through
/// [filterKey].
@immutable
class DebtAllocationsFilter {
  const DebtAllocationsFilter({
    this.manager,
    this.period = FilterPeriod.any,
    this.share = FilterRange.any,
  });

  static const DebtAllocationsFilter none = DebtAllocationsFilter();

  /// The manager chosen, or null.
  final String? manager;

  /// The months the sales are narrowed to — [FilterPeriod.any] when they
  /// are not.
  final FilterPeriod period;

  /// The span the amounts are narrowed to — [FilterRange.any] when they are
  /// not.
  final FilterRange share;

  bool get isEmpty => manager == null && period.isEmpty && share.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<DebtAllocationsColumn> get columns => <DebtAllocationsColumn>[
    for (final DebtAllocationsColumn column in DebtAllocationsColumn.values)
      if (has(column)) column,
  ];

  bool has(DebtAllocationsColumn column) => switch (column) {
    DebtAllocationsColumn.manager => manager != null,
    DebtAllocationsColumn.date => period.isNotEmpty,
    DebtAllocationsColumn.share => share.isNotEmpty,
  };

  List<String> valuesOf(DebtAllocationsColumn column) {
    final String? manager = this.manager;
    return column == DebtAllocationsColumn.manager && manager != null
        ? <String>[manager]
        : const <String>[];
  }

  bool isChosen(DebtAllocationsColumn column, String value) =>
      column == DebtAllocationsColumn.manager && manager == value;

  /// [value] chosen as the manager — or let go, if it already was.
  DebtAllocationsFilter toggle(DebtAllocationsColumn column, String value) {
    if (column != DebtAllocationsColumn.manager) return this;
    return DebtAllocationsFilter(
      manager: manager == value ? null : value,
      period: period,
      share: share,
    );
  }

  /// The amounts narrowed to [next]; an empty span lets go of them.
  DebtAllocationsFilter withShare(FilterRange next) => next == share
      ? this
      : DebtAllocationsFilter(manager: manager, period: period, share: next);

  /// The sales narrowed to [next]; an empty period lets go of them.
  DebtAllocationsFilter withPeriod(FilterPeriod next) => next == period
      ? this
      : DebtAllocationsFilter(manager: manager, period: next, share: share);

  /// [column] let go: `Hamısı`.
  DebtAllocationsFilter cleared(DebtAllocationsColumn column) =>
      switch (column) {
        DebtAllocationsColumn.manager =>
          manager == null
              ? this
              : DebtAllocationsFilter(period: period, share: share),
        DebtAllocationsColumn.date => withPeriod(FilterPeriod.any),
        DebtAllocationsColumn.share => withShare(FilterRange.any),
      };

  /// Whether [row] survives every column.
  ///
  /// A row whose date or amount 1C does not say is in no period and no
  /// span: its card says nothing about either.
  bool matches(DebtAllocation row) {
    final String? manager = this.manager;
    if (manager != null) {
      final String? name = row.manager;
      if (name == null || filterKey(name) != filterKey(manager)) return false;
    }
    if (period.isNotEmpty) {
      final FilterMonth? month = row.month;
      if (month == null || !period.contains(month)) return false;
    }
    if (share.isNotEmpty) {
      final double? allocated = row.allocated;
      if (allocated == null || !share.contains(allocated)) return false;
    }
    return true;
  }

  /// Whether [row] is past the last row this filter can let through, in a
  /// list that runs from the largest amount down — the bridge's order, the
  /// largest first, and in every answer to its `search` too (checked live
  /// on 2026-10-22: no row out of order in 5,989, nor in 659, 1,093 or
  /// 3,682 searched).
  ///
  /// So once one amount falls under the span, so does every one after it,
  /// and a filter with a minimum need not read the rest of the table.
  bool endsAt(DebtAllocation row) {
    final double? allocated = row.allocated;
    return allocated != null && share.isBelow(allocated);
  }

  @override
  bool operator ==(Object other) =>
      other is DebtAllocationsFilter &&
      other.manager == manager &&
      other.period == period &&
      other.share == share;

  @override
  int get hashCode => Object.hash(manager, period, share);

  @override
  String toString() => 'DebtAllocationsFilter($manager, $period, $share)';
}
