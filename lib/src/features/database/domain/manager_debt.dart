import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One manager's debt collection — a row of the website's `Menecer
/// Borcları` table, and one card on the phone.
///
/// A row of `/onec-data/manager-debt-stats/`, read live on 2026-10-21:
/// `{id, manager_id, phys_id, manager, orders_count, total_sales,
/// total_debet, collected, baza_id, synced_at, created_at, updated_at}` — 13
/// managers, one row each, and nothing more to ask for one on its own.
///
/// What the three amounts are, checked on all 13 that day: [sales] and
/// [orders] are the sums of the manager's months on `Menecer Statistikası`
/// — the whole run, not one month; [collected] is the sum of the manager's
/// rows on `Borc Bölgüsü`; and [debt] is what is left, `sales − collected`
/// to the qəpik. There is no percentage in the row: the website works its
/// `TOPLAMA %` out itself, and so does [collectedHundredths].
@immutable
class ManagerDebt {
  const ManagerDebt({
    required this.id,
    this.manager,
    this.orders,
    this.sales,
    this.debt,
    this._collected,
  });

  /// Null when [row] has no id: the id is what tells a row from the one that
  /// takes its place on the next page.
  static ManagerDebt? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id']);
    if (id == null) return null;
    return ManagerDebt(
      id: id,
      manager: readString(row, <String>['manager', 'manager_name']),
      orders: readInt(row, <String>['orders_count']),
      sales: readDouble(row, <String>['total_sales']),
      debt: readDouble(row, <String>['total_debet', 'total_debt']),
      collected: readDouble(row, <String>['collected']),
    );
  }

  final int id;

  /// `Mühasib-istehsal`, `Nərimanov_S1` — the 1C user the documents were
  /// signed with, which is a shop's till as often as a person.
  final String? manager;

  /// `orders_count`: the documents the manager signed.
  final int? orders;

  /// `total_sales`, in manat.
  final double? sales;

  /// `total_debet`: what the manager's customers still owe on those sales,
  /// in manat.
  final double? debt;

  final double? _collected;

  /// `collected`: what has been paid of [sales], in manat. Should a row
  /// come without it, it is what the bridge's own sum would give —
  /// [sales] less [debt].
  double? get collected {
    final double? given = _collected;
    if (given != null) return given;
    final double? sales = this.sales;
    final double? debt = this.debt;
    return sales == null || debt == null ? null : sales - debt;
  }

  /// [collected] as a share of [sales], in hundredths of a percent — 9672
  /// for 96.72% — or null when there are no sales to take a share of.
  ///
  /// Worked out in whole qəpiks, so it is exact, and cut rather than
  /// rounded: the website's `Math.round` shows 100% for a manager still
  /// owed money from 99.5% up, and the user wants the real figure
  /// (2026-10-21). Only a manager owed nothing at all reaches 100%.
  int? get collectedHundredths {
    final double? sales = this.sales;
    final double? collected = this.collected;
    if (sales == null || collected == null) return null;
    final int salesQepik = (sales * 100).round();
    if (salesQepik <= 0) return null;
    // `~/` cuts toward nothing.
    return (collected * 100).round() * 10000 ~/ salesQepik;
  }

  /// [collectedHundredths] as a percentage: `96.72`.
  double? get collectedPercent {
    final int? hundredths = collectedHundredths;
    return hundredths == null ? null : hundredths / 100;
  }
}
