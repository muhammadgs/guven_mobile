/// What every filter on the `Baza` tab shares: a column, a value, and how two
/// values written by 1C are told apart.
library;

import 'package:flutter/foundation.dart';

/// A column a `Baza` list can be narrowed by, as the filter panel lists it.
abstract interface class DatabaseFilterColumn {
  /// The column's name in the panel, and the hint in its search field.
  String get label;
}

/// One value a column can be narrowed to: what is kept, and what is read.
@immutable
class FilterValue {
  const FilterValue(this.value, this.label);

  /// Kept in the filter, exactly as the bridge wrote it.
  final String value;

  /// Shown in the list: the name with its spacing tidied, a kind in words.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FilterValue && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);

  @override
  String toString() => 'FilterValue($value, $label)';
}

/// A span of figures a column is narrowed to — a price between two amounts —
/// either end of which may be left open.
///
/// For a column whose values are figures listing every value is no use: the
/// user asked for `Qiymət` to be a minimum and a maximum rather than a list
/// of every price there is (2026-09-29), and `Stok` and `ƏDV` the same.
@immutable
class FilterRange {
  const FilterRange({this.min, this.max});

  /// Both ends open: the column is not narrowed.
  static const FilterRange any = FilterRange();

  final double? min;
  final double? max;

  bool get isEmpty => min == null && max == null;
  bool get isNotEmpty => !isEmpty;

  /// The span with its ends the right way round: `100`–`10` typed means
  /// `10`–`100`.
  FilterRange get ordered {
    final double? low = min;
    final double? high = max;
    if (low != null && high != null && low > high) {
      return FilterRange(min: high, max: low);
    }
    return this;
  }

  /// Whether [value] lies in the span, ends included.
  ///
  /// A hair either side is let in: a `15.6` typed has to hold the
  /// `15.600000000000001` a sum in 1C can leave.
  bool contains(double value) {
    final FilterRange span = ordered;
    final double? low = span.min;
    final double? high = span.max;
    if (low != null && value < low - _hair) return false;
    if (high != null && value > high + _hair) return false;
    return true;
  }

  /// Whether [value] lies under the span's lower end — so, in a list that
  /// runs from the largest figure down, everything after it does too.
  bool isBelow(double value) {
    final double? low = ordered.min;
    return low != null && value < low - _hair;
  }

  static const double _hair = 1e-9;

  @override
  bool operator ==(Object other) =>
      other is FilterRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'FilterRange($min, $max)';
}

/// How the filter panel asks for a column's [FilterRange]: what its two
/// fields say while empty, what is written after a figure, and whether a
/// figure may be below nothing.
@immutable
class FilterRangeField {
  const FilterRangeField({
    required this.minHint,
    required this.maxHint,
    this.suffix,
    this.signed = false,
    this.day = false,
  });

  /// `Min qiymət`, `Maks qiymət`.
  final String minHint;
  final String maxHint;

  /// `₼`, `%` — or null for a figure written bare.
  final String? suffix;

  /// Whether a minus can be typed: 1C lets a balance go below nothing.
  final bool signed;

  /// Whether the span is of days rather than figures: `01.06.2026` typed,
  /// held as [filterDayOf]'s count. The task list's `Tarix` and `Son
  /// müddət` — the only ordered columns it has (2026-11-08).
  final bool day;

  /// What a field of this span reads [text] as, or null for nothing yet.
  double? parse(String text) =>
      day ? parseFilterDay(text)?.toDouble() : parseFilterFigure(text);

  /// [value] as a field of this span shows it again.
  String write(double value) =>
      day ? writeFilterDay(value.round()) : writeFilterFigure(value);
}

/// [date]'s day as a count of days since 1 January 1970 — what a day span
/// holds, so `FilterRange` compares days the way it compares figures.
int filterDayOf(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The day [filterDayOf] counted.
DateTime filterDayDate(int day) => DateTime.fromMillisecondsSinceEpoch(
  day * Duration.millisecondsPerDay,
  isUtc: true,
);

/// [day] as a day field shows it: `01.06.2026`.
String writeFilterDay(int day) {
  final DateTime date = filterDayDate(day);
  final String d = date.day.toString().padLeft(2, '0');
  final String m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

/// A day as it was typed — `01.06.2026`, or `01.06` for this year — as
/// [filterDayOf] counts it. Null for nothing, for a year not typed out yet,
/// and for a day the calendar has not got: `31.02`.
int? parseFilterDay(String text, {DateTime? today}) {
  final List<String> parts = text.trim().split(RegExp(r'[.\-/ ]')).toList();
  if (parts.length == 3 && parts.last.isEmpty) parts.removeLast();
  if (parts.length < 2 || parts.length > 3) return null;
  final int? day = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? year = parts.length == 3
      ? (parts[2].length == 4 ? int.tryParse(parts[2]) : null)
      : (today ?? DateTime.now()).year;
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1) return null;
  final DateTime date = DateTime.utc(year, month, day);
  if (date.day != day || date.month != month) return null;
  return filterDayOf(date);
}

/// A figure as it was typed: `15.6`, `15,6` — the comma a local keyboard
/// puts where the point goes — or ` 15 `. Null for nothing, or for what is
/// not a figure yet: `-`, `.`.
double? parseFilterFigure(String text) {
  final String typed = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (typed.isEmpty) return null;
  final double? figure = double.tryParse(typed);
  return figure != null && figure.isFinite ? figure : null;
}

/// [figure] as a range field shows it again: bare, with no trailing zeros —
/// `15`, `15.6`, `-41`.
String writeFilterFigure(double figure) {
  if (figure == figure.roundToDouble()) return figure.toStringAsFixed(0);
  String text = figure.toStringAsFixed(6);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

final RegExp _spaces = RegExp(r'\s+');

/// [text] with its runs of spaces made one: `THE GARDEN CENTRAL RESTORAN
/// N.Ö.` as the design prints it, whatever 1C typed — and what a web page
/// shows of the same name, since HTML collapses them too.
String tidySpaces(String text) => text.trim().replaceAll(_spaces, ' ');

/// [text] as a filter compares two values: spacing, case and both i's set
/// aside.
///
/// Dart lower-cases `İ` into an `i` and a combining dot, and 1C's data mixes
/// the dotted and the dotless one in the same name, so both are folded into a
/// plain `i` — the bridge's own search treats `FAVORIT` and `FAVORİT` as one
/// word too.
String filterKey(String text) =>
    tidySpaces(text).toLowerCase().replaceAll('̇', '').replaceAll('ı', 'i');

/// [text] as a search compares it: [filterKey], with the letters Azerbaijani
/// adds to the Latin alphabet folded into the ones a keyboard without them
/// types instead — `sebeke` finds `ŞƏBƏKƏSİ`.
String filterSearchKey(String text) {
  final String key = filterKey(text);
  final StringBuffer out = StringBuffer();
  for (final int rune in key.runes) {
    out.write(switch (rune) {
      0x0259 => 'e', // ə
      0x00F6 => 'o', // ö
      0x00FC => 'u', // ü
      0x015F => 's', // ş
      0x00E7 => 'c', // ç
      0x011F => 'g', // ğ
      _ => String.fromCharCode(rune),
    });
  }
  return out.toString();
}

/// One month of one year — `07.2026` — which is how 1C files its monthly
/// figures, and what a [FilterPeriod] is made of.
@immutable
class FilterMonth implements Comparable<FilterMonth> {
  const FilterMonth(this.year, this.month) : assert(month >= 1 && month <= 12);

  final int year;

  /// 1 for January, 12 for December.
  final int month;

  /// The months since year nought: one more for every month later.
  int get index => year * 12 + month - 1;

  /// The month after this one, or [count] after it.
  FilterMonth plus(int count) {
    final int at = index + count;
    return FilterMonth(at ~/ 12, at % 12 + 1);
  }

  bool operator <(FilterMonth other) => index < other.index;
  bool operator >(FilterMonth other) => index > other.index;

  @override
  int compareTo(FilterMonth other) => index.compareTo(other.index);

  @override
  bool operator ==(Object other) =>
      other is FilterMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  /// `07.2026`, as 1C writes it.
  @override
  String toString() => '${month.toString().padLeft(2, '0')}.$year';
}

/// A run of months a column is narrowed to — `07.2026` to `09.2026` — either
/// end of which may be left open, both ends included.
///
/// The user's rule for a period (2026-10-05): a start and an end, each a
/// month and a year, rather than a list of every month there is.
@immutable
class FilterPeriod {
  const FilterPeriod({this.from, this.to});

  /// Both ends open: the column is not narrowed.
  static const FilterPeriod any = FilterPeriod();

  final FilterMonth? from;
  final FilterMonth? to;

  bool get isEmpty => from == null && to == null;
  bool get isNotEmpty => !isEmpty;

  /// The period with its ends the right way round: September to July
  /// means July to September.
  FilterPeriod get ordered {
    final FilterMonth? start = from;
    final FilterMonth? end = to;
    if (start != null && end != null && start > end) {
      return FilterPeriod(from: end, to: start);
    }
    return this;
  }

  /// Whether [month] lies in the period, ends included.
  bool contains(FilterMonth month) {
    final FilterPeriod span = ordered;
    final FilterMonth? start = span.from;
    final FilterMonth? end = span.to;
    if (start != null && month < start) return false;
    if (end != null && month > end) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is FilterPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'FilterPeriod($from, $to)';
}

/// What is typed into a page's quick search bar, beside its funnel: a few
/// letters the page's own headline — `Satışlar`' customer, `Məhsullar`'
/// product — must hold somewhere (2026-11-08).
///
/// Unlike a filter column, which keeps one whole value, this is a piece of
/// one, compared through [filterSearchKey]: `hollywood` finds
/// `QASIMOV ƏLİYAR ƏRƏSTUN OĞLU - HOLLYWOOD`, and `sebeke` finds `ŞƏBƏKƏSİ`.
@immutable
class QuickSearch {
  factory QuickSearch(String typed) {
    final String text = tidySpaces(typed);
    if (text.isEmpty) return none;
    return QuickSearch._(text, filterSearchKey(text), _bridgeTextOf(text));
  }

  const QuickSearch._(this.text, this._key, this.bridgeText);

  /// Nothing typed.
  static const QuickSearch none = QuickSearch._('', '', null);

  /// What was typed, its spacing tidied.
  final String text;

  final String _key;

  bool get isEmpty => text.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// What is sent to the bridge as `search`, or null for nothing worth
  /// sending — the whole table is then read and checked on the phone.
  ///
  /// The bridge's own `search` is a substring too, over the headline among
  /// a field or two more, so it narrows the answer to a few rows and
  /// [matches] keeps the ones whose headline it was. But it does not fold
  /// `ə` into `e` (measured 2026-11-08: `sebeke` finds nothing on
  /// `Satışlar`), so a text typed without Azerbaijani letters is not sent
  /// whole: only its longest run of letters that are written the same
  /// either way — `hollywood` sends `llyw`, `favorit` sends `fav`.
  final String? bridgeText;

  /// Whether the bridge is sent less than was typed, or nothing: what it
  /// answers is mostly rows the phone throws away.
  bool get scans => isNotEmpty && bridgeText != text;

  /// The letters a keyboard without Azerbaijani ones types in their place:
  /// `ə`, `ö`, `ü`, `ş`, `ç`, `ğ`, `ı` and `İ`.
  static const String _standIns = 'eoucsgiEOUCSGI';

  static String? _bridgeTextOf(String text) {
    // Typed with the letters themselves: sent as typed.
    if (text.runes.any((int rune) => rune > 0x7F)) return text;
    String best = '';
    for (final String run in text.split(RegExp('[$_standIns]'))) {
      if (run.trim().length > best.trim().length) best = run;
    }
    if (best.length == text.length) return text;
    best = best.trim();
    // A letter or two finds most of the table: reading it is no slower.
    return best.length < 2 ? null : best;
  }

  /// Whether [field] holds what was typed — always, for nothing typed.
  bool matches(String? field) =>
      isEmpty || (field != null && filterSearchKey(field).contains(_key));

  @override
  bool operator ==(Object other) => other is QuickSearch && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'QuickSearch($text)';
}
