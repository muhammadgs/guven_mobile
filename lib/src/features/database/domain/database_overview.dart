import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'database_metric.dart';

/// Every figure on `Əsas panel`, as of one refresh.
///
/// A null is a figure nobody could read — its request failed, or the answer
/// did not carry it — and the row says `—` rather than 0 for it: "no debt"
/// and "we do not know the debt" are different claims, and only one of them
/// would be true.
@immutable
class DatabaseOverview {
  const DatabaseOverview({
    this.products,
    this.customers,
    this.orders,
    this.salesDocuments,
    this.stockRecords,
    this.team,
    this.creditors,
    this.debitors,
    this.salesAmount,
    this.debtLoad,
  });

  static const DatabaseOverview empty = DatabaseOverview();

  /// Reads the four answers behind the panel, any of which may be missing.
  ///
  /// The mapping is the website's (`one_c_dashboard.js`) exactly, so the two
  /// agree:
  ///
  /// * products, customers and orders are the `total` of their own lists —
  ///   they are 1C catalogues, not snapshot tables, and the summary does not
  ///   count them;
  /// * the next five are `summary.counts`;
  /// * `Ümumi Satış Məbləği` is `totals.sales_amount`, and `Cari Borc Yükü`
  ///   is what the customers owe plus what the managers owe —
  ///   `totals.debitor_debt + totals.manager_debet`, `debet` as the backend
  ///   spells it.
  factory DatabaseOverview.fromResponses({
    Object? summary,
    Object? products,
    Object? customers,
    Object? orders,
  }) {
    final Map<String, Object?> body = _summaryBody(summary);
    final Map<String, Object?> counts = asMap(body['counts']);
    final Map<String, Object?> totals = asMap(body['totals']);

    final double? debitorDebt = readDouble(totals, <String>['debitor_debt']);
    final double? managerDebt = readDouble(totals, <String>[
      'manager_debet',
      'manager_debt',
    ]);

    return DatabaseOverview(
      // Should a list be down, a summary that happens to count the catalogue
      // too is better than a dash.
      products:
          readListTotal(products) ?? readInt(counts, <String>['products']),
      customers:
          readListTotal(customers) ?? readInt(counts, <String>['customers']),
      orders: readListTotal(orders) ?? readInt(counts, <String>['orders']),
      salesDocuments: readInt(counts, <String>['sales']),
      stockRecords: readInt(counts, <String>['stock']),
      team: readInt(counts, <String>['team']),
      creditors: readInt(counts, <String>['creditors']),
      debitors: readInt(counts, <String>['debitors']),
      salesAmount: readDouble(totals, <String>['sales_amount']),
      debtLoad: debitorDebt == null && managerDebt == null
          ? null
          : (debitorDebt ?? 0) + (managerDebt ?? 0),
    );
  }

  final int? products;
  final int? customers;
  final int? orders;

  /// `Satış Sənədi` — sale documents synced from 1C.
  final int? salesDocuments;

  /// `Stok Qeydi` — stock rows, one per product and warehouse.
  final int? stockRecords;

  final int? team;
  final int? creditors;
  final int? debitors;

  /// In manat.
  final double? salesAmount;

  /// In manat.
  final double? debtLoad;

  /// [metric]'s figure, or null when it is not known.
  num? valueOf(DatabaseMetric metric) => switch (metric) {
    DatabaseMetric.products => products,
    DatabaseMetric.customers => customers,
    DatabaseMetric.orders => orders,
    DatabaseMetric.salesDocuments => salesDocuments,
    DatabaseMetric.stockRecords => stockRecords,
    DatabaseMetric.team => team,
    DatabaseMetric.creditors => creditors,
    DatabaseMetric.debitors => debitors,
    DatabaseMetric.salesAmount => salesAmount,
    DatabaseMetric.debtLoad => debtLoad,
  };

  /// The summary's own object, bare or inside a `data` envelope.
  static Map<String, Object?> _summaryBody(Object? payload) {
    final Map<String, Object?> map = asMap(payload);
    if (map['counts'] is Map || map['totals'] is Map) return map;
    final Object? data = map['data'];
    return data is Map ? asMap(data) : map;
  }
}
