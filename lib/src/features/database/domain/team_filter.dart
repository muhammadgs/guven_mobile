import 'package:flutter/foundation.dart';

import 'database_filter.dart';
import 'team_member.dart';

/// A column of the `Komanda` filter: every field the card shows, in the
/// card's order.
enum TeamColumn implements DatabaseFilterColumn {
  code('Kod'),
  name('Ad-soyad'),
  position('Vəzifə'),
  department('Şöbə'),
  salary('Maaş'),
  status('Status');

  const TeamColumn(this.label);

  @override
  final String label;

  /// Whether the bridge's `search` can find this column's value.
  ///
  /// Probed on the live bridge (2026-10-05): `search` on `/onec-data/team/`
  /// is one case-insensitive substring over the person's code, name,
  /// position and department — `PAKETÇİ` finds `Paketçi`, `şöbə` every
  /// `ƏSAS şöbə` — and nothing else: not a salary, not the status.
  bool get searchable =>
      this == TeamColumn.code ||
      this == TeamColumn.name ||
      this == TeamColumn.position ||
      this == TeamColumn.department;

  /// Whether the column is narrowed by a span of figures — a minimum and a
  /// maximum — rather than by one of its values: the user's rule for every
  /// figure on the tab since `Məhsullar`' price.
  bool get takesRange => this == TeamColumn.salary;

  /// Whether the column's values can only all be known by reading every
  /// person: the bridge can list neither its positions nor its departments.
  bool get needsEveryone =>
      this == TeamColumn.position || this == TeamColumn.department;
}

/// The `Status` column's two values: the website's `Aktiv` and `Deaktiv`.
///
/// Everyone was active on 2026-10-05, but 1C can switch a person off and
/// the website has a word for it, so both are offered.
enum TeamStatus {
  active('Aktiv'),
  inactive('Deaktiv');

  const TeamStatus(this.label);

  final String label;

  /// A person whose status 1C does not say is neither.
  bool matches(TeamMember member) =>
      member.active != null && member.active == (this == TeamStatus.active);

  static TeamStatus? byName(String name) {
    for (final TeamStatus status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// What `Komanda` is narrowed to: at most one value a column — or, for the
/// salary, one span.
///
/// A value is kept exactly as the bridge wrote it and compared through
/// [filterKey].
@immutable
class TeamFilter {
  const TeamFilter._(this._chosen, this._ranges);

  static const TeamFilter none = TeamFilter._(
    <TeamColumn, String>{},
    <TeamColumn, FilterRange>{},
  );

  final Map<TeamColumn, String> _chosen;
  final Map<TeamColumn, FilterRange> _ranges;

  bool get isEmpty => _chosen.isEmpty && _ranges.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many columns are narrowing the list — the number on the funnel.
  int get columnCount => columns.length;

  /// The columns doing something, in the card's order.
  List<TeamColumn> get columns => <TeamColumn>[
    for (final TeamColumn column in TeamColumn.values)
      if (has(column)) column,
  ];

  bool has(TeamColumn column) =>
      _chosen.containsKey(column) || _ranges.containsKey(column);

  /// The column's value, or null.
  String? valueOf(TeamColumn column) => _chosen[column];

  List<String> valuesOf(TeamColumn column) {
    final String? value = _chosen[column];
    return value == null ? const <String>[] : <String>[value];
  }

  bool isChosen(TeamColumn column, String value) => _chosen[column] == value;

  /// The column's span — open at both ends when it has none.
  FilterRange rangeOf(TeamColumn column) => _ranges[column] ?? FilterRange.any;

  /// The column worth sending to the bridge as `search`: the code, which
  /// names one person, then the name, the position and the department.
  TeamColumn? get searchColumn {
    for (final TeamColumn column in TeamColumn.values) {
      if (column.searchable && _chosen.containsKey(column)) return column;
    }
    return null;
  }

  /// [value] chosen — or let go, if it already was. Choosing replaces
  /// whatever the column held.
  TeamFilter toggle(TeamColumn column, String value) {
    final Map<TeamColumn, String> chosen = Map<TeamColumn, String>.of(_chosen);
    final Map<TeamColumn, FilterRange> ranges = Map<TeamColumn, FilterRange>.of(
      _ranges,
    );
    if (chosen[column] == value) {
      chosen.remove(column);
    } else {
      chosen[column] = value;
      ranges.remove(column);
    }
    return TeamFilter._freeze(chosen, ranges);
  }

  /// [column] narrowed to [range]; an empty span lets go of it.
  TeamFilter withRange(TeamColumn column, FilterRange range) {
    final Map<TeamColumn, FilterRange> ranges = Map<TeamColumn, FilterRange>.of(
      _ranges,
    );
    if (range.isEmpty) {
      if (!ranges.containsKey(column)) return this;
      ranges.remove(column);
    } else {
      ranges[column] = range;
    }
    return TeamFilter._freeze(
      Map<TeamColumn, String>.of(_chosen)..remove(column),
      ranges,
    );
  }

  /// [column] let go: `Hamısı`.
  TeamFilter cleared(TeamColumn column) {
    if (!has(column)) return this;
    return TeamFilter._freeze(
      Map<TeamColumn, String>.of(_chosen)..remove(column),
      Map<TeamColumn, FilterRange>.of(_ranges)..remove(column),
    );
  }

  static TeamFilter _freeze(
    Map<TeamColumn, String> chosen,
    Map<TeamColumn, FilterRange> ranges,
  ) => TeamFilter._(
    Map<TeamColumn, String>.unmodifiable(chosen),
    Map<TeamColumn, FilterRange>.unmodifiable(ranges),
  );

  /// Whether [member] survives every column.
  ///
  /// A person whose salary 1C does not have is in no span: their card says
  /// nothing about a salary, and a list of those paid up to 700 ₼ should
  /// not be mostly people whose pay nobody wrote down.
  bool matches(TeamMember member) {
    for (final MapEntry<TeamColumn, String> entry in _chosen.entries) {
      if (!_matches(entry.key, entry.value, member)) return false;
    }
    for (final MapEntry<TeamColumn, FilterRange> entry in _ranges.entries) {
      final double? salary = member.salary;
      if (salary == null || !entry.value.contains(salary)) return false;
    }
    return true;
  }

  static bool _matches(TeamColumn column, String value, TeamMember member) {
    bool same(String? field) =>
        field != null && filterKey(field) == filterKey(value);

    return switch (column) {
      TeamColumn.code => same(member.code),
      TeamColumn.name => same(member.name),
      TeamColumn.position => same(member.position),
      TeamColumn.department => same(member.department),
      TeamColumn.status => TeamStatus.byName(value)?.matches(member) ?? true,
      // A salary is narrowed by a span, never by a value.
      TeamColumn.salary => true,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TeamFilter &&
      mapEquals(other._chosen, _chosen) &&
      mapEquals(other._ranges, _ranges);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<TeamColumn, String> entry in _chosen.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAllUnordered(<Object>[
      for (final MapEntry<TeamColumn, FilterRange> entry in _ranges.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => 'TeamFilter($_chosen, $_ranges)';
}
