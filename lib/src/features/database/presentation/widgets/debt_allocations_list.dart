import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/debt_allocations_controller.dart';
import '../../domain/debt_allocation.dart';
import 'database_list.dart';
import 'debt_allocation_card.dart';

/// What `Borc Bölgüsü` calls a row: a *bölgü*.
const DatabaseListWords kDebtAllocationsListWords = DatabaseListWords(
  unit: 'bölgü',
  checking: 'Bölgülər yoxlanılır…',
  empty: 'Borc bölgüsü tapılmadı.',
  filteredEmpty: 'Filterə uyğun bölgü tapılmadı.',
);

/// `Borc Bölgüsü`: every sale's share as a card, the largest first as the
/// bridge gives them — or, while a filter is on, the shares it lets
/// through. [DatabaseList] does the work; this says what a card is.
class DebtAllocationsList extends StatelessWidget {
  const DebtAllocationsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final DebtAllocationsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<DebtAllocation>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (DebtAllocation row) => row.id,
      words: kDebtAllocationsListWords,
      // The other `Maliyyə` pages' gap.
      gap: 9,
      card:
          (
            BuildContext context,
            DatabaseRows<DebtAllocation> rows,
            DebtAllocation row,
          ) => DebtAllocationCard(row: row),
    );
  }
}
