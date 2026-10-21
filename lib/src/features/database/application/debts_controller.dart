import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/debt.dart';
import '../domain/debts_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'debts_filter_values.dart';

/// How many rows one request asks for: the other lists' page. Twenty debts
/// are ~6.7 KB of JSON (measured 2026-10-20).
const int kDebtsPageSize = 20;

/// The largest page read when the whole list is wanted at once
/// ([DebtsController.readAll]): the bridge's own ceiling. Either list was
/// one request at this size on 2026-10-20 — 88 and 120 rows.
const int kDebtsReadAllPageMax = 500;

/// How many filtered answers are kept, with the rows read for them, for
/// when the filter comes back to one.
const int kDebtsFeedMemory = 8;

/// The amounts' fields: the debt's by whichever name its card gives it, and
/// the settlement's.
const Map<DebtsColumn, FilterRangeField> kDebtsRangeFields =
    <DebtsColumn, FilterRangeField>{
      DebtsColumn.debt: FilterRangeField(
        minHint: 'Min borc',
        maxHint: 'Maks borc',
        suffix: '₼',
      ),
      DebtsColumn.ourDebt: FilterRangeField(
        minHint: 'Min borc',
        maxHint: 'Maks borc',
        suffix: '₼',
      ),
      DebtsColumn.settlement: FilterRangeField(
        minHint: 'Min hesablaşma',
        maxHint: 'Maks hesablaşma',
        suffix: '₼',
      ),
    };

/// Drives `Kreditorlar` or `Debitorlar` — [kind] says which: the rows loaded
/// so far, the next page, and the filter. A card does not open (the user,
/// 2026-10-20: the card is the whole of it), so there is nothing to ask for
/// one row on its own.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge what its `search` can find — a counterparty, a contract —
/// and checks everything else against the rows read. Either list is small,
/// so the first time a column whose values can only be known by reading all
/// of it opens (`Təşkilat`, `Müqavilə`), the rest is read into the list's
/// own pages ([readAll]); from then on every value is listed and every
/// filter is answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class DebtsController extends DatabaseListController<Debt>
    implements DatabaseRangeFilterSource {
  /// [pageSize] is the seam the tests reach through.
  DebtsController(this._api, this.kind, {int pageSize = kDebtsPageSize})
    : super(_fetchFor(_api, kind), idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  /// Which of the two lists this is.
  final DebtKind kind;

  static Object _idOf(Debt debt) => debt.id;

  static DatabasePageFetch<Debt> _fetchFor(DatabaseApi api, DebtKind kind) =>
      ({required int page, required int pageSize, String? search}) =>
          api.debtsPage(kind, page: page, pageSize: pageSize, search: search);

  /// The bridge asked for this list's rows.
  DatabasePageFetch<Debt> get fetch => _fetchFor(_api, kind);

  /// Every row loaded so far, in the bridge's order.
  List<Debt> get debts => rows;

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

  /// True while the rest of the list is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the list stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every row is on the phone: the list's own pages reach its end.
  bool get hasEveryone => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the list into its own pages, as large as a page goes,
  /// so that a filter column can list every value it has.
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
        await base.next(kDebtsReadAllPageMax);
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

  DebtsFilter _filter = DebtsFilter.none;

  /// What the list is narrowed to.
  DebtsFilter get filter => _filter;

  DebtsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every row.
  @override
  DebtsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<Debt>> _feeds =
      LinkedHashMap<String, DatabaseFeed<Debt>>();

  int _rowsStamp = 0;

  /// Bumped whenever rows arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every row on the phone: the list's, and every filtered answer's. The
  /// values a filter column offers are theirs.
  Iterable<Debt> get knownDebts sync* {
    yield* base.rows;
    for (final DatabaseFeed<Debt> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  DebtsFilterValues? _values;

  /// The values each filter column offers.
  DebtsFilterValues get values => _values ??= DebtsFilterValues(this);

  @override
  List<DebtsColumn> get filterColumns => DebtsColumn.of(kind);

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(DebtsColumn column) => _filter.has(column);

  @override
  bool isChosen(DebtsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  DebtsFilterValues get filterValues => values;

  @override
  FilterRangeField? rangeFieldOf(DebtsColumn column) =>
      kDebtsRangeFields[column];

  @override
  FilterRange rangeOf(DebtsColumn column) => _filter.rangeOf(column);

  @override
  Future<void> setRange(DebtsColumn column, FilterRange range) =>
      setFilter(_filter.withRange(column, range));

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(DebtsFilter next) {
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
  Future<void> toggleFilter(DebtsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(DebtsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(DebtsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final DebtsFilterView view = DebtsFilterView._(
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
  DatabaseFeed<Debt> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<Debt> feed =
        _feeds.remove(key) ??
        DatabaseFeed<Debt>(
          fetch,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kDebtsFeedMemory) {
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
/// counterparty or the contract — so the most telling of those that is
/// chosen goes to it, and is checked exactly here as well. Everything else —
/// the organisation, an amount, the status — is checked against each row
/// read, a page at a time as the list asks for more, the page growing while
/// matches are few.
class DebtsFilterView implements DatabaseFilteredRows<Debt> {
  DebtsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final DebtsController _owner;

  final DebtsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<Debt> _matches = <Debt>[];

  @override
  late final List<Debt> rows = UnmodifiableListView<Debt>(_matches);

  DatabaseFeed<Debt>? _feed;
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
    final DatabaseFeed<Debt>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final DebtsColumn? searched = filter.searchColumn;
    for (final DebtsColumn column in filter.columns) {
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
      final DebtsColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<Debt>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<Debt> all = feed.rows;
    while (_examined < all.length) {
      final Debt debt = all[_examined++];
      if (filter.matches(debt)) _matches.add(debt);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<Debt> feed = _feed!;
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
