import 'package:flutter/foundation.dart';

import 'customer.dart';
import 'database_filter.dart';

/// A column of the `Müştərilər` filter: the card's fields that the list's
/// own rows carry, in the card's order.
///
/// `Rolu` and `Hüquqi status` are on an open card but not here: only a
/// customer's own answer carries them, so filtering by either would mean
/// asking for every customer one at a time — 310 requests.
enum CustomersColumn implements DatabaseFilterColumn {
  code('Kod / VÖEN'),
  name('Müştəri'),
  type('Növ'),
  payment('Ödəniş müddəti');

  const CustomersColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-04): `search` on `/customers/` is
  /// one case-insensitive substring over the customer's name, its code and
  /// its VÖEN — the website's own hint, `Ad, VÖEN, kod axtar...` — and
  /// nothing else: not the kind, not the payment term.
  bool get searchable =>
      this == CustomersColumn.code || this == CustomersColumn.name;

  /// Whether the column's values can only all be known by reading every
  /// customer: the bridge can neither search for them nor list them.
  bool get needsEveryCustomer => this == CustomersColumn.payment;
}

/// The `Növ` column's two values: the website's `Hüquqi` and `Fiziki`.
enum CustomerType {
  legal('Hüquqi'),
  physical('Fiziki');

  const CustomerType(this.label);

  final String label;

  /// A customer whose kind 1C does not say is neither.
  bool matches(Customer customer) =>
      customer.type != null && customer.isLegal == (this == CustomerType.legal);

  static CustomerType? byName(String name) {
    for (final CustomerType type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// What `Müştərilər` is narrowed to: at most one value a column.
///
/// A code or a name is kept exactly as the bridge wrote it — spacing
/// included — and compared through [filterKey]; a payment term is kept as
/// its number of days.
@immutable
class CustomersFilter {
  const CustomersFilter._(this._chosen);

  static const CustomersFilter none = CustomersFilter._(
    <CustomersColumn, String>{},
  );

  final Map<CustomersColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => _chosen.isNotEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the card's order.
  List<CustomersColumn> get columns => <CustomersColumn>[
    for (final CustomersColumn column in CustomersColumn.values)
      if (_chosen.containsKey(column)) column,
  ];

  bool has(CustomersColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(CustomersColumn column) => _chosen[column];

  List<String> valuesOf(CustomersColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(CustomersColumn column, String value) =>
      _chosen[column] == value;

  /// The column worth sending to the bridge as `search`: the code or VÖEN,
  /// which names one customer, then the name.
  CustomersColumn? get searchColumn {
    for (final CustomersColumn column in CustomersColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  CustomersFilter toggle(CustomersColumn column, String value) {
    final Map<CustomersColumn, String> next = Map<CustomersColumn, String>.of(
      _chosen,
    );
    if (next[column] == value) {
      next.remove(column);
    } else {
      next[column] = value;
    }
    return CustomersFilter._(Map<CustomersColumn, String>.unmodifiable(next));
  }

  /// [column] let go: `Hamısı`.
  CustomersFilter cleared(CustomersColumn column) {
    if (!_chosen.containsKey(column)) return this;
    final Map<CustomersColumn, String> next = Map<CustomersColumn, String>.of(
      _chosen,
    )..remove(column);
    return CustomersFilter._(Map<CustomersColumn, String>.unmodifiable(next));
  }

  /// Whether [customer] survives every column.
  bool matches(Customer customer) {
    for (final MapEntry<CustomersColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, customer)) return false;
    }
    return true;
  }

  static bool _matches(
    CustomersColumn column,
    String value,
    Customer customer,
  ) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      CustomersColumn.code => same(customer.taxIdOrCode),
      CustomersColumn.name => same(customer.name),
      CustomersColumn.type =>
        CustomerType.byName(value)?.matches(customer) ?? true,
      CustomersColumn.payment => '${customer.paymentDays}' == value,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CustomersFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<CustomersColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'CustomersFilter($_chosen)';
}
