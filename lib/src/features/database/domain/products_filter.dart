import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'product.dart';

/// A column of the `Məhsullar` filter: every field the card shows, in the
/// card's order — all but the warehouses, which the user did not want as a
/// filter (2026-09-29). `Qiymət / Vahid` is one line on the card and two
/// columns here, since one of them is a figure and the other a word.
enum ProductsColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Məhsul'),
  category('Kateqoriya'),
  price('Qiymət'),
  unit('Vahid'),
  stock('Stok'),
  type('Növ'),
  vat('ƏDV'),
  status('Status');

  const ProductsColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-09-29): `search` on `/products/` is one
  /// case-insensitive substring over the product's code and its name, and
  /// nothing else — not the category, the kind or the unit.
  bool get searchable =>
      this == ProductsColumn.code || this == ProductsColumn.name;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's own rule for
  /// the price, the stock and the VAT rate.
  bool get takesRange =>
      this == ProductsColumn.price ||
      this == ProductsColumn.stock ||
      this == ProductsColumn.vat;

  /// Whether the column's values can only all be known by reading every
  /// product: the bridge can neither search for them nor list them —
  /// `/product-groups/` answers with nothing.
  bool get needsEveryProduct =>
      this == ProductsColumn.category ||
      this == ProductsColumn.unit ||
      this == ProductsColumn.type;
}

/// The `Status` column's two values: the website's `Aktiv` and `Deaktiv`.
///
/// Every product was active on 2026-09-29, but 1C can switch one off and
/// the website offers both, so both are offered.
enum ProductStatus {
  active('Aktiv'),
  inactive('Deaktiv');

  const ProductStatus(this.label);

  final String label;

  bool matches(Product product) =>
      product.isActive == (this == ProductStatus.active);

  static ProductStatus? byName(String name) {
    for (final ProductStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// The `ƏDV` column's one value beside its span: a product with no VAT.
const String kNoVatValue = 'none';

/// What `ƏDV yoxdur` is called in the filter.
const String kNoVatLabel = 'ƏDV yoxdur';

/// What `Məhsullar` is narrowed to: at most one value a column — or, for a
/// column of figures, one span.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey]. `ƏDV` takes either its span or `ƏDV yoxdur`, never both:
/// choosing one lets go of the other.
@immutable
class ProductsFilter {
  const ProductsFilter._(this._chosen, this._ranges);

  static const ProductsFilter none = ProductsFilter._(
    <ProductsColumn, String>{},
    <ProductsColumn, FilterRange>{},
  );

  final Map<ProductsColumn, String> _chosen;
  final Map<ProductsColumn, FilterRange> _ranges;

  bool get isEmpty => _chosen.isEmpty && _ranges.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<ProductsColumn> get columns => <ProductsColumn>[
    for (final ProductsColumn column in ProductsColumn.values)
      if (has(column)) column,
  ];

  bool has(ProductsColumn column) =>
      _chosen.containsKey(column) || _ranges.containsKey(column);

  /// The column's value, or null.
  String? valueOf(ProductsColumn column) => _chosen[column];

  List<String> valuesOf(ProductsColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(ProductsColumn column, String value) =>
      _chosen[column] == value;

  /// The column's span — open at both ends when it has none.
  FilterRange rangeOf(ProductsColumn column) =>
      _ranges[column] ?? FilterRange.any;

  /// The `Status` value, when one is chosen.
  ProductStatus? get status {
    final String? value = _chosen[ProductsColumn.status];
    return value == null ? null : ProductStatus.byName(value);
  }

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one product, then the name.
  ProductsColumn? get searchColumn {
    for (final ProductsColumn column in ProductsColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held, a span included.
  ProductsFilter toggle(ProductsColumn column, String value) {
    final Map<ProductsColumn, String> chosen = Map<ProductsColumn, String>.of(
      _chosen,
    );
    final Map<ProductsColumn, FilterRange> ranges =
        Map<ProductsColumn, FilterRange>.of(_ranges);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
      ranges.remove(column);
    }
    return ProductsFilter._freeze(chosen, ranges);
  }

  /// [column] narrowed to [range], replacing a value it held.
  ///
  /// An empty span lets go of the column's span — but not of a value it
  /// holds: the panel clears its fields when `ƏDV yoxdur` is chosen, and
  /// that must not take the choice back.
  ProductsFilter withRange(ProductsColumn column, FilterRange range) {
    final Map<ProductsColumn, String> chosen = Map<ProductsColumn, String>.of(
      _chosen,
    );
    final Map<ProductsColumn, FilterRange> ranges =
        Map<ProductsColumn, FilterRange>.of(_ranges);
    if (range.isEmpty) {
      if (!ranges.containsKey(column)) return this;
      ranges.remove(column);
    } else {
      ranges[column] = range;
      chosen.remove(column);
    }
    return ProductsFilter._freeze(chosen, ranges);
  }

  /// [column] let go: `Hamısı`.
  ProductsFilter cleared(ProductsColumn column) {
    if (!has(column)) return this;
    return ProductsFilter._freeze(
      Map<ProductsColumn, String>.of(_chosen)..remove(column),
      Map<ProductsColumn, FilterRange>.of(_ranges)..remove(column),
    );
  }

  static ProductsFilter _freeze(
    Map<ProductsColumn, String> chosen,
    Map<ProductsColumn, FilterRange> ranges,
  ) => ProductsFilter._(
    Map<ProductsColumn, String>.unmodifiable(chosen),
    Map<ProductsColumn, FilterRange>.unmodifiable(ranges),
  );

  /// Whether [product] survives every column.
  bool matches(Product product) {
    for (final MapEntry<ProductsColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, product)) return false;
    }
    for (final MapEntry<ProductsColumn, FilterRange> entry in _ranges.entries) {
      final double? figure = figureOf(entry.key, product);
      if (figure == null || !entry.value.contains(figure)) return false;
    }
    return true;
  }

  /// The figure a span column reads off [product].
  ///
  /// A price, a stock or a rate the bridge leaves out is 0, as the website
  /// reads it (`parseFloat(…) || 0`): a product with no VAT *is* at 0%.
  static double? figureOf(ProductsColumn column, Product product) =>
      switch (column) {
        ProductsColumn.price => product.price ?? 0,
        ProductsColumn.stock => product.stock ?? 0,
        ProductsColumn.vat => product.vat ?? 0,
        _ => null,
      };

  static bool _matches(ProductsColumn column, String value, Product product) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      ProductsColumn.code => same(product.code),
      ProductsColumn.name => same(product.name),
      ProductsColumn.category => same(product.category),
      ProductsColumn.unit => same(product.unit),
      ProductsColumn.type => same(product.type),
      ProductsColumn.status =>
        ProductStatus.byName(value)?.matches(product) ?? true,
      ProductsColumn.vat => value == kNoVatValue && product.hasNoVat,
      // Figures are narrowed by a span, never by a value.
      ProductsColumn.price || ProductsColumn.stock => true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ProductsFilter &&
      mapEquals(other._chosen, _chosen) &&
      mapEquals(other._ranges, _ranges);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ProductsColumn, String> entry in _chosen.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<ProductsColumn, FilterRange> entry in _ranges.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => 'ProductsFilter($_chosen, $_ranges)';
}
