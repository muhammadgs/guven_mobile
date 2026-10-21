import 'package:flutter/material.dart';

import '../../application/database_list_controller.dart';
import '../../application/units_of_measure_controller.dart';
import '../../domain/unit_of_measure.dart';
import 'database_list.dart';
import 'unit_of_measure_row.dart';

/// What `Ölçü Vahidləri` calls a row: a *vahid* — the website's own word,
/// `Ölçü vahidi tapılmadı`.
const DatabaseListWords kUnitsOfMeasureListWords = DatabaseListWords(
  unit: 'vahid',
  checking: 'Ölçü vahidləri yoxlanılır…',
  empty: 'Ölçü vahidi tapılmadı.',
  filteredEmpty: 'Filterə uyğun ölçü vahidi tapılmadı.',
);

/// `Ölçü Vahidləri`: every unit in the catalogue as a line of one card, in
/// the bridge's order — by name — fetched a page at a time as the list nears
/// its end; or, while a filter is on, the units it lets through.
/// [DatabaseList] does the work; this says what a line is.
class UnitsOfMeasureList extends StatelessWidget {
  const UnitsOfMeasureList({
    super.key,
    required this.controller,
    required this.bottomReserve,
    required this.sideInset,
  });

  final UnitsOfMeasureController controller;

  /// Vertical space the floating nav bar occupies, kept clear at the bottom
  /// of the list.
  final double bottomReserve;

  /// From the screen's edge to the card's.
  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return DatabaseList<UnitOfMeasure>(
      source: controller,
      bottomReserve: bottomReserve,
      sideInset: sideInset,
      keyOf: (UnitOfMeasure unit) => unit.id,
      words: kUnitsOfMeasureListWords,
      // One card, its lines touching: the rules are what part them.
      gap: 0,
      card: _line,
    );
  }

  /// A unit's line, in either list. The pane closes under the catalogue's
  /// last unit only once there is no more to come: until then the last one
  /// loaded keeps its rule, the card running on under the spinner.
  static Widget _line(
    BuildContext context,
    DatabaseRows<UnitOfMeasure> rows,
    UnitOfMeasure unit,
  ) {
    final List<UnitOfMeasure> list = rows.rows;
    return UnitOfMeasureRow(
      unit: unit,
      first: identical(list.first, unit),
      last: identical(list.last, unit) && !rows.hasMore,
    );
  }
}
