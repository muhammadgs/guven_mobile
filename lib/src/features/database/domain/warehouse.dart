import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One warehouse in 1C's catalogue — a row of the website's `Anbarlar`
/// table, and one card on the phone.
///
/// A row of `/warehouses/`, read live on 2026-10-09: `{id, onec_guid, code,
/// name, warehouse_type, is_active, created_at, updated_at, baza_id}`. There
/// were seven — `Ağ Şəhər Anbar` … `istehsalat`, the same seven a stock row
/// names — every one `default`, active, and with its code blank (`""`). There
/// is nothing more to ask for one on its own: `/warehouses/{id}` is 404.
@immutable
class Warehouse {
  const Warehouse({
    required this.id,
    this.code,
    this.name,
    this.type,
    this.active,
  });

  /// Null when [row] has no id: the id is what tells a warehouse from the
  /// one that takes its place on the next page.
  static Warehouse? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'warehouse_id']);
    if (id == null) return null;
    return Warehouse(
      id: id,
      // Blank reads as null: a blank code is no code, and the card has no
      // line for it (the user, 2026-10-09).
      code: readString(row, <String>['code']),
      name: readString(row, <String>['name']),
      type: readString(row, <String>['warehouse_type']),
      active: readBool(row, <String>['is_active']),
    );
  }

  final int id;

  /// The warehouse's code in 1C — blank on all seven on 2026-10-09, so null.
  final String? code;

  /// `Ağ Şəhər Anbar`, as 1C spells it — inner spaces and all:
  /// `Nizami (6-cı Paralel)  Anbarı` has two.
  final String? name;

  /// `warehouse_type` as the bridge writes it: `default` on all seven.
  final String? type;

  /// `is_active`: true for all seven on 2026-10-09.
  final bool? active;

  /// What the website calls [type] in its `NÖVÜ` column: its own four words
  /// for the four kinds it knows, any other kind as 1C writes it, and
  /// `Standart` when 1C names none.
  String get typeLabel => warehouseTypeLabel(type);
}

/// The website's `typeMap`, and its fallback: `typeMap[t] || t || 'Standart'`.
String warehouseTypeLabel(String? type) => switch (type) {
  null => 'Standart',
  'default' => 'Standart',
  'wholesale' => 'Topdansatış',
  'retail' => 'Pərakəndə',
  'virtual' => 'Virtual',
  final String other => other,
};
