import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/sales_controller.dart';
import '../../domain/sale.dart';
import 'database_list.dart';
import 'sale_card.dart';

/// What `Satışlar` calls a row: a *sənəd*, a document.
const DatabaseListWords kSalesListWords = DatabaseListWords(
  unit: 'sənəd',
  checking: 'Sənədlər yoxlanılır…',
  empty: 'Satış sənədi tapılmadı.',
  filteredEmpty: 'Filterə uyğun sənəd tapılmadı.',
);

/// `Satışlar`: every sale document as a card, fetched a page at a time as the
/// list is scrolled towards its end — or, while a filter is on, the
/// documents it lets through. [DatabaseList] does the paging; this says what
/// a card is, and that a card opens.
class SalesList extends StatelessWidget {
  const SalesList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final SalesController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's. The cards are wider than the titles
  /// above them, as the design draws them.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final SalesController sales = controller;
    return DatabaseList<Sale>(
      source: sales,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Sale sale) => sale.id,
      words: kSalesListWords,
      card: (BuildContext context, DatabaseRows<Sale> rows, Sale row) {
        // Both of `Satışlar`' lists — every document, and the ones a filter
        // lets through — are [SalesRows], and each opens its own cards.
        final SalesRows list = rows as SalesRows;
        return SaleCard(
          sale: sales.view(row),
          expanded: list.isExpanded(row.id),
          loading: sales.isDocumentLoading(row.id),
          error: sales.documentError(row.id),
          onToggle: () => list.toggle(row),
          onRetry: () => sales.loadDocument(row.id),
        );
      },
    );
  }
}
