import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/unit_of_measure.dart';
import '../domain/units_of_measure_filter.dart';
import 'units_of_measure_filter_values.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';

/// How many units one request asks for: the other lists' page. The whole
/// catalogue was 32 units, 6.8 KB (read 2026-10-10).
const int kUnitsOfMeasurePageSize = 20;

/// The largest page read when the whole catalogue is wanted at once
/// ([UnitsOfMeasureController.readAll]): the bridge's own ceiling — one request
/// for any company's units.
const int kUnitsOfMeasureReadAllPageMax = 500;

/// How many filtered answers are kept, with the units read for them, for
/// when the filter comes back to one.
const int kUnitsOfMeasureFeedMemory = 8;

/// Drives `Ölçü Vahidləri`: the units loaded so far, the next page — and the
/// filter. A line does not open — there is nothing more to it than its three
/// fields, and the bridge has nothing to say about one unit on its own.
///
/// The paging is every `Baza` list's ([DatabaseListController]). The filter
/// asks the bridge what its `search` can find — a code, a name — and checks
/// everything else against the units read. The catalogue is small, so the
/// first time a column whose values can only be known by reading all of it
/// opens (`Beynəlxalq kod`), the rest is read into the list's own pages
/// ([readAll]); from then on every value is listed and every filter is
/// answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own place in the scroll, so letting go of it puts
/// the reader back exactly where they were.
class UnitsOfMeasureController extends DatabaseListController<UnitOfMeasure>
    implements DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  UnitsOfMeasureController(this._api, {int pageSize = kUnitsOfMeasurePageSize})
    : super(_api.unitsOfMeasurePage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(UnitOfMeasure unit) => unit.id;

  /// Every unit loaded so far, in the bridge's order — by name.
  List<UnitOfMeasure> get units => rows;

  /// A pull's page one has replaced the list: everything read for the
  /// filter is as old as the list just replaced.
  @override
  void didRestart() {
    _readAllError = null;
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Every unit ──────────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the catalogue is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the catalogue stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every unit is on the phone: the list's own pages reach the
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
        await base.next(kUnitsOfMeasureReadAllPageMax);
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

  UnitsOfMeasureFilter _filter = UnitsOfMeasureFilter.none;

  /// What the list is narrowed to.
  UnitsOfMeasureFilter get filter => _filter;

  UnitsOfMeasureFilterView? _view;

  /// The filtered list, while there is a filter; null shows every unit.
  @override
  UnitsOfMeasureFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<UnitOfMeasure>> _feeds =
      LinkedHashMap<String, DatabaseFeed<UnitOfMeasure>>();

  int _rowsStamp = 0;

  /// Bumped whenever units arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every unit on the phone: the list's, and every filtered answer's. The
  /// values a filter column offers are theirs.
  Iterable<UnitOfMeasure> get knownUnits sync* {
    yield* base.rows;
    for (final DatabaseFeed<UnitOfMeasure> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  UnitsOfMeasureFilterValues? _values;

  /// The values each filter column offers.
  UnitsOfMeasureFilterValues get values =>
      _values ??= UnitsOfMeasureFilterValues(this, _api);

  @override
  List<UnitsOfMeasureColumn> get filterColumns => UnitsOfMeasureColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(UnitsOfMeasureColumn column) => _filter.has(column);

  @override
  bool isChosen(UnitsOfMeasureColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  UnitsOfMeasureFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(UnitsOfMeasureFilter next) {
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
  Future<void> toggleFilter(UnitsOfMeasureColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(UnitsOfMeasureColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(UnitsOfMeasureFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final UnitsOfMeasureFilterView view = UnitsOfMeasureFilterView._(
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
  /// already hold every unit, or when the question is the list's own — no
  /// search. Not while they are on their way in again, and not for a pull,
  /// which wants nothing old.
  DatabaseFeed<UnitOfMeasure> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<UnitOfMeasure> feed =
        _feeds.remove(key) ??
        DatabaseFeed<UnitOfMeasure>(
          _api.unitsOfMeasurePage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kUnitsOfMeasureFeedMemory) {
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

/// The units a filter lets through, found in the whole catalogue.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// code or the name — so the more telling of those that is chosen goes to
/// it, and is checked exactly here as well. Everything else — the other of
/// the two, an international code — is checked against each unit read, a
/// page at a time as the list asks for more, the page growing while matches
/// are few.
class UnitsOfMeasureFilterView implements DatabaseFilteredRows<UnitOfMeasure> {
  UnitsOfMeasureFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final UnitsOfMeasureController _owner;

  final UnitsOfMeasureFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<UnitOfMeasure> _matches = <UnitOfMeasure>[];

  @override
  late final List<UnitOfMeasure> rows = UnmodifiableListView<UnitOfMeasure>(
    _matches,
  );

  DatabaseFeed<UnitOfMeasure>? _feed;
  int _epoch = -1;

  /// How many of the feed's units have been checked.
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
    final DatabaseFeed<UnitOfMeasure>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final UnitsOfMeasureColumn? searched = filter.searchColumn;
    for (final UnitsOfMeasureColumn column in filter.columns) {
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
      final UnitsOfMeasureColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<UnitOfMeasure>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<UnitOfMeasure> all = feed.rows;
    while (_examined < all.length) {
      final UnitOfMeasure unit = all[_examined++];
      if (filter.matches(unit)) _matches.add(unit);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<UnitOfMeasure> feed = _feed!;
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
