import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/stock_controller.dart';
import '../../domain/stock_item.dart';
import 'database_list.dart';
import 'stock_card.dart';

/// What `Stok` calls a row: a *qeyd*, the website's own word — `Stok qeydi
/// tapılmadı`. Not a product: the same product has a row in every warehouse
/// that keeps it.
const DatabaseListWords kStockListWords = DatabaseListWords(
  unit: 'qeyd',
  checking: 'Qeydlər yoxlanılır…',
  empty: 'Stok qeydi tapılmadı.',
  filteredEmpty: 'Filterə uyğun qeyd tapılmadı.',
);

/// `Stok`: every balance as a card, most of anything first, fetched a page at
/// a time as the list nears its end — or, while a filter is on, the balances
/// it lets through. [DatabaseList] does the work; this says what a card is.
class StockList extends StatelessWidget {
  const StockList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final StockController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<StockItem>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (StockItem item) => item.id,
      words: kStockListWords,
      card: _card,
    );
  }

  /// The same card in either list: a balance has nothing to open.
  static Widget _card(
    BuildContext context,
    DatabaseRows<StockItem> rows,
    StockItem item,
  ) => StockCard(item: item);
}
