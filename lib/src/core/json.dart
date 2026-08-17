/// Tolerant readers for a backend that is not consistent about shapes.
///
/// The same list arrives as a bare array from one endpoint, wrapped in
/// `{"data": …}` from another and `{"sub_companies": …}` from a third; a
/// person's given name is `first_name` on an employee and `ceo_name` on a
/// company owner. The web client copes by testing every spelling at each call
/// site. That sprawl is collected here instead, so the feature code can ask
/// for what it wants and get null when it is genuinely absent.
library;

/// [value] as a map, or an empty one.
Map<String, Object?> asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

/// The list [value] holds, wherever it is holding it.
///
/// Accepts a bare array, or an object carrying one under any of [keys] (tried
/// in order) or under the usual envelope names. Anything else yields an empty
/// list — callers count these, and a count of zero beats a crash.
List<Map<String, Object?>> asRows(Object? value, {List<String> keys = const []}) {
  if (value is List) return _rows(value);
  if (value is Map) {
    for (final String key in <String>[...keys, 'data', 'items', 'results']) {
      final Object? nested = value[key];
      if (nested is List) return _rows(nested);
    }
    // One endpoint answers `{success: true, data: {parent_companies: […]}}`.
    final Object? data = value['data'];
    if (data is Map) return asRows(data, keys: keys);
  }
  return const <Map<String, Object?>>[];
}

List<Map<String, Object?>> _rows(List<Object?> list) => list
    .whereType<Map<Object?, Object?>>()
    .map((Map<Object?, Object?> row) => row.cast<String, Object?>())
    .toList(growable: false);

/// The first non-empty string among [keys], trimmed. Null when none of them
/// carry text — an empty string counts as absent, because the backend uses
/// `""` and `null` interchangeably for "not filled in".
String? readString(Map<String, Object?> row, List<String> keys) {
  for (final String key in keys) {
    final Object? value = row[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return '$value';
  }
  return null;
}

/// The first parsable integer among [keys].
int? readInt(Map<String, Object?> row, List<String> keys) {
  for (final String key in keys) {
    final Object? value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final int? parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

/// The first parsable timestamp among [keys], as local time.
///
/// The backend sends naive ISO strings (no zone) that are in fact UTC, so a
/// value without an offset is read as UTC before being localised — otherwise
/// every "4 saat əvvəl" is wrong by the device's offset.
DateTime? readDate(Map<String, Object?> row, List<String> keys) {
  for (final String key in keys) {
    final Object? value = row[key];
    if (value is! String || value.trim().isEmpty) continue;
    final String text = value.trim();
    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed == null) continue;
    final bool hasZone = text.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    return hasZone
        ? parsed.toLocal()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
          ).toLocal();
  }
  return null;
}

/// Whether a record should be treated as live.
///
/// Only an explicit negative counts: a row that says nothing about its state
/// is kept, matching how the web dashboard filters its employee list.
bool isActiveRow(Map<String, Object?> row) {
  bool? flag(String key) {
    final Object? value = row[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String text = value.toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return null;
  }

  if (flag('is_active') == false) return false;
  if (flag('active') == false) return false;
  if (flag('is_deleted') == true) return false;
  if (flag('is_archived') == true) return false;
  if (row['deleted_at'] is String &&
      (row['deleted_at'] as String).trim().isNotEmpty) {
    return false;
  }

  final Object? status = row['status'];
  if (status is String && status.trim().isNotEmpty) {
    const Set<String> dead = <String>{
      'inactive',
      'deactivated',
      'blocked',
      'rejected',
      'deleted',
    };
    if (dead.contains(status.toLowerCase())) return false;
  }
  return true;
}
