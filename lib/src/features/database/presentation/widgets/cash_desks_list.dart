import 'package:flutter/material.dart';

import '../../application/cash_desks_controller.dart';
import '../../application/database_list_controller.dart';
import '../../domain/cash_desk.dart';
import 'cash_desk_card.dart';
import 'database_list.dart';

/// What `Kassalar` calls a row: a *kassa* — the website's own word, `Kassa
/// tapılmadı`.
const DatabaseListWords kCashDesksListWords = DatabaseListWords(
  unit: 'kassa',
  checking: 'Kassalar yoxlanılır…',
  empty: 'Kassa tapılmadı.',
  filteredEmpty: 'Filterə uyğun kassa tapılmadı.',
);

/// `Kassalar`: every cash desk in the catalogue as a card, in the bridge's
/// order — the newest first — fetched a page at a time as the list nears its
/// end; or, while a filter is on, the desks it lets through. [DatabaseList]
/// does the work; this says what a card is.
class CashDesksList extends StatelessWidget {
  const CashDesksList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final CashDesksController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<CashDesk>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (CashDesk desk) => desk.id,
      words: kCashDesksListWords,
      // `Komanda`'s card, `Komanda`'s 9pt between cards.
      gap: 9,
      card: _card,
    );
  }

  /// The same card in either list: a desk's card has nothing to open.
  static Widget _card(
    BuildContext context,
    DatabaseRows<CashDesk> rows,
    CashDesk desk,
  ) => CashDeskCard(desk: desk);
}
