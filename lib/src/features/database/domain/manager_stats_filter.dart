import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'manager_stat.dart';

/// A column of the `Menecer statistikası` filter: every field the card
/// shows, in the card's order.
enum ManagerStatsColumn implements DatabaseFilterColumn {
  manager('Menecer'),
  period('Dövr'),
  orders('Sifariş'),
  amount('Cəmi məbləğ');

  const ManagerStatsColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-05): `search` on
  /// `/onec-data/manager-stats/` is one case-insensitive substring of the
  /// manager's name — `MÜHASİB` finds all three `Mühasib…` — and nothing
  /// else: not `07`, `2026` or `07.2026`, not a figure. No other parameter
  /// (`year`, `month`, `date_from`, `period`) is honoured either.
  bool get searchable => this == ManagerStatsColumn.manager;

  /// Whether the column is narrowed by a run of months — the user's rule
  /// for `Dövr` (2026-10-05): a start and an end, each a month and a year.
  bool get takesPeriod => this == ManagerStatsColumn.period;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's rule for every
  /// figure on the tab since `Məhsullar`' price.
  bool get takesRange =>
      this == ManagerStatsColumn.orders || this == ManagerStatsColumn.amount;

  /// Whether the column needs every row on the phone before it can offer
  /// anything: the bridge lists neither the managers nor the months.
  bool get needsEveryone =>
      this == ManagerStatsColumn.manager || this == ManagerStatsColumn.period;
}

/// What `Menecer statistikası` is narrowed to: at most one manager, a run
/// of months, and a span for each figure.
///
/// A manager is kept exactly as the bridge wrote them and compared through
/// [filterKey].
@immutable
class ManagerStatsFilter {
  const ManagerStatsFilter._(this._chosen, this._ranges, this.period);

  static const ManagerStatsFilter none = ManagerStatsFilter._(
    <ManagerStatsColumn, String>{},
    <ManagerStatsColumn, FilterRange>{},
    FilterPeriod.any,
  );

  final Map<ManagerStatsColumn, String> _chosen;
  final Map<ManagerStatsColumn, FilterRange> _ranges;

  /// The months the list is narrowed to — [FilterPeriod.any] when it is
  /// not.
  final FilterPeriod period;

  bool get isEmpty => _chosen.isEmpty && _ranges.isEmpty && period.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<ManagerStatsColumn> get columns => <ManagerStatsColumn>[
    for (final ManagerStatsColumn column in ManagerStatsColumn.values)
      if (has(column)) column,
  ];

  bool has(ManagerStatsColumn column) => column.takesPeriod
      ? period.isNotEmpty
      : _chosen.containsKey(column) || _ranges.containsKey(column);

  /// The column's value, or null.
  String? valueOf(ManagerStatsColumn column) => _chosen[column];

  List<String> valuesOf(ManagerStatsColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(ManagerStatsColumn column, String value) =>
      _chosen[column] == value;

  /// The column's span — open at both ends when it has none.
  FilterRange rangeOf(ManagerStatsColumn column) =>
      _ranges[column] ?? FilterRange.any;

  /// The column worth sending to the bridge as `search`: the manager, the
  /// only one it can find.
  ManagerStatsColumn? get searchColumn =>
      _chosen.containsKey(ManagerStatsColumn.manager)
      ? ManagerStatsColumn.manager
      : null;

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  ManagerStatsFilter toggle(ManagerStatsColumn column, String value) {
    final Map<ManagerStatsColumn, String> chosen =
        Map<ManagerStatsColumn, String>.of(_chosen);
    final Map<ManagerStatsColumn, FilterRange> ranges =
        Map<ManagerStatsColumn, FilterRange>.of(_ranges);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
      ranges.remove(column);
    }
    return ManagerStatsFilter._freeze(chosen, ranges, period);
  }

  /// [column] narrowed to [range]; an empty span lets go of it.
  ManagerStatsFilter withRange(ManagerStatsColumn column, FilterRange range) {
    final Map<ManagerStatsColumn, FilterRange> ranges =
        Map<ManagerStatsColumn, FilterRange>.of(_ranges);
    if (range.isEmpty) {
      if (!ranges.containsKey(column)) return this;
      ranges.remove(column);
    } else {
      ranges[column] = range;
    }
    return ManagerStatsFilter._freeze(
      Map<ManagerStatsColumn, String>.of(_chosen)..remove(column),
      ranges,
      period,
    );
  }

  /// The list narrowed to [next]; an empty period lets go of it.
  ManagerStatsFilter withPeriod(FilterPeriod next) =>
      next == period ? this : ManagerStatsFilter._(_chosen, _ranges, next);

  /// [column] let go: `Hamısı`.
  ManagerStatsFilter cleared(ManagerStatsColumn column) {
    if (!has(column)) return this;
    if (column.takesPeriod) return withPeriod(FilterPeriod.any);
    return ManagerStatsFilter._freeze(
      Map<ManagerStatsColumn, String>.of(_chosen)..remove(column),
      Map<ManagerStatsColumn, FilterRange>.of(_ranges)..remove(column),
      period,
    );
  }

  static ManagerStatsFilter _freeze(
    Map<ManagerStatsColumn, String> chosen,
    Map<ManagerStatsColumn, FilterRange> ranges,
    FilterPeriod period,
  ) => ManagerStatsFilter._(
    Map<ManagerStatsColumn, String>.unmodifiable(chosen),
    Map<ManagerStatsColumn, FilterRange>.unmodifiable(ranges),
    period,
  );

  /// Whether [stat] survives every column.
  ///
  /// A row whose month or figure 1C does not say is in no period and no
  /// span: its card says nothing about either.
  bool matches(ManagerStat stat) {
    final String? manager = _chosen[ManagerStatsColumn.manager];
    if (manager != null) {
      final String? name = stat.manager;
      if (name == null || filterKey(name) != filterKey(manager)) return false;
    }
    if (period.isNotEmpty) {
      final FilterMonth? month = stat.period;
      if (month == null || !period.contains(month)) return false;
    }
    for (final MapEntry<ManagerStatsColumn, FilterRange> entry
        in _ranges.entries) {
      final double? figure = switch (entry.key) {
        ManagerStatsColumn.orders => stat.orders?.toDouble(),
        ManagerStatsColumn.amount => stat.amount,
        _ => null,
      };
      if (figure == null || !entry.value.contains(figure)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ManagerStatsFilter &&
      mapEquals(other._chosen, _chosen) &&
      mapEquals(other._ranges, _ranges) &&
      other.period == period;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ManagerStatsColumn, String> entry in _chosen.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ManagerStatsColumn, FilterRange> entry
          in _ranges.entries)
        Object.hash(entry.key, entry.value),
    ]),
    period,
  );

  @override
  String toString() => 'ManagerStatsFilter($_chosen, $_ranges, $period)';
}
