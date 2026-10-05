import 'package:flutter/foundation.dart';

import '../../../core/json.dart';
import 'database_filter.dart';

/// One manager's sales in one month — a row of the website's `Menecer
/// Statistikası` table, and one card on the phone.
///
/// A row of `/onec-data/manager-stats/`, read live on 2026-10-05: `{id,
/// manager_id, phys_id, manager, year, month, month_label, orders_count,
/// total_amount, baza_id, synced_at, created_at, updated_at}`. There is a
/// row for every manager for every month they sold in — 34 of them for 13
/// managers over July to September 2026 — and nothing more to ask for one
/// on its own.
@immutable
class ManagerStat {
  const ManagerStat({
    required this.id,
    this.manager,
    this.year,
    this.month,
    this.monthLabel,
    this.orders,
    this.amount,
  });

  /// Null when [row] has no id: the id is what tells a row from the one that
  /// takes its place on the next page.
  static ManagerStat? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id']);
    if (id == null) return null;
    final int? month = readInt(row, <String>['month']);
    return ManagerStat(
      id: id,
      manager: readString(row, <String>['manager', 'manager_name']),
      year: readInt(row, <String>['year']),
      month: month != null && month >= 1 && month <= 12 ? month : null,
      monthLabel: readString(row, <String>['month_label']),
      orders: readInt(row, <String>['orders_count']),
      amount: readDouble(row, <String>['total_amount']),
    );
  }

  final int id;

  /// `Mühasib-istehsal`, `Nərimanov_S1` — the 1C user the documents were
  /// signed with, which is a shop's till as often as a person.
  final String? manager;

  final int? year;

  /// 1 for January; null when 1C's is not a month.
  final int? month;

  /// `07.2026` — 1C's own way of writing [month] and [year].
  final String? monthLabel;

  /// `orders_count`: the documents the manager signed that month.
  final int? orders;

  /// `total_amount`, in manat.
  final double? amount;

  /// The month the row is for, out of [year] and [month] — or, failing
  /// those, out of [monthLabel].
  FilterMonth? get period {
    final int? year = this.year;
    final int? month = this.month;
    if (year != null && month != null) return FilterMonth(year, month);
    final RegExpMatch? match = _label.firstMatch(monthLabel ?? '');
    if (match == null) return null;
    final int parsed = int.parse(match.group(1)!);
    if (parsed < 1 || parsed > 12) return null;
    return FilterMonth(int.parse(match.group(2)!), parsed);
  }

  /// `07.2026` — what the card says for the period: 1C's own label when it
  /// gives one, the month written the same way when it does not.
  ///
  /// The website prints the label *and* the year after it (`07.2026 2026`),
  /// which says the year twice.
  String? get periodLabel => monthLabel ?? period?.toString();

  static final RegExp _label = RegExp(r'^(\d{1,2})\.(\d{4})$');
}
