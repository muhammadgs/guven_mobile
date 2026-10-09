import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/cash_desk.dart';
import '../domain/cash_desks_filter.dart';
import 'cash_desks_filter_values.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';

/// How many desks one request asks for: the other lists' page. The whole
/// catalogue was three desks, 746 bytes (read 2026-10-05).
const int kCashDesksPageSize = 20;

/// The largest page read when the whole catalogue is wanted at once
/// ([CashDesksController.readAll]): the bridge's own ceiling — one request
/// for any company's tills.
const int kCashDesksReadAllPageMax = 500;

/// How many filtered answers are kept, with the desks read for them, for
/// when the filter comes back to one.
const int kCashDesksFeedMemory = 8;

/// Drives `Kassalar`: the desks loaded so far, the next page — and the
/// filter. A card does not open (the user, 2026-10-05: there is too little
/// on it to open onto), so there is nothing to ask for one desk on its own.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge what its `search` can find — a code, a name — and checks
/// everything else against the desks read. The catalogue is small, so the
/// first time a column whose values can only be known by reading all of it
/// opens (`Valyuta`), the rest is read into the list's own pages
/// ([readAll]); from then on every value is listed and every filter is
/// answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class CashDesksController extends DatabaseListController<CashDesk>
    implements DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  CashDesksController(this._api, {int pageSize = kCashDesksPageSize})
    : super(_api.cashDesksPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(CashDesk desk) => desk.id;

  /// Every desk loaded so far, in the bridge's order — the newest first.
  List<CashDesk> get desks => rows;

  /// A pull's page one has replaced the list: everything read for the
  /// filter is as old as the list just replaced.
  @override
  void didRestart() {
    _readAllError = null;
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Every desk ──────────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the catalogue is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the catalogue stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every desk is on the phone: the list's own pages reach the
  /// catalogue's end.
  bool get hasEveryone => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the catalogue into the list's own pages, as large as
  /// a page goes, so that a filter column can list every value it has.
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
        await base.next(kCashDesksReadAllPageMax);
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

  CashDesksFilter _filter = CashDesksFilter.none;

  /// What the list is narrowed to.
  CashDesksFilter get filter => _filter;

  CashDesksFilterView? _view;

  /// The filtered list, while there is a filter; null shows every desk.
  @override
  CashDesksFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<CashDesk>> _feeds =
      LinkedHashMap<String, DatabaseFeed<CashDesk>>();

  int _rowsStamp = 0;

  /// Bumped whenever desks arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every desk on the phone: the list's, and every filtered answer's. The
  /// values a filter column offers are theirs.
  Iterable<CashDesk> get knownDesks sync* {
    yield* base.rows;
    for (final DatabaseFeed<CashDesk> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  CashDesksFilterValues? _values;

  /// The values each filter column offers.
  CashDesksFilterValues get values =>
      _values ??= CashDesksFilterValues(this, _api);

  @override
  List<CashDesksColumn> get filterColumns => CashDesksColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(CashDesksColumn column) => _filter.has(column);

  @override
  bool isChosen(CashDesksColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  CashDesksFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(CashDesksFilter next) {
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
  Future<void> toggleFilter(CashDesksColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(CashDesksColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(CashDesksFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final CashDesksFilterView view = CashDesksFilterView._(
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
  /// already hold every desk, or when the question is the list's own — no
  /// search. Not while they are on their way in again, and not for a pull,
  /// which wants nothing old.
  DatabaseFeed<CashDesk> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<CashDesk> feed =
        _feeds.remove(key) ??
        DatabaseFeed<CashDesk>(
          _api.cashDesksPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kCashDesksFeedMemory) {
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

/// The desks a filter lets through, found in the whole catalogue.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// code or the name — so the more telling of those that is chosen goes to
/// it, and is checked exactly here as well. Everything else — a currency, a
/// status — is checked against each desk read, a page at a time as the list
/// asks for more, the page growing while matches are few.
class CashDesksFilterView implements DatabaseFilteredRows<CashDesk> {
  CashDesksFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final CashDesksController _owner;

  final CashDesksFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<CashDesk> _matches = <CashDesk>[];

  @override
  late final List<CashDesk> rows = UnmodifiableListView<CashDesk>(_matches);

  DatabaseFeed<CashDesk>? _feed;
  int _epoch = -1;

  /// How many of the feed's desks have been checked.
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
    final DatabaseFeed<CashDesk>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final CashDesksColumn? searched = filter.searchColumn;
    for (final CashDesksColumn column in filter.columns) {
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
      final CashDesksColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<CashDesk>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<CashDesk> all = feed.rows;
    while (_examined < all.length) {
      final CashDesk desk = all[_examined++];
      if (filter.matches(desk)) _matches.add(desk);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<CashDesk> feed = _feed!;
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
