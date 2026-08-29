/// How this app writes a task's dates.
///
/// One place rather than two: the card prints these and the filter groups its
/// `Tarix` / `Son müddət` values by them, so a card and the filter row that
/// selects it can never disagree about what day a task belongs to.
library;

/// `2026-08-25`. The design's format, and the site's.
String formatTaskDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

/// `18:15`.
String formatTaskTime(DateTime value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
