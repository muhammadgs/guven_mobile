import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/orders_controller.dart';
import '../../domain/order.dart';
import 'database_list.dart';
import 'order_card.dart';

/// What `Sifarişlər` calls a row: a *sifariş* — the website's own word,
/// `Sifariş tapılmadı`.
const DatabaseListWords kOrdersListWords = DatabaseListWords(
  unit: 'sifariş',
  checking: 'Sifarişlər yoxlanılır…',
  empty: 'Sifariş tapılmadı.',
  filteredEmpty: 'Filterə uyğun sifariş tapılmadı.',
);

/// `Sifarişlər`: every order as a card, in the bridge's order, fetched a
/// page at a time as the list nears its end — or, while a filter is on, the
/// orders it lets through. [DatabaseList] does the paging; this says what a
/// card is, and that a card opens.
class OrdersList extends StatelessWidget {
  const OrdersList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final OrdersController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final OrdersController orders = controller;
    return DatabaseList<Order>(
      source: orders,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Order order) => order.id,
      words: kOrdersListWords,
      card: (BuildContext context, DatabaseRows<Order> rows, Order row) {
        // Both of `Sifarişlər`' lists — every order, and the ones a filter
        // lets through — are [OrdersRows], and each opens its own cards.
        final OrdersRows list = rows as OrdersRows;
        return OrderCard(
          order: orders.view(row),
          expanded: list.isExpanded(row.id),
          loading: orders.isDetailLoading(row.id),
          error: orders.detailError(row.id),
          onToggle: () => list.toggle(row),
          onRetry: () => orders.loadDetail(row.id),
        );
      },
    );
  }
}
