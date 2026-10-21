import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One unit of measure in 1C's catalogue — a row of the website's `Ölçü
/// Vahidləri` table, and one line of the phone's.
///
/// A row of `/units-of-measure/`, read live on 2026-10-10: `{id, onec_guid,
/// code, name, international_code, created_at, updated_at, baza_id}`. There
/// were 32 — `Ay`, `Bağlama` … `əd` — every one with a three-digit code and
/// a name, nine with the international code blank (`""`); no status at all.
/// There is nothing more to ask for one on its own: `/units-of-measure/{id}`
/// is 404. The 1C guid the website prints in its last column is left out,
/// as on every other catalogue page.
@immutable
class UnitOfMeasure {
  const UnitOfMeasure({
    required this.id,
    this.code,
    this.name,
    this.internationalCode,
  });

  /// Null when [row] has no id: the id is what tells a unit from the one
  /// that takes its place on the next page.
  static UnitOfMeasure? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'unit_id']);
    if (id == null) return null;
    return UnitOfMeasure(
      id: id,
      // Blank reads as null: a blank field is drawn as nothing at all.
      code: readString(row, <String>['code']),
      name: readString(row, <String>['name']),
      internationalCode: readString(row, <String>['international_code']),
    );
  }

  final int id;

  /// `110` — the unit's code in 1C.
  final String? code;

  /// `Bağlama`, as 1C spells it: `DƏFƏ`, `kq` and `Nəfər` (twice, under two
  /// codes) are all in the live catalogue.
  final String? name;

  /// `Bağ` — what the website heads `BEYNƏLXALQ KOD`. Blank on nine of the
  /// 32 on 2026-10-10, so null; and not always international (`Ay` is the
  /// one given to `Çəllək` and `TOP` as well as to `Ay`).
  final String? internationalCode;
}
