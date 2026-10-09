import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One cash desk in 1C's catalogue — a row of the website's `Kassalar`
/// table, and one card on the phone.
///
/// A row of `/cash-desks/`, read live on 2026-10-05: `{id, onec_guid, code,
/// name, currency, is_active, created_at, updated_at, baza_id}`. There were
/// three — `Əsas Kassa`, `Nərimanov kassası`, `Danət Kassa` — all in manat
/// and all active, and nothing more to ask for one on its own. The 1C guid
/// the website prints in its last column is left out: the user's word.
@immutable
class CashDesk {
  const CashDesk({
    required this.id,
    this.code,
    this.name,
    this.currency = kCashDeskCurrency,
    this.active,
  });

  /// Null when [row] has no id: the id is what tells a desk from the one
  /// that takes its place on the next page.
  static CashDesk? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'cash_desk_id']);
    if (id == null) return null;
    return CashDesk(
      id: id,
      code: readString(row, <String>['code']),
      name: readString(row, <String>['name']),
      // The website's own rule, `c.currency || 'AZN'`: a desk 1C names no
      // currency for keeps the company's own.
      currency: readString(row, <String>['currency']) ?? kCashDeskCurrency,
      active: readBool(row, <String>['is_active']),
    );
  }

  final int id;

  /// `NT0000001` — the desk's code in 1C.
  final String? code;

  /// `Əsas Kassa`, as 1C spells it.
  final String? name;

  /// `AZN` — or, when 1C names none, [kCashDeskCurrency].
  final String currency;

  /// `is_active`: true for all three on 2026-10-05.
  final bool? active;
}

/// What a desk's currency is when 1C does not say: the website's `AZN`.
const String kCashDeskCurrency = 'AZN';
