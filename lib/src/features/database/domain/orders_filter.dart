import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'order.dart';

/// A column of the `Sifarişlər` filter: the website table's five, in its
/// order — the fields every row of the list carries.
///
/// `Endirim`, `Vergi` and `Ödənilən` are not among them: the list's rows do
/// not carry them, and reading them means one request per order — 7,519 of
/// them. Nor `Qalıq borc` or `Valyuta`, which the bridge does not send at
/// all.
enum OrdersColumn implements DatabaseFilterColumn {
  number('Sifariş'),
  date('Tarix'),
  amount('Məbləğ'),
  status('Status'),
  payment('Ödəniş');

  const OrdersColumn(this.label);

  @override
  final String label;

  /// Whether the column's values can only all be known by reading every
  /// order: the bridge can neither search for them nor say which exist.
  ///
  /// Probed on 2026-09-27: `search` on `/orders/` is a substring of the
  /// order's number and nothing else, `status` is honoured — together with
  /// `search` too — and every other parameter is ignored.
  bool get needsEveryOrder =>
      this == OrdersColumn.date ||
      this == OrdersColumn.amount ||
      this == OrdersColumn.payment;
}

/// An amount as the filter files it: whole qəpiks, so that `6720` and
/// `6720.0` — and a sum a floating-point total leaves a hair off — are one.
int? amountKey(double? amount) =>
    amount == null || !amount.isFinite ? null : (amount * 100).round();

/// An amount as the filter keeps it: `6720.00`.
String amountValue(double amount) => amount.toStringAsFixed(2);

/// What `Sifarişlər` is narrowed to: at most one value a column.
///
/// Values are kept as the bridge writes them — the number, the day
/// (`2026-09-18`), the status's own word — except an amount, which is kept
/// to the qəpik ([amountValue]).
@immutable
class OrdersFilter {
  const OrdersFilter._(this._chosen);

  static const OrdersFilter none = OrdersFilter._(<OrdersColumn, String>{});

  final Map<OrdersColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => _chosen.isNotEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the website's order.
  List<OrdersColumn> get columns => <OrdersColumn>[
    for (final OrdersColumn column in OrdersColumn.values)
      if (_chosen.containsKey(column)) column,
  ];

  bool has(OrdersColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(OrdersColumn column) => _chosen[column];

  List<String> valuesOf(OrdersColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(OrdersColumn column, String value) => _chosen[column] == value;

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held: one day, one amount, one status at a time.
  OrdersFilter toggle(OrdersColumn column, String value) {
    final Map<OrdersColumn, String> next = Map<OrdersColumn, String>.of(
      _chosen,
    );
    if (next[column] == value) {
      next.remove(column);
    } else {
      next[column] = value;
    }
    return OrdersFilter._(Map<OrdersColumn, String>.unmodifiable(next));
  }

  /// [column] let go: `Hamısı`.
  OrdersFilter cleared(OrdersColumn column) {
    if (!_chosen.containsKey(column)) return this;
    final Map<OrdersColumn, String> next = Map<OrdersColumn, String>.of(_chosen)
      ..remove(column);
    return OrdersFilter._(Map<OrdersColumn, String>.unmodifiable(next));
  }

  /// Whether [order] survives every column.
  bool matches(Order order) {
    for (final MapEntry<OrdersColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, order)) return false;
    }
    return true;
  }

  static bool _matches(OrdersColumn column, String value, Order order) {
    return switch (column) {
      OrdersColumn.number =>
        order.number != null && filterKey(order.number!) == filterKey(value),
      OrdersColumn.date => order.date == value,
      OrdersColumn.amount =>
        amountKey(order.amount) != null &&
            amountKey(order.amount) == amountKey(double.tryParse(value)),
      OrdersColumn.status => order.status == value,
      OrdersColumn.payment => order.payment == value,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is OrdersFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<OrdersColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'OrdersFilter($_chosen)';
}
