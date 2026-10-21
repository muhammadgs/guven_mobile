import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/manager_debt.dart';
import '../domain/manager_debts_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'manager_debts_filter_values.dart';

/// How many rows one request asks for: the other lists' page. The whole list
/// was 13 rows on 2026-10-21, so one page holds all of it.
const int kManagerDebtsPageSize = 20;

/// How many filtered answers are kept, with the rows read for them, for
/// when the filter comes back to one.
const int kManagerDebtsFeedMemory = 8;

/// The figures' fields.
const Map<ManagerDebtsColumn, FilterRangeField> kManagerDebtsRangeFields =
    <ManagerDebtsColumn, FilterRangeField>{
      ManagerDebtsColumn.orders: FilterRangeField(
        minHint: 'Min sifariş',
        maxHint: 'Maks sifariş',
      ),
      ManagerDebtsColumn.sales: FilterRangeField(
        minHint: 'Min satış',
        maxHint: 'Maks satış',
        suffix: '₼',
      ),
      ManagerDebtsColumn.debt: FilterRangeField(
        minHint: 'Min debet',
        maxHint: 'Maks debet',
        suffix: '₼',
      ),
      ManagerDebtsColumn.collected: FilterRangeField(
        minHint: 'Min yığılmış',
        maxHint: 'Maks yığılmış',
        suffix: '₼',
      ),
      ManagerDebtsColumn.share: FilterRangeField(
        minHint: 'Min faiz',
        maxHint: 'Maks faiz',
        suffix: '%',
      ),
    };

/// Drives `Menecer Borcları`: the rows loaded so far, the next page, and the
/// filter. A card does not open — there is nothing more to ask for one row.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge for a manager — its `search` finds nothing else — and
/// checks every figure against the rows read.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class ManagerDebtsController extends DatabaseListController<ManagerDebt>
    implements DatabaseRangeFilterSource {
  /// [pageSize] is the seam the tests reach through.
  ManagerDebtsController(this._api, {int pageSize = kManagerDebtsPageSize})
    : super(_api.managerDebtsPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(ManagerDebt row) => row.id;

  /// The bridge asked for this list's rows.
  DatabasePageFetch<ManagerDebt> get fetch => _api.managerDebtsPage;

  /// Every row loaded so far, in the bridge's order.
  List<ManagerDebt> get managerDebts => rows;

  /// Whether every row is on the phone: the list's own pages reach its end.
  bool get hasEveryone => hasLoaded && !isLoadingFirst && base.exhausted;

  /// A pull's page one has replaced the list: everything read for the
  /// filter is as old as the list just replaced.
  @override
  void didRestart() {
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── The filter ──────────────────────────────────────────────────────────

  ManagerDebtsFilter _filter = ManagerDebtsFilter.none;

  /// What the list is narrowed to.
  ManagerDebtsFilter get filter => _filter;

  ManagerDebtsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every row.
  @override
  ManagerDebtsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<ManagerDebt>> _feeds =
      LinkedHashMap<String, DatabaseFeed<ManagerDebt>>();

  int _rowsStamp = 0;

  /// Bumped whenever rows arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every row on the phone: the list's, and every filtered answer's. The
  /// names `Menecer` offers are theirs.
  Iterable<ManagerDebt> get knownRows sync* {
    yield* base.rows;
    for (final DatabaseFeed<ManagerDebt> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  ManagerDebtsFilterValues? _values;

  /// The values each filter column offers.
  ManagerDebtsFilterValues get values =>
      _values ??= ManagerDebtsFilterValues(this);

  @override
  List<ManagerDebtsColumn> get filterColumns => ManagerDebtsColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(ManagerDebtsColumn column) => _filter.has(column);

  @override
  bool isChosen(ManagerDebtsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  ManagerDebtsFilterValues get filterValues => values;

  @override
  FilterRangeField? rangeFieldOf(ManagerDebtsColumn column) =>
      kManagerDebtsRangeFields[column];

  @override
  FilterRange rangeOf(ManagerDebtsColumn column) => _filter.rangeOf(column);

  @override
  Future<void> setRange(ManagerDebtsColumn column, FilterRange range) =>
      setFilter(_filter.withRange(column, range));

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(ManagerDebtsFilter next) {
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
  Future<void> toggleFilter(ManagerDebtsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(ManagerDebtsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(ManagerDebtsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final ManagerDebtsFilterView view = ManagerDebtsFilterView._(
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
  DatabaseFeed<ManagerDebt> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<ManagerDebt> feed =
        _feeds.remove(key) ??
        DatabaseFeed<ManagerDebt>(
          fetch,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kManagerDebtsFeedMemory) {
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

/// The rows a filter lets through, found in the whole list.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// manager's name — so a chosen manager goes to it, and is checked exactly
/// here as well. Every figure is checked against each row read, a page at a
/// time as the list asks for more, the page growing while matches are few.
class ManagerDebtsFilterView implements DatabaseFilteredRows<ManagerDebt> {
  ManagerDebtsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final ManagerDebtsController _owner;

  final ManagerDebtsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<ManagerDebt> _matches = <ManagerDebt>[];

  @override
  late final List<ManagerDebt> rows = UnmodifiableListView<ManagerDebt>(
    _matches,
  );

  DatabaseFeed<ManagerDebt>? _feed;
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
    final DatabaseFeed<ManagerDebt>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final ManagerDebtsColumn? searched = filter.searchColumn;
    for (final ManagerDebtsColumn column in filter.columns) {
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
      final ManagerDebtsColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<ManagerDebt>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<ManagerDebt> all = feed.rows;
    while (_examined < all.length) {
      final ManagerDebt row = all[_examined++];
      if (filter.matches(row)) _matches.add(row);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<ManagerDebt> feed = _feed!;
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
