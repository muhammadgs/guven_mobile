import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'unit_of_measure.dart';

/// A column of the `Ölçü Vahidləri` filter: every field a line shows, in the
/// line's order — the website's three columns, less its guid.
enum UnitsOfMeasureColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Vahid adı'),
  internationalCode('Beynəlxalq kod');

  const UnitsOfMeasureColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-10): `search` on
  /// `/units-of-measure/` is one case-insensitive substring over the unit's
  /// code and name — `11` finds `110`, `111`, `112` and `113`, `BAĞ` finds
  /// `Bağlama` — and nothing else: not the international code (`KGM`, on
  /// two units, finds none), and with no folding of `ğ` (`bag` finds none).
  bool get searchable =>
      this == UnitsOfMeasureColumn.code || this == UnitsOfMeasureColumn.name;

  /// Whether the column's values can only all be known by reading every
  /// unit: the bridge cannot search the international codes.
  bool get needsEveryone => this == UnitsOfMeasureColumn.internationalCode;
}

/// What `Ölçü Vahidləri` is narrowed to: at most one value a column.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class UnitsOfMeasureFilter {
  const UnitsOfMeasureFilter._(this._chosen);

  static const UnitsOfMeasureFilter none = UnitsOfMeasureFilter._(
    <UnitsOfMeasureColumn, String>{},
  );

  final Map<UnitsOfMeasureColumn, String> _chosen;

  bool get isEmpty => _chosen.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => _chosen.length;

  /// The columns doing something, in the line's order.
  List<UnitsOfMeasureColumn> get columns => <UnitsOfMeasureColumn>[
    for (final UnitsOfMeasureColumn column in UnitsOfMeasureColumn.values)
      if (has(column)) column,
  ];

  bool has(UnitsOfMeasureColumn column) => _chosen.containsKey(column);

  /// The column's value, or null.
  String? valueOf(UnitsOfMeasureColumn column) => _chosen[column];

  List<String> valuesOf(UnitsOfMeasureColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(UnitsOfMeasureColumn column, String value) =>
      _chosen[column] == value;

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one unit, then the name.
  UnitsOfMeasureColumn? get searchColumn {
    for (final UnitsOfMeasureColumn column in UnitsOfMeasureColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  UnitsOfMeasureFilter toggle(UnitsOfMeasureColumn column, String value) {
    final Map<UnitsOfMeasureColumn, String> chosen =
        Map<UnitsOfMeasureColumn, String>.of(_chosen);
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
    }
    return UnitsOfMeasureFilter._(
      Map<UnitsOfMeasureColumn, String>.unmodifiable(chosen),
    );
  }

  /// [column] let go: `Hamısı`.
  UnitsOfMeasureFilter cleared(UnitsOfMeasureColumn column) {
    if (!has(column)) return this;
    return UnitsOfMeasureFilter._(
      Map<UnitsOfMeasureColumn, String>.unmodifiable(
        Map<UnitsOfMeasureColumn, String>.of(_chosen)..remove(column),
      ),
    );
  }

  /// Whether [unit] survives every column.
  bool matches(UnitOfMeasure unit) {
    for (final MapEntry<UnitsOfMeasureColumn, String> entry
        in _chosen.entries) {
      final String? field = switch (entry.key) {
        UnitsOfMeasureColumn.code => unit.code,
        UnitsOfMeasureColumn.name => unit.name,
        UnitsOfMeasureColumn.internationalCode => unit.internationalCode,
      };
      if (field == null || filterKey(field) != filterKey(entry.value)) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is UnitsOfMeasureFilter && mapEquals(other._chosen, _chosen);

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<UnitsOfMeasureColumn, String> entry in _chosen.entries)
      Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'UnitsOfMeasureFilter($_chosen)';
}
