import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/database_page.dart';

/// One request for one page of a bridge list: `page` counted from 1,
/// `page_size` rows, narrowed by the bridge's `search`.
typedef DatabasePageFetch<T> =
    Future<DatabasePage<T>> Function({
      required int page,
      required int pageSize,
      String? search,
    });

/// The largest page a scan asks for.
///
/// A filter the bridge cannot apply itself is applied on the phone, to every
/// row read, and one that matches little would read a list twenty at a time
/// for a minute. The bridge spends ~0.4 s on a sales request before its first
/// row and ~14 ms on each row after it (measured 2026-09-24), so a scan that
/// is finding little doubles its page up to this — 160 documents, ~170 KB,
/// ~2.6 s — rather than paying the 0.4 s eight times over. A stock row is a
/// third of the size and cheaper still, so the same cap keeps its pages
/// small.
const int kDatabaseScanPageMax = 160;

/// One question put to the bridge — every row one of its lists holds for
/// [search], in its order — read from [start] onwards, a page at a time.
///
/// The bridge pages by number, so a page of `n` rows can only start at a
/// multiple of `n`. Everything here is therefore counted in rows from the top
/// of the answer rather than in pages, and a page is only as large as the
/// place it starts at allows ([pageSizeFor]); starts are always a multiple of
/// [unit].
class DatabaseFeed<T> {
  DatabaseFeed(
    this._fetch, {
    required this.idOf,
    this.search,
    this.start = 0,
    required this.unit,
    this.onRows,
  }) : assert(start % unit == 0),
       _offset = start;

  final DatabasePageFetch<T> _fetch;

  /// What tells one row from another, whatever page it arrives on.
  final Object Function(T row) idOf;

  /// The bridge's `search`, or null for every row.
  final String? search;

  /// Where in the answer the first row held here sits.
  final int start;

  /// The smallest page, and the step every start is a multiple of.
  final int unit;

  /// Called whenever rows arrive or are replaced.
  final VoidCallback? onRows;

  final List<T> _rows = <T>[];
  final Set<Object> _ids = <Object>{};

  /// Every row read so far, in the bridge's order.
  late final List<T> rows = UnmodifiableListView<T>(_rows);

  int _offset;

  /// Where in the answer the next row to ask for sits.
  int get offset => _offset;

  int? _total;

  /// Rows in the whole answer, when the bridge says.
  int? get total => _total;

  bool _exhausted = false;

  /// Whether the last row of the answer has been read.
  bool get exhausted => _exhausted;

  int _epoch = 0;

  /// Bumped whenever [rows] are replaced rather than added to, so that
  /// whoever was reading them knows to start again.
  int get epoch => _epoch;

  /// Bumped by [restart]: an answer carrying an older number belongs to a
  /// question nobody is asking any more.
  int _generation = 0;

  bool _restarting = false;
  Future<List<T>>? _pending;

  bool get isLoading => _restarting || _pending != null;

  /// The largest page, up to [preferred], that starts exactly at [offset].
  int pageSizeFor(int preferred) {
    int size = unit;
    while (size * 2 <= preferred && _offset % (size * 2) == 0) {
      size *= 2;
    }
    return size;
  }

  /// Reads the next page — up to [size] rows — and hands back the rows it
  /// added.
  ///
  /// One request at a time, whoever asks: a second caller while a page is on
  /// its way is given that same page rather than a second request, because
  /// the bridge drops connections when it is asked several things at once.
  Future<List<T>> next(int size) {
    if (_exhausted || _restarting) return Future<List<T>>.value(<T>[]);
    return _pending ??= _next(size).whenComplete(() => _pending = null);
  }

  Future<List<T>> _next(int size) async {
    final int generation = _generation;
    final int pageSize = pageSizeFor(size);
    final DatabasePage<T> page = await _fetch(
      page: _offset ~/ pageSize + 1,
      pageSize: pageSize,
      search: search,
    );
    if (generation != _generation) return <T>[];

    final List<T> added = _take(page);
    _offset += page.received;
    _total = page.total ?? _total;
    _exhausted = _isEnd(page, pageSize);
    onRows?.call();
    return added;
  }

  /// Reads the answer again from [start]: its first page replaces every row
  /// held so far, once — and only if — it arrives.
  Future<void> restart() async {
    final int generation = ++_generation;
    _restarting = true;
    try {
      final DatabasePage<T> page = await _fetch(
        page: start ~/ unit + 1,
        pageSize: unit,
        search: search,
      );
      if (generation != _generation) return;

      _rows.clear();
      _ids.clear();
      _take(page);
      _offset = start + page.received;
      _total = page.total;
      _exhausted = _isEnd(page, unit);
      _epoch++;
      onRows?.call();
    } finally {
      if (generation == _generation) _restarting = false;
    }
  }

  /// Adds a page's rows, skipping any already held.
  ///
  /// 1C keeps syncing while a list is read, and every row that arrives in the
  /// meantime pushes the rest one place down, so the top of one page can be
  /// the bottom of the one before it again.
  List<T> _take(DatabasePage<T> page) {
    final List<T> added = <T>[];
    for (final T row in page.rows) {
      if (!_ids.add(idOf(row))) continue;
      _rows.add(row);
      added.add(row);
    }
    return added;
  }

  /// A short page is the last; so is one that reaches the `total`, which
  /// saves asking for an empty page to find out.
  bool _isEnd(DatabasePage<T> page, int pageSize) {
    if (page.received < pageSize) return true;
    final int? total = _total;
    return total != null && _offset >= total;
  }
}
