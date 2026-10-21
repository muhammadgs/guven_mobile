import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/debts_controller.dart';
import '../../domain/debt.dart';
import 'database_list.dart';
import 'debt_card.dart';

/// What `Kreditorlar` calls a row: a *kreditor*.
const DatabaseListWords kCreditorsListWords = DatabaseListWords(
  unit: 'kreditor',
  checking: 'Kreditorlar yoxlanılır…',
  empty: 'Kreditor tapılmadı.',
  filteredEmpty: 'Filterə uyğun kreditor tapılmadı.',
);

/// What `Debitorlar` calls a row: a *debitor*.
const DatabaseListWords kDebitorsListWords = DatabaseListWords(
  unit: 'debitor',
  checking: 'Debitorlar yoxlanılır…',
  empty: 'Debitor tapılmadı.',
  filteredEmpty: 'Filterə uyğun debitor tapılmadı.',
);

/// `Kreditorlar` or `Debitorlar`: every open debt as a card, the largest
/// first as the bridge gives them, fetched a page at a time as the list
/// nears its end — or, while a filter is on, the debts it lets through.
/// [DatabaseList] does the work; this says what a card is.
class DebtsList extends StatelessWidget {
  const DebtsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final DebtsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    final DebtKind kind = controller.kind;
    return DatabaseList<Debt>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Debt debt) => debt.id,
      words: switch (kind) {
        DebtKind.creditors => kCreditorsListWords,
        DebtKind.debitors => kDebitorsListWords,
      },
      // The design draws one card; the tab's other single-card designs keep
      // their cards 9pt apart.
      gap: 9,
      card: (BuildContext context, DatabaseRows<Debt> rows, Debt debt) =>
          DebtCard(debt: debt, kind: kind),
    );
  }
}
