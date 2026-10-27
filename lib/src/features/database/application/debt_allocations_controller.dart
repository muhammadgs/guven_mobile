import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/debt_allocation.dart';
import '../domain/debt_allocations_filter.dart';
import '../domain/manager_debt.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'debt_allocations_filter_values.dart';

/// How many rows one request asks for: the other lists' page. Twenty rows
/// are ~7 KB of JSON; the whole table was 5,989 rows and 2 MB on
/// 2026-10-22, so it is read a page at a time like `Satışlar`.
const int kDebtAllocationsPageSize = 20;

/// How many filtered answers are kept, with the rows read for them, for
/// when the filter comes back to one.
const int kDebtAllocationsFeedMemory = 8;

/// The amount's fields.
const FilterRangeField kDebtAllocationsShareField = FilterRangeField(
  minHint: 'Min bölgü',
  maxHint: 'Maks bölgü',
  suffix: '₼',
);

/// Drives `Borc Bölgüsü`: the rows loaded so far, the next page, and the
/// filter. A card does not open — there is nothing more to ask for one row.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge for a manager — its `search` finds nothing else worth
/// asking — and checks the months and the amounts against the rows read, a
/// page at a time as the list asks for more. The bridge gives the largest
/// amount first, so a minimum amount ends the reading at the first row
/// under it ([DebtAllocationsFilter.endsAt]).
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class DebtAllocationsController extends DatabaseListController<DebtAllocation>
    implements DatabaseRangeFilterSource, DatabasePeriodFilterSource {
  /// [pageSize] is the seam the tests reach through.
  DebtAllocationsController(
    this._api, {
    int pageSize = kDebtAllocationsPageSize,
  }) : super(_api.debtAllocationsPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(DebtAllocation row) => row.id;

  /// The bridge asked for this list's rows.
  DatabasePageFetch<DebtAllocation> get fetch => _api.debtAllocationsPage;

  /// Every manager with a share, from `Menecer Borcları`' rows — one small
  /// request, where the shares themselves are thousands — the most
  /// collected first.
  Future<List<ManagerDebt>> managers() async {
    final List<ManagerDebt> rows = <ManagerDebt>[
      ...(await _api.managerDebtsPage(page: 1, pageSize: 500)).rows,
    ];
    rows.sort(
      (ManagerDebt a, ManagerDebt b) =>
          (b.collected ?? 0).compareTo(a.collected ?? 0),
    );
    return rows;
  }

  /// Every row loaded so far, in the bridge's order.
  List<DebtAllocation> get allocations => rows;

  /// A pull's page one has replaced the list: everything read for the
  /// filter is as old as the list just replaced.
  @override
  void didRestart() {
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── The filter ──────────────────────────────────────────────────────────

  DebtAllocationsFilter _filter = DebtAllocationsFilter.none;

  /// What the list is narrowed to.
  DebtAllocationsFilter get filter => _filter;

  DebtAllocationsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every row.
  @override
  DebtAllocationsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<DebtAllocation>> _feeds =
      LinkedHashMap<String, DatabaseFeed<DebtAllocation>>();

  int _rowsStamp = 0;

  /// Bumped whenever rows arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every row on the phone: the list's, and every filtered answer's.
  Iterable<DebtAllocation> get knownRows sync* {
    yield* base.rows;
    for (final DatabaseFeed<DebtAllocation> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  DebtAllocationsFilterValues? _values;

  /// The values each filter column offers.
  DebtAllocationsFilterValues get values =>
      _values ??= DebtAllocationsFilterValues(this);

  @override
  List<DebtAllocationsColumn> get filterColumns => DebtAllocationsColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(DebtAllocationsColumn column) => _filter.has(column);

  @override
  bool isChosen(DebtAllocationsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  DebtAllocationsFilterValues get filterValues => values;

  @override
  FilterRangeField? rangeFieldOf(DebtAllocationsColumn column) =>
      column.takesRange ? kDebtAllocationsShareField : null;

  @override
  FilterRange rangeOf(DebtAllocationsColumn column) =>
      column.takesRange ? _filter.share : FilterRange.any;

  @override
  Future<void> setRange(DebtAllocationsColumn column, FilterRange range) =>
      column.takesRange
      ? setFilter(_filter.withShare(range))
      : Future<void>.value();

  @override
  bool takesPeriod(DebtAllocationsColumn column) => column.takesPeriod;

  @override
  FilterPeriod periodOf(DebtAllocationsColumn column) =>
      column.takesPeriod ? _filter.period : FilterPeriod.any;

  @override
  Future<void> setPeriod(DebtAllocationsColumn column, FilterPeriod period) =>
      column.takesPeriod
      ? setFilter(_filter.withPeriod(period))
      : Future<void>.value();

  int _monthsStamp = -1;
  Set<FilterMonth> _months = const <FilterMonth>{};

  /// The months of the sales on the phone. The table runs by amount, not by
  /// date, so what is on the phone is all that can be known without reading
  /// every row — and the calendar takes any month, marked or not.
  @override
  Set<FilterMonth> periodMonthsOf(DebtAllocationsColumn column) {
    if (!column.takesPeriod) return const <FilterMonth>{};
    if (_monthsStamp != _rowsStamp) {
      _monthsStamp = _rowsStamp;
      _months = Set<FilterMonth>.unmodifiable(<FilterMonth>{
        for (final DebtAllocation row in knownRows) ?row.month,
      });
    }
    return _months;
  }

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(DebtAllocationsFilter next) {
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
  Future<void> toggleFilter(DebtAllocationsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(DebtAllocationsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(DebtAllocationsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final DebtAllocationsFilterView view = DebtAllocationsFilterView._(
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
  DatabaseFeed<DebtAllocation> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<DebtAllocation> feed =
        _feeds.remove(key) ??
        DatabaseFeed<DebtAllocation>(
          fetch,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kDebtAllocationsFeedMemory) {
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
/// The bridge narrows an answer one way only — `search` — so a chosen
/// manager goes to it, and is checked exactly here as well (`Mühasib` also
/// finds `Mühasib-istehsal`). The months and the amounts are checked
/// against each row read, a page at a time as the list asks for more, the
/// page growing while matches are few — and the reading stops at the first
/// amount under the span's minimum, everything after it being smaller.
class DebtAllocationsFilterView
    implements DatabaseFilteredRows<DebtAllocation> {
  DebtAllocationsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final DebtAllocationsController _owner;

  final DebtAllocationsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<DebtAllocation> _matches = <DebtAllocation>[];

  @override
  late final List<DebtAllocation> rows = UnmodifiableListView<DebtAllocation>(
    _matches,
  );

  DatabaseFeed<DebtAllocation>? _feed;
  int _epoch = -1;

  /// How many of the feed's rows have been checked.
  int _examined = 0;

  /// Whether a row under the span's minimum has been read: nothing after it
  /// can match.
  bool _ended = false;

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
    if (_ended) return false;
    final DatabaseFeed<DebtAllocation>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans => filter.period.isNotEmpty || filter.share.isNotEmpty;

  @override
  int get read => _examined;

  @override
  int? get readOf => _feed?.total;

  Future<void> _start() async {
    try {
      final String? search = filter.manager?.trim();
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
    final DatabaseFeed<DebtAllocation>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _ended = false;
      _matches.clear();
    }

    final List<DebtAllocation> all = feed.rows;
    while (!_ended && _examined < all.length) {
      final DebtAllocation row = all[_examined++];
      if (filter.matches(row)) {
        _matches.add(row);
      } else if (filter.endsAt(row)) {
        _ended = true;
      }
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<DebtAllocation> feed = _feed!;
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
