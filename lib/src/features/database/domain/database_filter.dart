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
    const double hair = 1e-9;
    final FilterRange span = ordered;
    final double? low = span.min;
    final double? high = span.max;
    if (low != null && value < low - hair) return false;
    if (high != null && value > high + hair) return false;
    return true;
  }

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
  });

  /// `Min qiymət`, `Maks qiymət`.
  final String minHint;
  final String maxHint;

  /// `₼`, `%` — or null for a figure written bare.
  final String? suffix;

  /// Whether a minus can be typed: 1C lets a balance go below nothing.
  final bool signed;
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
