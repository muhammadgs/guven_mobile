import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/manager_stats_controller.dart';
import '../../domain/manager_stat.dart';
import 'database_list.dart';
import 'manager_stat_card.dart';

/// What `Menecer statistikası` calls a row: a *qeyd*, as `Stok` does — one
/// manager's month is neither a document nor a person. The empty list says
/// what the website says, `Statistika tapılmadı`.
const DatabaseListWords kManagerStatsListWords = DatabaseListWords(
  unit: 'qeyd',
  checking: 'Qeydlər yoxlanılır…',
  empty: 'Statistika tapılmadı.',
  filteredEmpty: 'Filterə uyğun qeyd tapılmadı.',
);

/// `Menecer statistikası`: every manager's every month as a card, in the
/// bridge's order — the largest month first — fetched a page at a time as
/// the list nears its end; or, while a filter is on, the rows it lets
/// through. [DatabaseList] does the work; this says what a card is.
class ManagerStatsList extends StatelessWidget {
  const ManagerStatsList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final ManagerStatsController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to a card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<ManagerStat>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (ManagerStat stat) => stat.id,
      words: kManagerStatsListWords,
      card: _card,
    );
  }

  /// The same card in either list: a month's card has nothing to open.
  static Widget _card(
    BuildContext context,
    DatabaseRows<ManagerStat> rows,
    ManagerStat stat,
  ) => ManagerStatCard(stat: stat);
}
