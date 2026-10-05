import 'package:flutter/foundation.dart';

import '../domain/database_filter.dart';

/// What the filter panel narrows: a `Baza` list with columns to choose values
/// in.
///
/// The panel is the same glass on every page that has a funnel — only the
/// columns and where their values come from differ — so it asks for exactly
/// this and nothing about the rows. Column parameters are `covariant`: each
/// page takes its own kind of column, and the panel only ever hands back the
/// ones [filterColumns] gave it.
abstract interface class DatabaseFilterSource implements Listenable {
  /// The columns, in the order the panel lists them.
  List<DatabaseFilterColumn> get filterColumns;

  /// Whether any column is narrowing the list.
  bool get isFiltered;

  /// How many columns are narrowing the list — the number on the funnel.
  int get filterCount;

  /// Whether [column] is one of them.
  bool narrows(covariant DatabaseFilterColumn column);

  /// Whether [value] is chosen in [column].
  bool isChosen(covariant DatabaseFilterColumn column, String value);

  /// [value] chosen in [column] — or let go, if it already was.
  Future<void> toggleFilter(
    covariant DatabaseFilterColumn column,
    String value,
  );

  /// [column] let go: `Hamısı`.
  Future<void> clearFilterColumn(covariant DatabaseFilterColumn column);

  /// Every column let go: `Sıfırla`.
  Future<void> clearFilter();

  /// The values the open column offers.
  DatabaseFilterValues get filterValues;
}

/// A filter some of whose columns are narrowed by a span of figures — a price
/// between a minimum and a maximum — rather than by one of their values.
///
/// The panel opens such a column onto two fields instead of a list of every
/// figure there is. Whatever values [DatabaseFilterSource.filterValues] still
/// lists for it — `ƏDV yoxdur` — are offered under the fields, and choosing
/// one lets go of the span.
abstract interface class DatabaseRangeFilterSource
    implements DatabaseFilterSource {
  /// How [column] asks for its span, or null for a column of values.
  FilterRangeField? rangeFieldOf(covariant DatabaseFilterColumn column);

  /// The span [column] is narrowed to — [FilterRange.any] when it is not.
  FilterRange rangeOf(covariant DatabaseFilterColumn column);

  /// [column] narrowed to [range]. An empty span lets go of the span, and
  /// leaves a value the column holds alone.
  Future<void> setRange(
    covariant DatabaseFilterColumn column,
    FilterRange range,
  );
}

/// The values the filter's open column offers, for what has been typed into
/// its search.
abstract interface class DatabaseFilterValues implements Listenable {
  /// The column whose values are showing, or null.
  DatabaseFilterColumn? get column;

  List<FilterValue> get values;

  /// True while the bridge is being asked about what was typed.
  bool get isSearching;

  /// What the list says while it has nothing to show because its values are
  /// still being gathered — `2,400 / 7,519 sifariş oxundu` — or null.
  String? get progress;

  /// Opens [column] with nothing typed.
  void open(covariant DatabaseFilterColumn column);

  /// Nothing showing.
  void close();

  /// Narrows the list to [text], asking the bridge where it can.
  void search(String text);

  /// Keeps [value] at the top the next time the list is rebuilt.
  void remember(String value);
}

/// A filter one of whose columns is narrowed by a run of months — a start
/// and an end, each a month and a year — rather than by one of its values.
///
/// The panel opens such a column onto the two ends and a calendar of months
/// to set them from, instead of a list.
abstract interface class DatabasePeriodFilterSource
    implements DatabaseFilterSource {
  /// Whether [column] is narrowed by a period.
  bool takesPeriod(covariant DatabaseFilterColumn column);

  /// The period [column] is narrowed to — [FilterPeriod.any] when it is not.
  FilterPeriod periodOf(covariant DatabaseFilterColumn column);

  /// [column] narrowed to [period]. An empty period lets go of it.
  Future<void> setPeriod(
    covariant DatabaseFilterColumn column,
    FilterPeriod period,
  );

  /// The months the rows on the phone fall in: the calendar sets them in
  /// ink and every other month paler, so a period is not chosen blind.
  Set<FilterMonth> periodMonthsOf(covariant DatabaseFilterColumn column);
}
