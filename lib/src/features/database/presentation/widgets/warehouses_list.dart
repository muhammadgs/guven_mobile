import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/warehouses_controller.dart';
import '../../domain/warehouse.dart';
import 'database_list.dart';
import 'warehouse_card.dart';

/// What `Anbarlar` calls a row: an *anbar* — the website's own word, `Anbar
/// tapılmadı`.
const DatabaseListWords kWarehousesListWords = DatabaseListWords(
  unit: 'anbar',
  checking: 'Anbarlar yoxlanılır…',
  empty: 'Anbar tapılmadı.',
  filteredEmpty: 'Filterə uyğun anbar tapılmadı.',
);

/// `Anbarlar`: every warehouse in the catalogue as a card, in the bridge's
/// order — by name — fetched a page at a time as the list nears its end; or,
/// while a filter is on, the warehouses it lets through. [DatabaseList] does
/// the work; this says what a card is.
class WarehousesList extends StatelessWidget {
  const WarehousesList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final WarehousesController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<Warehouse>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (Warehouse warehouse) => warehouse.id,
      words: kWarehousesListWords,
      // `Kassalar`' card, `Kassalar`' 9pt between cards.
      gap: 9,
      card: _card,
    );
  }

  /// The same card in either list: a warehouse's card has nothing to open.
  static Widget _card(
    BuildContext context,
    DatabaseRows<Warehouse> rows,
    Warehouse warehouse,
  ) => WarehouseCard(warehouse: warehouse);
}
