import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'sale.dart' show readDocumentDate;

/// One product in 1C's catalogue — a row of the website's `Məhsullar` table,
/// and one card on the phone.
///
/// The bridge answers it two ways, read live on 2026-09-29:
///
/// * a row of `/products/`: `{id, code, name, price, stock_qty, unit,
///   product_type, vat_rate, is_active, folder_path, folder_name, category,
///   article, …}` — everything a shut card and the filter need;
/// * `/products/{id}`: the same, plus `warehouses` — the product's balance
///   in each warehouse that holds any — which only an open card shows. It is
///   asked for when the card is opened, and laid over the row by
///   [mergedWith].
///
/// The field names are the website's (`one_c_dashboard.js`), since the
/// bridge's spec types the answers as a bare `{}`.
@immutable
class Product {
  const Product({
    required this.id,
    this.code,
    this.name,
    this.category,
    this.article,
    this.price,
    this.unit,
    this.stock,
    this.type,
    this.vat,
    this.active,
    this.balances,
  });

  /// Null when [row] has no id: the id is what opens a product, and tells it
  /// from the one that takes its place on the next page.
  ///
  /// [knownId] is for a product fetched *by* its id, whose answer need not
  /// repeat it.
  static Product? fromJson(Map<String, Object?> row, {int? knownId}) {
    final int? id = readInt(row, <String>['id', 'product_id']) ?? knownId;
    if (id == null) return null;
    final Object? warehouses = row['warehouses'];
    return Product(
      id: id,
      code: readString(row, <String>['code', 'product_code']),
      name: readString(row, <String>['name', 'product_name']),
      // The website's `categoryLabel`: the whole path first, `NM MENU /
      // SOUSLAR`, which is what the design prints.
      category: readString(row, <String>[
        'folder_path',
        'folder_name',
        'category',
      ]),
      article: readString(row, <String>['article']),
      price: readDouble(row, <String>['price']),
      unit: readString(row, <String>['unit', 'base_unit']),
      stock: readDouble(row, <String>['stock_qty', 'stock']),
      type: readString(row, <String>['product_type']),
      vat: readDouble(row, <String>['vat_rate']),
      active: readBool(row, <String>['is_active']),
      balances: warehouses is List
          ? <ProductBalance>[
              for (final Map<String, Object?> balance in asRows(warehouses))
                ProductBalance.fromJson(balance),
            ]
          : null,
    );
  }

  final int id;

  /// `NT000001093` — the product's code in 1C.
  final String? code;

  /// `20/20 Şəffaf paket (1696)`, exactly as 1C spells it — spaces doubled or
  /// trailing, as some of the names are.
  final String? name;

  /// `NM MENU / SOUSLAR` — the catalogue folder, parent and child.
  final String? category;

  /// `1265` — the article number only some products carry (the website's
  /// `Artikul`). Null when 1C leaves it empty, and then the card says
  /// nothing of it.
  final String? article;

  /// The selling price, in manat. 1C leaves it at 0 for over half the
  /// catalogue — raw materials nobody sells — and the website prints that 0.
  final double? price;

  /// `kq`, `əd`, `L` — 1C's own short names.
  final String? unit;

  /// How much there is in all, in [unit]: the latest count of every
  /// warehouse. 1C lets a balance go below nothing (17 products on
  /// 2026-09-29), and weighs meat to the gram.
  final double? stock;

  /// `xammal`, `Mal`, `Məhsul`, … — 1C's kind of product.
  final String? type;

  /// The VAT rate in per cent: 18 or 0 in the data, and 0 — or nothing — is
  /// no VAT at all, as the website reads it (`ƏDV-siz`).
  final double? vat;

  /// `is_active`, when the bridge says.
  final bool? active;

  /// The balance in each warehouse, from the product's own answer; null
  /// until that has been read.
  final List<ProductBalance>? balances;

  /// Deactivated only when the bridge says so: the website shows everything
  /// else as active.
  bool get isActive => active != false;

  /// Whether the product carries no VAT.
  bool get hasNoVat => (vat ?? 0) == 0;

  /// The row, with [detail] — the product's own, later answer — laid over
  /// it.
  Product mergedWith(Product detail) => Product(
    id: id,
    code: detail.code ?? code,
    name: detail.name ?? name,
    category: detail.category ?? category,
    article: detail.article ?? article,
    price: detail.price ?? price,
    unit: detail.unit ?? unit,
    stock: detail.stock ?? stock,
    type: detail.type ?? type,
    vat: detail.vat ?? vat,
    active: detail.active ?? active,
    balances: detail.balances ?? balances,
  );
}

/// A product's balance in one warehouse: a row of the open card's table.
@immutable
class ProductBalance {
  const ProductBalance({this.warehouse, this.quantity, this.date});

  factory ProductBalance.fromJson(Map<String, Object?> row) => ProductBalance(
    warehouse: readString(row, <String>['warehouse', 'warehouse_name']),
    quantity: readDouble(row, <String>['quantity', 'qty']),
    date: readDocumentDate(row, <String>['balance_date', 'date']),
  );

  /// `istehsalat` — spelt as `/warehouses/` spells it, spacing and all.
  final String? warehouse;

  final double? quantity;

  /// The day 1C counted it.
  final String? date;
}
