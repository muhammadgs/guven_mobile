import 'package:flutter/material.dart';

import '../../application/customers_controller.dart';
import '../../application/database_list_controller.dart';
import '../../domain/customer.dart';
import 'customer_card.dart';
import 'database_list.dart';

/// What `Müştərilər` calls a row: a *müştəri* — the website's own word,
/// `Müştəri tapılmadı`.
const DatabaseListWords kCustomersListWords = DatabaseListWords(
  unit: 'müştəri',
  checking: 'Müştərilər yoxlanılır…',
  empty: 'Müştəri tapılmadı.',
  filteredEmpty: 'Filterə uyğun müştəri tapılmadı.',
);

/// `Müştərilər`: every customer as a card, in the bridge's order, fetched a
/// page at a time as the list nears its end — or, while a filter is on, the
/// customers it lets through. [DatabaseList] does the paging; this says what
/// a card is, and that a card opens.
class CustomersList extends StatelessWidget {
  const CustomersList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final CustomersController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final CustomersController customers = controller;
    return DatabaseList<Customer>(
      source: customers,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Customer customer) => customer.id,
      words: kCustomersListWords,
      // `Müştərilər`' design sets its cards closer than the other lists':
      // 9pt apart, not 11.5.
      gap: 9,
      card: (BuildContext context, DatabaseRows<Customer> rows, Customer row) {
        // Both of `Müştərilər`' lists — every customer, and the ones a
        // filter lets through — are [CustomersRows], and each opens its own
        // cards.
        final CustomersRows list = rows as CustomersRows;
        return CustomerCard(
          customer: customers.view(row),
          expanded: list.isExpanded(row.id),
          loading: customers.isDetailLoading(row.id),
          error: customers.detailError(row.id),
          onToggle: () => list.toggle(row),
          onRetry: () => customers.loadDetail(row.id),
        );
      },
    );
  }
}
