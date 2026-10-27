import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'database_filter.dart';
import 'sale.dart' show readDocumentDate;

/// One sale's share of what a manager has collected — a row of the
/// website's `Borc Bölgüsü` table, and one card on the phone.
///
/// A row of `/onec-data/manager-debt-allocations/`, read live on
/// 2026-10-22: `{id, sale_id, sale_date ("2026-10-07"), manager_id,
/// phys_id, manager, allocated, baza_id, synced_at, created_at,
/// updated_at}` — 5,989 of them, one a sale, and nothing more to ask for
/// one on its own. A manager's rows add up to their `Yığılmış` on
/// `Menecer Borcları` to the qəpik.
///
/// The website shows the sale's 1C guid as its first column; the user left
/// it off the phone (2026-10-22), so it is not kept.
@immutable
class DebtAllocation {
  const DebtAllocation({
    required this.id,
    this.date,
    this.manager,
    this.allocated,
  });

  /// Null when [row] has no id: the id is what tells a row from the one that
  /// takes its place on the next page.
  static DebtAllocation? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id']);
    if (id == null) return null;
    return DebtAllocation(
      id: id,
      date: readDocumentDate(row, <String>['sale_date', 'date']),
      manager: readString(row, <String>['manager', 'manager_name']),
      allocated: readDouble(row, <String>['allocated', 'amount']),
    );
  }

  final int id;

  /// The sale's day, as `2026-10-07`.
  final String? date;

  /// `Mühasib-istehsal`, `Nərimanov_S1` — the 1C user the sale was signed
  /// with.
  final String? manager;

  /// `allocated`: what of the sale has been paid and filed to [manager], in
  /// manat.
  final double? allocated;

  /// The month of [date], or null when there is no date to read one from.
  FilterMonth? get month {
    final RegExpMatch? match = _day.firstMatch(date ?? '');
    if (match == null) return null;
    final int month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return null;
    return FilterMonth(int.parse(match.group(1)!), month);
  }

  static final RegExp _day = RegExp(r'^(\d{4})-(\d{2})-\d{2}');
}
