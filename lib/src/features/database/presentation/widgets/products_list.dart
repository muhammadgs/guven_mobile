import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/products_controller.dart';
import '../../domain/product.dart';
import 'database_list.dart';
import 'product_card.dart';

/// What `Məhsullar` calls a row: a *məhsul* — the website's own word,
/// `Məhsul tapılmadı`.
const DatabaseListWords kProductsListWords = DatabaseListWords(
  unit: 'məhsul',
  checking: 'Məhsullar yoxlanılır…',
  empty: 'Məhsul tapılmadı.',
  filteredEmpty: 'Filterə uyğun məhsul tapılmadı.',
);

/// `Məhsullar`: every product as a card, in the bridge's order, fetched a
/// page at a time as the list nears its end — or, while a filter is on, the
/// products it lets through. [DatabaseList] does the paging; this says what
/// a card is, and that a card opens.
class ProductsList extends StatelessWidget {
  const ProductsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final ProductsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final ProductsController products = controller;
    return DatabaseList<Product>(
      source: products,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Product product) => product.id,
      words: kProductsListWords,
      card: (BuildContext context, DatabaseRows<Product> rows, Product row) {
        // Both of `Məhsullar`' lists — every product, and the ones a filter
        // lets through — are [ProductsRows], and each opens its own cards.
        final ProductsRows list = rows as ProductsRows;
        return ProductCard(
          product: products.view(row),
          expanded: list.isExpanded(row.id),
          loading: products.isDetailLoading(row.id),
          error: products.detailError(row.id),
          onToggle: () => list.toggle(row),
          onRetry: () => products.loadDetail(row.id),
        );
      },
    );
  }
}
