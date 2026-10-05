import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/manager_stat.dart';
import '../domain/manager_stats_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'manager_stats_filter_values.dart';

/// How many rows one request asks for: the other lists' page. Twenty rows
/// are ~7 KB of JSON (the whole 34 were ~12 KB on 2026-10-05).
const int kManagerStatsPageSize = 20;

/// The largest page read when every row is wanted at once
/// ([ManagerStatsController.readAll]): the bridge's own ceiling. There were
/// 34 rows on 2026-10-05, and a month adds a row a manager — one request at
/// this size for years to come.
const int kManagerStatsReadAllPageMax = 500;

/// How many filtered answers are kept, with the rows read for them, for when
/// the filter comes back to one.
const int kManagerStatsFeedMemory = 8;

/// The figures' fields.
const Map<ManagerStatsColumn, FilterRangeField> kManagerStatsRangeFields =
    <ManagerStatsColumn, FilterRangeField>{
      ManagerStatsColumn.orders: FilterRangeField(
        minHint: 'Min sifariş',
        maxHint: 'Maks sifariş',
      ),
      ManagerStatsColumn.amount: FilterRangeField(
        minHint: 'Min məbləğ',
        maxHint: 'Maks məbləğ',
        suffix: '₼',
      ),
    };

/// Drives `Menecer statistikası`: the rows loaded so far, the next page —
/// and the filter. A card does not open (the user, 2026-10-05: there is
/// too little on it to open onto), so nothing is asked for one row on its
/// own.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge what its `search` can find — a manager — and checks
/// everything else against the rows read: the period, the number of orders
/// and the amount. The table is small, so the first time a column whose
/// values can only be known by reading all of it opens (`Menecer`, `Dövr`),
/// the rest is read into the list's own pages ([readAll]); from then on
/// every manager is listed, every month with figures is marked, and every
/// filter is answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class ManagerStatsController extends DatabaseListController<ManagerStat>
    implements DatabaseRangeFilterSource, DatabasePeriodFilterSource {
  /// [pageSize] is the seam the tests reach through.
  ManagerStatsController(this._api, {int pageSize = kManagerStatsPageSize})
    : super(_api.managerStatsPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(ManagerStat stat) => stat.id;

  /// Every row loaded so far, in the bridge's order.
  List<ManagerStat> get stats => rows;

  /// A pull's page one has replaced the list: everything read for the
  /// filter is as old as the list just replaced.
  @override
  void didRestart() {
    _readAllError = null;
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Everything ──────────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the table is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the table stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every row is on the phone: the list's own pages reach its end.
  bool get hasEveryone => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the table into the list's own pages, as large as a
  /// page goes, so that a filter column can offer every value it has.
  ///
  /// The rows read are the list's own — nothing is read twice, and the list
  /// then scrolls to its end without asking again. Stops where a pull starts
  /// the list over.
  Future<void> readAll() async {
    if (_readingAll || hasEveryone) return;
    _readingAll = true;
    _readAllError = null;
    notify();

    int asked = generation;
    try {
      await ensureLoaded();
      asked = generation;
      while (!isDisposed &&
          asked == generation &&
          !isLoadingFirst &&
          !base.exhausted) {
        final int before = base.offset;
        await base.next(kManagerStatsReadAllPageMax);
        // A page that moved nothing on belongs to a list being started over.
        if (base.offset == before && !base.exhausted) break;
      }
    } on ApiException catch (error) {
      if (asked == generation) _readAllError = error.message;
    } finally {
      _readingAll = false;
      notify();
    }
  }

  // ── The filter ──────────────────────────────────────────────────────────

  ManagerStatsFilter _filter = ManagerStatsFilter.none;

  /// What the list is narrowed to.
  ManagerStatsFilter get filter => _filter;

  ManagerStatsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every row.
  @override
  ManagerStatsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<ManagerStat>> _feeds =
      LinkedHashMap<String, DatabaseFeed<ManagerStat>>();

  int _rowsStamp = 0;

  /// Bumped whenever rows arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every row on the phone: the list's, and every filtered answer's. The
  /// values a filter column offers are theirs.
  Iterable<ManagerStat> get knownStats sync* {
    yield* base.rows;
    for (final DatabaseFeed<ManagerStat> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  ManagerStatsFilterValues? _values;

  /// The values each filter column offers.
  ManagerStatsFilterValues get values =>
      _values ??= ManagerStatsFilterValues(this);

  @override
  List<ManagerStatsColumn> get filterColumns => ManagerStatsColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(ManagerStatsColumn column) => _filter.has(column);

  @override
  bool isChosen(ManagerStatsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  ManagerStatsFilterValues get filterValues => values;

  @override
  FilterRangeField? rangeFieldOf(ManagerStatsColumn column) =>
      kManagerStatsRangeFields[column];

  @override
  FilterRange rangeOf(ManagerStatsColumn column) => _filter.rangeOf(column);

  @override
  Future<void> setRange(ManagerStatsColumn column, FilterRange range) =>
      setFilter(_filter.withRange(column, range));

  @override
  bool takesPeriod(ManagerStatsColumn column) => column.takesPeriod;

  @override
  FilterPeriod periodOf(ManagerStatsColumn column) =>
      column.takesPeriod ? _filter.period : FilterPeriod.any;

  @override
  Future<void> setPeriod(ManagerStatsColumn column, FilterPeriod period) =>
      column.takesPeriod
      ? setFilter(_filter.withPeriod(period))
      : Future<void>.value();

  int _monthsStamp = -1;
  Set<FilterMonth> _months = const <FilterMonth>{};

  @override
  Set<FilterMonth> periodMonthsOf(ManagerStatsColumn column) {
    if (!column.takesPeriod) return const <FilterMonth>{};
    if (_monthsStamp != _rowsStamp) {
      _monthsStamp = _rowsStamp;
      _months = Set<FilterMonth>.unmodifiable(<FilterMonth>{
        for (final ManagerStat stat in knownStats) ?stat.period,
      });
    }
    return _months;
  }

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(ManagerStatsFilter next) {
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
  Future<void> toggleFilter(ManagerStatsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(ManagerStatsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(ManagerStatsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final ManagerStatsFilterView view = ManagerStatsFilterView._(
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
  void onRowsChanged() {
    _rowsStamp++;
    _view?._sync();
    super.onRowsChanged();
  }

  /// Tells the list that the filtered one has changed.
  void _changed() => notify();

  /// The answer to [search], kept or new.
  ///
  /// The list's own pages answer it instead whenever they can: when they
  /// already hold every row, or when the question is the list's own — no
  /// search. Not while they are on their way in again, and not for a pull,
  /// which wants nothing old.
  DatabaseFeed<ManagerStat> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<ManagerStat> feed =
        _feeds.remove(key) ??
        DatabaseFeed<ManagerStat>(
          _api.managerStatsPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kManagerStatsFeedMemory) {
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

/// The rows a filter lets through, found in the whole table.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// manager's name — so a chosen manager goes to it, and is checked exactly
/// here as well. Everything else — a period, a figure — is checked against
/// each row read, a page at a time as the list asks for more, the page
/// growing while matches are few.
class ManagerStatsFilterView implements DatabaseFilteredRows<ManagerStat> {
  ManagerStatsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final ManagerStatsController _owner;

  final ManagerStatsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<ManagerStat> _matches = <ManagerStat>[];

  @override
  late final List<ManagerStat> rows = UnmodifiableListView<ManagerStat>(
    _matches,
  );

  DatabaseFeed<ManagerStat>? _feed;
  int _epoch = -1;

  /// How many of the feed's rows have been checked.
  int _examined = 0;

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
    final DatabaseFeed<ManagerStat>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final ManagerStatsColumn? searched = filter.searchColumn;
    for (final ManagerStatsColumn column in filter.columns) {
      if (column != searched) return true;
    }
    return false;
  }

  @override
  int get read => _examined;

  @override
  int? get readOf => _feed?.total;

  Future<void> _start() async {
    try {
      final ManagerStatsColumn? searched = filter.searchColumn;
      final String? search = searched == null
          ? null
          : filter.valueOf(searched)!.trim();
      _feed = _owner._feedFor(
        search == null || search.isEmpty ? null : search,
        fresh: fresh,
      );
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
    final DatabaseFeed<ManagerStat>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<ManagerStat> all = feed.rows;
    while (_examined < all.length) {
      final ManagerStat stat = all[_examined++];
      if (filter.matches(stat)) _matches.add(stat);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<ManagerStat> feed = _feed!;
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
