import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'sale.dart';

/// A column of the `Satışlar` filter, in the order the design lists them.
enum SalesColumn implements DatabaseFilterColumn {
  number('Sənəd'),
  date('Tarix'),
  customer('Müştəri'),
  organization('Təşkilat'),
  manager('Menecer'),
  warehouse('Anbar'),
  kind('Növ'),
  status('Status'),
  product('Məhsul');

  const SalesColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-09-24): `search` is one substring over
  /// the document number, the customer and the manager, and nothing else. A
  /// value of any other column can only be found by reading the documents.
  bool get searchable =>
      this == SalesColumn.number ||
      this == SalesColumn.customer ||
      this == SalesColumn.manager;
}

/// The four values of the `Status` column: the two flags a card prints, each
/// either way round.
enum SaleFlag {
  posted('Postlanıb'),
  unposted('Postlanmayıb'),
  sold('Satılıb'),
  unsold('Satılmayıb');

  const SaleFlag(this.label);

  final String label;

  /// Its other half. A document is posted or not, sold or not, so choosing
  /// one of a pair lets go of the other — while a flag of the other pair can
  /// stand beside it.
  SaleFlag get opposite => switch (this) {
    SaleFlag.posted => SaleFlag.unposted,
    SaleFlag.unposted => SaleFlag.posted,
    SaleFlag.sold => SaleFlag.unsold,
    SaleFlag.unsold => SaleFlag.sold,
  };

  bool matches(Sale sale) => switch (this) {
    SaleFlag.posted => sale.isPosted,
    SaleFlag.unposted => !sale.isPosted,
    SaleFlag.sold => sale.isSold,
    SaleFlag.unsold => !sale.isSold,
  };

  static SaleFlag? byName(String name) {
    for (final SaleFlag flag in values) {
      if (flag.name == name) return flag;
    }
    return null;
  }
}

/// What `Satışlar` is narrowed to: at most one value a column, except
/// `Status`, which takes one of each pair.
///
/// A value is kept exactly as the bridge wrote it — spacing included — and
/// compared through [filterKey], so a customer picked from the catalogue
/// matches the same customer on a document even where one of the two has an
/// extra space in it.
@immutable
class SalesFilter {
  const SalesFilter._(this._chosen);

  static const SalesFilter none = SalesFilter._(<SalesColumn, List<String>>{});

  final Map<SalesColumn, List<String>> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => _chosen.isNotEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the design's order.
  List<SalesColumn> get columns => <SalesColumn>[
    for (final SalesColumn column in SalesColumn.values)
      if (_chosen.containsKey(column)) column,
  ];

  bool has(SalesColumn column) => _chosen.containsKey(column);

  List<String> valuesOf(SalesColumn column) =>
      _chosen[column] ?? const <String>[];

  /// The value of a one-value column, or null.
  String? valueOf(SalesColumn column) {
    final List<String>? values = _chosen[column];
    return values == null || values.isEmpty ? null : values.first;
  }

  bool isChosen(SalesColumn column, String value) =>
      valuesOf(column).contains(value);

  /// [value] chosen — or let go, if it already was.
  ///
  /// Choosing replaces whatever the column held: one customer at a time, one
  /// day at a time. `Status` is the exception: its values come in two pairs,
  /// and a value only replaces its own partner.
  SalesFilter toggle(SalesColumn column, String value) {
    final Map<SalesColumn, List<String>> next =
        Map<SalesColumn, List<String>>.of(_chosen);
    final List<String> current = valuesOf(column);

    if (current.contains(value)) {
      final List<String> rest = <String>[
        for (final String chosen in current)
          if (chosen != value) chosen,
      ];
      if (rest.isEmpty) {
        next.remove(column);
      } else {
        next[column] = List<String>.unmodifiable(rest);
      }
      return SalesFilter._(Map<SalesColumn, List<String>>.unmodifiable(next));
    }

    if (column == SalesColumn.status) {
      final String? partner = SaleFlag.byName(value)?.opposite.name;
      next[column] = List<String>.unmodifiable(<String>[
        for (final String chosen in current)
          if (chosen != partner) chosen,
        value,
      ]);
    } else {
      next[column] = List<String>.unmodifiable(<String>[value]);
    }
    return SalesFilter._(Map<SalesColumn, List<String>>.unmodifiable(next));
  }

  /// [column] let go: `Hamısı`.
  SalesFilter cleared(SalesColumn column) {
    if (!_chosen.containsKey(column)) return this;
    final Map<SalesColumn, List<String>> next =
        Map<SalesColumn, List<String>>.of(_chosen)..remove(column);
    return SalesFilter._(Map<SalesColumn, List<String>>.unmodifiable(next));
  }

  /// Whether [sale] survives every column.
  bool matches(Sale sale) {
    for (final MapEntry<SalesColumn, List<String>> entry in _chosen.entries) {
      for (final String value in entry.value) {
        if (!_matches(entry.key, value, sale)) return false;
      }
    }
    return true;
  }

  static bool _matches(SalesColumn column, String value, Sale sale) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      SalesColumn.number => same(sale.number),
      SalesColumn.date => sale.date == value,
      SalesColumn.customer => same(sale.customer),
      SalesColumn.organization => same(sale.organization),
      SalesColumn.manager => same(sale.manager),
      SalesColumn.warehouse => same(sale.warehouse),
      SalesColumn.kind => sale.docType?.toLowerCase() == value.toLowerCase(),
      SalesColumn.status => SaleFlag.byName(value)?.matches(sale) ?? true,
      SalesColumn.product =>
        sale.lines?.any((SaleLine line) => same(line.product)) ?? false,
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! SalesFilter || other._chosen.length != _chosen.length) {
      return false;
    }
    for (final MapEntry<SalesColumn, List<String>> entry in _chosen.entries) {
      if (!listEquals(other._chosen[entry.key], entry.value)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<SalesColumn, List<String>> entry in _chosen.entries)
      Object.hash(entry.key, Object.hashAll(entry.value)),
  ]);

  @override
  String toString() => 'SalesFilter($_chosen)';
}
