import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One person on 1C's staff register — a row of the website's `Komanda`
/// table, and one card on the phone.
///
/// A row of `/onec-data/team/`, read live on 2026-10-05: `{id, onec_guid,
/// code, full_name, position, department, phone, email, hire_date, salary,
/// is_active, baza_id}`. There is no answer for one person on their own —
/// `/onec-data/team/{id}` is a 404 — and nothing a row leaves out to ask
/// for, so a card is the row and nothing more.
///
/// 1C leaves much of the register blank: of 61 people, 57 had no position,
/// 21 no department and 57 a salary of 0; `phone` and `email` were null on
/// every one. A blank is `""` or `0`, never a word, so [position],
/// [department] and [salary] are null for it.
@immutable
class TeamMember {
  const TeamMember({
    required this.id,
    this.code,
    this.name,
    this.position,
    this.department,
    this.salary,
    this.active,
  });

  /// Null when [row] has no id: the id is what tells a person from the one
  /// that takes their place on the next page.
  static TeamMember? fromJson(Map<String, Object?> row) {
    final int? id = readInt(row, <String>['id', 'employee_id']);
    if (id == null) return null;
    final double? salary = readDouble(row, <String>['salary']);
    return TeamMember(
      id: id,
      code: readString(row, <String>['code']),
      name: readString(row, <String>['full_name', 'name']),
      position: readString(row, <String>['position']),
      department: readString(row, <String>['department']),
      // The website's own test, `m.salary ? … : '—'`: a salary of nothing
      // is one 1C was never given.
      salary: salary == null || salary <= 0 ? null : salary,
      active: readBool(row, <String>['is_active']),
    );
  }

  final int id;

  /// `0000000051` — the person's code in 1C. A few are `д000000014`: 1C
  /// keeps the people it carried over from an older base under a Cyrillic
  /// prefix, the same name sometimes under both.
  final String? code;

  /// `Məhərrəmova Pərvanə Ələstun qızı`, as 1C spells it.
  final String? name;

  /// `Paketçi`, `Qəssab`; null when 1C has none.
  final String? position;

  /// `ƏSAS şöbə`, `İstehsal`; null when 1C has none.
  final String? department;

  /// In manat a month; null when 1C has none.
  final double? salary;

  /// `is_active`: true for every one of the 61 on 2026-10-05.
  final bool? active;
}
