import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/manager_debts_controller.dart';
import '../../domain/manager_debt.dart';
import 'database_list.dart';
import 'manager_debt_card.dart';

/// What `Menecer Borcları` calls a row: a *menecer*.
const DatabaseListWords kManagerDebtsListWords = DatabaseListWords(
  unit: 'menecer',
  checking: 'Menecerlər yoxlanılır…',
  empty: 'Menecer borcu tapılmadı.',
  filteredEmpty: 'Filterə uyğun menecer tapılmadı.',
);

/// `Menecer Borcları`: every manager as a card, the largest debt first as
/// the bridge gives them — or, while a filter is on, the managers it lets
/// through. [DatabaseList] does the work; this says what a card is.
class ManagerDebtsList extends StatelessWidget {
  const ManagerDebtsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final ManagerDebtsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<ManagerDebt>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (ManagerDebt row) => row.id,
      words: kManagerDebtsListWords,
      // The design draws one card; the tab's other single-card designs keep
      // their cards 9pt apart.
      gap: 9,
      card:
          (
            BuildContext context,
            DatabaseRows<ManagerDebt> rows,
            ManagerDebt row,
          ) => ManagerDebtCard(row: row),
    );
  }
}
