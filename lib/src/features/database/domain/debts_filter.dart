import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'debt.dart';

/// A column of the `Kreditorlar` and `Debitorlar` filter: every field the
/// card shows, in the card's order.
///
/// The amount is two columns, [debt] and [ourDebt], because the two cards
/// call it by two names — `Borc` and `Borcumuz` — and the funnel says what
/// the card says. A list offers only its own ([of]).
enum DebtsColumn implements DatabaseFilterColumn {
  contractor('Kontraqent'),
  organization('Təşkilat'),
  contract('Müqavilə'),
  debt('Borc'),
  ourDebt('Borcumuz'),
  settlement('Hesablaşma'),
  status('Status');

  const DebtsColumn(this.label);

  @override
  final String label;

  /// The columns [kind]'s funnel opens, in the card's order.
  static List<DebtsColumn> of(DebtKind kind) => <DebtsColumn>[
    for (final DebtsColumn column in values)
      if (column != _otherAmount(kind)) column,
  ];

  /// The amount column [kind] does not use.
  static DebtsColumn _otherAmount(DebtKind kind) => switch (kind) {
    DebtKind.creditors => DebtsColumn.debt,
    DebtKind.debitors => DebtsColumn.ourDebt,
  };

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-20): `search` on either list is one
  /// case-insensitive substring over the counterparty and the contract —
  /// `mmc` finds `MMC`, `müqavilə` 78 of 88 creditors — and nothing else:
  /// not the organisation, not an amount, not the status.
  bool get searchable =>
      this == DebtsColumn.contractor || this == DebtsColumn.contract;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's rule for every
  /// figure on the tab since `Məhsullar`' price, said again for these two
  /// (2026-10-20).
  bool get takesRange =>
      this == DebtsColumn.debt ||
      this == DebtsColumn.ourDebt ||
      this == DebtsColumn.settlement;

  /// Whether the column's values can only all be known by reading every
  /// row: the bridge can list neither the organisations nor the contracts.
  bool get needsEveryone =>
      this == DebtsColumn.organization || this == DebtsColumn.contract;
}

/// The `Status` column's two values: the website's `Açıq borc` and
/// `Ödənilib`.
///
/// Every row was open on 2026-10-20 — a list of debts holds what is still
/// owed — but the website has a word for a paid one, so both are offered.
enum DebtStatus {
  open('Açıq borc'),
  paid('Ödənilib');

  const DebtStatus(this.label);

  final String label;

  bool matches(Debt debt) => debt.paid == (this == DebtStatus.paid);

  static DebtStatus? byName(String name) {
    for (final DebtStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// What `Kreditorlar` or `Debitorlar` is narrowed to: at most one value a
/// column — or, for an amount, one span.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class DebtsFilter {
  const DebtsFilter._(this._chosen, this._ranges);

  static const DebtsFilter none = DebtsFilter._(
    <DebtsColumn, String>{},
    <DebtsColumn, FilterRange>{},
  );

  final Map<DebtsColumn, String> _chosen;
  final Map<DebtsColumn, FilterRange> _ranges;

  bool get isEmpty => _chosen.isEmpty && _ranges.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<DebtsColumn> get columns => <DebtsColumn>[
    for (final DebtsColumn column in DebtsColumn.values)
      if (has(column)) column,
  ];

  bool has(DebtsColumn column) =>
      _chosen.containsKey(column) || _ranges.containsKey(column);

  /// The column's value, or null.
  String? valueOf(DebtsColumn column) => _chosen[column];

  List<String> valuesOf(DebtsColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(DebtsColumn column, String value) => _chosen[column] == value;

  /// The column's span — open at both ends when it has none.
  FilterRange rangeOf(DebtsColumn column) => _ranges[column] ?? FilterRange.any;

  /// The column worth sending to the bridge as `search`: the counterparty,
  /// which names one row or a few, then the contract.
  DebtsColumn? get searchColumn {
    for (final DebtsColumn column in DebtsColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  DebtsFilter toggle(DebtsColumn column, String value) {
    final Map<DebtsColumn, String> chosen = Map<DebtsColumn, String>.of(
      _chosen,
    );
    final Map<DebtsColumn, FilterRange> ranges =
        Map<DebtsColumn, FilterRange>.of(_ranges);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
      ranges.remove(column);
    }
    return DebtsFilter._freeze(chosen, ranges);
  }

  /// [column] narrowed to [range]; an empty span lets go of it.
  DebtsFilter withRange(DebtsColumn column, FilterRange range) {
    final Map<DebtsColumn, FilterRange> ranges =
        Map<DebtsColumn, FilterRange>.of(_ranges);
    if (range.isEmpty) {
      if (!ranges.containsKey(column)) return this;
      ranges.remove(column);
    } else {
      ranges[column] = range;
    }
    return DebtsFilter._freeze(
      Map<DebtsColumn, String>.of(_chosen)..remove(column),
      ranges,
    );
  }

  /// [column] let go: `Hamısı`.
  DebtsFilter cleared(DebtsColumn column) {
    if (!has(column)) return this;
    return DebtsFilter._freeze(
      Map<DebtsColumn, String>.of(_chosen)..remove(column),
      Map<DebtsColumn, FilterRange>.of(_ranges)..remove(column),
    );
  }

  static DebtsFilter _freeze(
    Map<DebtsColumn, String> chosen,
    Map<DebtsColumn, FilterRange> ranges,
  ) => DebtsFilter._(
    Map<DebtsColumn, String>.unmodifiable(chosen),
    Map<DebtsColumn, FilterRange>.unmodifiable(ranges),
  );

  /// Whether [debt] survives every column. An amount 1C does not give is
  /// in no span.
  bool matches(Debt debt) {
    for (final MapEntry<DebtsColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, debt)) return false;
    }
    for (final MapEntry<DebtsColumn, FilterRange> entry in _ranges.entries) {
      final double? figure = switch (entry.key) {
        DebtsColumn.settlement => debt.settlement,
        _ => debt.debt,
      };
      if (figure == null || !entry.value.contains(figure)) return false;
    }
    return true;
  }

  static bool _matches(DebtsColumn column, String value, Debt debt) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      DebtsColumn.contractor => same(debt.contractor),
      DebtsColumn.organization => same(debt.organization),
      DebtsColumn.contract => same(debt.contract),
      DebtsColumn.status => DebtStatus.byName(value)?.matches(debt) ?? true,
      // An amount is narrowed by a span, never by a value.
      DebtsColumn.debt || DebtsColumn.ourDebt || DebtsColumn.settlement => true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is DebtsFilter &&
      mapEquals(other._chosen, _chosen) &&
      mapEquals(other._ranges, _ranges);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<DebtsColumn, String> entry in _chosen.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<DebtsColumn, FilterRange> entry in _ranges.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => 'DebtsFilter($_chosen, $_ranges)';
}
