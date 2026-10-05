import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'sale.dart' show readDocumentDate;

/// One product's balance in one warehouse, synced from 1C — a row of the
/// website's `Stok Balansları` table, and one card on the phone.
///
/// The bridge's `product_stock` table, read live on 2026-09-25: 799 rows, one
/// for each product a warehouse holds any of, as `{id, product_guid,
/// product_code, product_name, warehouse_id, warehouse, quantity,
/// balance_date, baza_id, synced_at}`. The same product appears once per
/// warehouse it is kept in — `Tabak Kiçik` six times — so a row is a
/// *balance*, not a product. The field names are the website's too
/// (`one_c_dashboard.js`), since the bridge's spec types the answer as a bare
/// `{}`.
@immutable
class StockItem {
  const StockItem({
    required this.id,
    this.code,
    this.product,
    this.warehouse,
    this.quantity,
    this.date,
  });

  /// Null when [row] has no id: the id is what tells a balance from the one
  /// that takes its place on the next page.
  static StockItem? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'stock_id']);
    if (id == null) return null;
    return StockItem(
      id: id,
      code: readString(row, <String>['product_code', 'code']),
      product: readString(row, <String>['product_name', 'name']),
      warehouse: readString(row, <String>['warehouse', 'warehouse_name']),
      quantity: readDouble(row, <String>['quantity', 'qty']),
      date: readDocumentDate(row, <String>['balance_date', 'date']),
    );
  }

  final int id;

  /// `NT000001046` — the product's code in 1C.
  final String? code;

  /// `Salafan ağ qulplu 44*77`, exactly as 1C spells it — spaces doubled or
  /// trailing, as some of the names are.
  final String? product;

  /// `istehsalat` — one of the seven warehouses `/warehouses/` lists, and
  /// spelt exactly as it spells them.
  final String? warehouse;

  /// How much of it the warehouse holds, in the product's own unit: pieces
  /// for a bag, kilograms to the gram for meat.
  final double? quantity;

  /// `2026-09-23`, the day 1C last counted this balance.
  final String? date;
}
