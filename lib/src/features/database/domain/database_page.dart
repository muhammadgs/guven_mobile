import 'package:flutter/foundation.dart';

import '../../../core/json.dart';

/// One page of a list the 1C bridge answers as `{data: [...], total: N}` —
/// `Satışlar`' documents, `Stok`'s balances, and every list after them.
@immutable
class DatabasePage<T> {
  const DatabasePage({
    required this.rows,
    required this.received,
    required this.total,
  });

  /// [read] turns one row of the answer into a [T], or into null to leave it
  /// out — a row without the id that tells it from the next one.
  factory DatabasePage.fromJson(
    Object? payload,
    T? Function(Map<String, Object?> row) read,
  ) {
    final List<Map<String, Object?>> raw = asRows(payload);
    return DatabasePage<T>(
      rows: <T>[for (final Map<String, Object?> row in raw) ?read(row)],
      received: raw.length,
      total: readListTotal(payload),
    );
  }

  final List<T> rows;

  /// How many rows the page actually held, including any [rows] left out for
  /// having no id. A page shorter than was asked for is the last one, and
  /// that has to be judged on what the bridge sent, not on what was kept.
  final int received;

  /// Rows in the whole answer, when it says.
  final int? total;
}
