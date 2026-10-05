import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/stock_filter.dart';
import '../domain/stock_item.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'stock_filter_values.dart';

/// How many balances one request asks for.
///
/// Twenty stock rows are ~6 KB of JSON (measured 2026-09-25) and four or
/// five screens of the short stock cards, so the reader stays well ahead of
/// the bridge, which answers a page this size in ~0.12 s. The whole table is
/// 799 rows, ~244 KB, and nobody who reads the first screens pays for the
/// rest.
const int kStockPageSize = 20;

/// How many filtered answers are kept, with the rows read for them, for when
/// the filter comes back to one.
const int kStockFeedMemory = 8;

/// Drives `Stok`: the balances loaded so far, the next page — and the filter.
///
/// The paging is `Satışlar`' own ([DatabaseListController]): a page at a
/// time as the list nears its end, nothing again until a pull. A card has
/// nothing to open, so there is nothing else to fetch.
///
/// The filter never touches the list it narrows. It is a second list
/// ([filtered]) found in the whole of the table rather than in the pages read
/// so far, so letting go of it puts the reader back exactly where they were.
class StockController extends DatabaseListController<StockItem>
    implements DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  StockController(this._api, {int pageSize = kStockPageSize})
    : super(_api.stockPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(StockItem item) => item.id;

  /// Every balance loaded so far, in the bridge's order: the most of
  /// anything first.
  List<StockItem> get items => rows;

  // ── The filter ──────────────────────────────────────────────────────────

  StockFilter _filter = StockFilter.none;

  /// What the list is narrowed to.
  StockFilter get filter => _filter;

  StockFilterView? _view;

  @override
  StockFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<StockItem>> _feeds =
      LinkedHashMap<String, DatabaseFeed<StockItem>>();

  int _rowsStamp = 0;

  /// Bumped whenever rows arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every balance on the phone: the list's, and every filtered answer's.
  /// The values a filter column offers before anything is typed are theirs.
  Iterable<StockItem> get knownItems sync* {
    yield* rows;
    for (final DatabaseFeed<StockItem> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  StockFilterValues? _values;

  /// The values each filter column offers.
  StockFilterValues get values => _values ??= StockFilterValues(this, _api);

  @override
  List<StockColumn> get filterColumns => StockColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(StockColumn column) => _filter.has(column);

  @override
  bool isChosen(StockColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  StockFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(StockFilter next) {
    if (next == _filter) return _view?.ready ?? Future<void>.value();
    _filter = next;
    _view?._close();
    if (next.isEmpty) {
      _view = null;
      notify();
      return Future<void>.value();
    }
    return _replan(fresh: false);
  }

  @override
  Future<void> toggleFilter(StockColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(StockColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(StockFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final StockFilterView view = StockFilterView._(
      this,
      _filter,
      ++_viewSerial,
      fresh: fresh,
    );
    _view = view;
    view._ready = view._start();
    notify();
    return view._ready;
  }

  /// A pull on the filtered list: its answers are asked for again, and the
  /// list it narrows is left alone.
  Future<void> _refreshFiltered() {
    _forgetAnswers();
    return _replan(fresh: true);
  }

  void _forgetAnswers() {
    _feeds.clear();
    _rowsStamp++;
  }

  @override
  void didRestart() {
    // Every filtered answer is as old as the list just replaced.
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  @override
  void onRowsChanged() {
    _rowsStamp++;
    _view?._sync();
    super.onRowsChanged();
  }

  /// Tells the list that the filtered one has changed.
  void _changed() => notify();

  /// The answer to [search], kept or new.
  ///
  /// No search at all is the list's own question, so the list's own pages
  /// answer it — every row already read is checked for free, and every row
  /// read for the filter is one the list will not ask for again — unless
  /// they are on their way in again, or a pull wants nothing old.
  DatabaseFeed<StockItem> _feedFor(String? search, {required bool fresh}) {
    if (search == null && !fresh && hasLoaded && !isLoadingFirst) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<StockItem> feed =
        _feeds.remove(key) ??
        DatabaseFeed<StockItem>(
          _api.stockPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kStockFeedMemory) {
      _feeds.remove(_feeds.keys.first);
    }
    return feed;
  }

  @override
  void dispose() {
    _view?._close();
    _values?.dispose();
    super.dispose();
  }
}

/// The balances a filter lets through, found in the whole table.
///
/// The bridge narrows a stock answer by one thing only — `search`, a
/// substring of the code, the product or the warehouse — so:
///
/// * the most selective of those three that is chosen goes to the bridge as
///   `search` ([StockFilter.searchColumn]);
/// * everything else — and the searched column too, exactly rather than as
///   a substring — is checked against each row read, a page at a time as the
///   list asks for more, the page growing while matches are few;
/// * `10-dan çox` stops reading at the first balance of ten or less: the
///   bridge answers the most of anything first, so nothing after it can
///   match.
///
/// At its worst — a day or `10 və daha az` over every warehouse — that is
/// the whole table: 799 rows, eight requests, ~244 KB.
class StockFilterView implements DatabaseFilteredRows<StockItem> {
  StockFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final StockController _owner;

  final StockFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<StockItem> _matches = <StockItem>[];

  @override
  late final List<StockItem> rows = UnmodifiableListView<StockItem>(_matches);

  DatabaseFeed<StockItem>? _feed;
  int _epoch = -1;

  /// How many of the feed's rows have been checked.
  int _examined = 0;

  /// Reached a balance too small for `10-dan çox`: nothing after it can
  /// match.
  bool _pastEnd = false;

  int _scanSize;

  bool _planning = true;
  bool _loaded = false;
  bool _loadingMore = false;
  bool _closed = false;
  String? _error;
  String? _moreError;

  late Future<void> _ready;

  /// Completes once the first answer has settled.
  Future<void> get ready => _ready;

  @override
  bool get hasLoaded => _loaded;

  @override
  bool get isLoadingFirst => _planning;

  @override
  bool get isLoadingMore => _loadingMore;

  @override
  String? get error => _error;

  @override
  String? get moreError => _moreError;

  @override
  bool get hasMore {
    if (_planning) return true;
    final DatabaseFeed<StockItem>? feed = _feed;
    if (feed == null || _pastEnd) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final StockColumn? searched = filter.searchColumn;
    for (final StockColumn column in filter.columns) {
      if (column != searched) return true;
    }
    return false;
  }

  @override
  int get read => _examined;

  /// How many rows there are to check — unless `10-dan çox` will stop well
  /// short of them.
  @override
  int? get readOf {
    final int? total = _feed?.total;
    if (total == null || filter.level == StockLevel.plenty) return null;
    return total;
  }

  Future<void> _start() async {
    try {
      final StockColumn? searched = filter.searchColumn;
      final String? search = searched == null
          ? null
          : filter.valueOf(searched)!.trim();
      _feed = _owner._feedFor(search, fresh: fresh);
      _sync();
      if (_matches.isEmpty && hasMore) await _fetch();
    } on ApiException catch (error) {
      if (_closed) return;
      _error = error.message;
    } finally {
      if (!_closed) {
        _planning = false;
        _loaded = true;
        _owner._changed();
      }
    }
  }

  /// Checks whatever the feed has read since last time.
  void _sync() {
    final DatabaseFeed<StockItem>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
      _pastEnd = false;
    }

    final List<StockItem> all = feed.rows;
    final bool plentyOnly = filter.level == StockLevel.plenty;
    while (!_pastEnd && _examined < all.length) {
      final StockItem item = all[_examined];
      final double? quantity = item.quantity;
      // The bridge answers the most of anything first — not one inversion
      // in 799 rows (2026-09-25) — so the first small balance is where the
      // large ones end.
      if (plentyOnly && quantity != null && quantity <= kStockLowThreshold) {
        _pastEnd = true;
        return;
      }
      _examined++;
      if (filter.matches(item)) _matches.add(item);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<StockItem> feed = _feed!;
    final int found = _matches.length;
    final int read = _examined;
    await feed.next(_scanSize);
    if (_closed) return;
    _sync();

    // Few matches in what was just read: the next page is larger, since
    // most of what a request costs is the request.
    final int newlyRead = _examined - read;
    if (newlyRead > 0 && (_matches.length - found) * 2 < newlyRead) {
      _scanSize = math.min(_scanSize * 2, kDatabaseScanPageMax);
    }
  }

  @override
  Future<void> loadMore() async {
    if (_closed ||
        _planning ||
        _loadingMore ||
        _moreError != null ||
        _feed == null ||
        !hasMore) {
      return;
    }
    _loadingMore = true;
    _owner._changed();
    try {
      await _fetch();
    } on ApiException catch (error) {
      if (_closed) return;
      _moreError = error.message;
    } finally {
      if (!_closed) {
        _loadingMore = false;
        _owner._changed();
      }
    }
  }

  @override
  Future<void> retryMore() {
    _moreError = null;
    return loadMore();
  }

  /// A pull: the filter is asked again, from nothing.
  @override
  Future<void> refresh() => _owner._refreshFiltered();

  void _close() => _closed = true;
}
