import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_page.dart';
import '../domain/sale.dart';
import '../domain/sales_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'sales_filter_values.dart';

/// How many documents one request asks for.
///
/// About four screens of cards. Measured against the live bridge on
/// 2026-09-24: 19–23 KB of JSON a page, product lines included, because the
/// bridge does not compress its answers — the same page gzipped is under
/// 3 KB. Smaller pages save nothing worth having — a few kilobytes on the
/// last page somebody does not read to the end of — and cost a request, and
/// a wake of the phone's radio, every screen or two. Larger ones start to
/// download pages nobody scrolls to.
const int kSalesPageSize = 20;

/// How many opened documents are remembered. Past this the oldest is
/// forgotten and asked for again should it be opened again.
const int kSaleDocumentMemory = 150;

/// A filtered answer this short is read to its end rather than sought in: a
/// seek would spend more requests finding its place than reading it takes.
const int kSalesSeekThreshold = kDatabaseScanPageMax;

/// How many one-row requests a seek may spend before settling for where it
/// has got to. Bisection alone takes thirteen through 7,547 documents; the
/// dates usually lead there in four or five.
const int kSalesSeekProbes = 16;

/// How many filtered answers are kept, with the documents read for them, for
/// when the filter comes back to one.
const int kSalesFeedMemory = 8;

/// A list of sale cards — every document, or only the ones a filter lets
/// through — whose cards open, each list its own.
abstract interface class SalesRows implements DatabaseRows<Sale> {
  bool isExpanded(int id);
  void toggle(Sale sale);
}

/// Drives `Satışlar`: the documents loaded so far, the next page, the
/// documents behind the cards that have been opened — and the filter.
///
/// The paging is every `Baza` list's ([DatabaseListController]): a page at
/// a time, never past the last, nothing again until a pull, and nothing
/// mixed in from a question that has since been replaced. On top of it:
///
/// * nothing at all to open a card: the list's rows already carry the
///   organisation and the product lines. Only a row that does not is
///   fetched whole, when its card is first opened, and only once — it is
///   kept for the session.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own documents, its own open cards and its own place
/// in the scroll, found in the whole of the 1C database rather than in the
/// pages read so far — so letting go of the filter puts the reader back
/// exactly where they were, and a document found four thousand rows down
/// goes back there with it.
class SalesController extends DatabaseListController<Sale>
    implements SalesRows, DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  SalesController(this._api, {int pageSize = kSalesPageSize})
    : super(_api.salesPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(Sale sale) => sale.id;

  /// Every document loaded so far, in the bridge's order.
  List<Sale> get sales => rows;

  final Set<int> _expanded = <int>{};
  final LinkedHashMap<int, Sale> _documents = LinkedHashMap<int, Sale>();
  final Set<int> _documentsLoading = <int>{};
  final Map<int, String> _documentErrors = <int, String>{};

  /// A pull's page one has replaced the list: opened cards shut and their
  /// documents are forgotten, so that a pull gives fresh lines as well as
  /// fresh rows.
  @override
  void didRestart() {
    _expanded.clear();
    _filteredExpanded.clear();
    _documents.clear();
    _documentsLoading.clear();
    _documentErrors.clear();

    // Every filtered answer is as old as the list just replaced.
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Open cards ──────────────────────────────────────────────────────────

  @override
  bool isExpanded(int id) => _expanded.contains(id);

  /// Opens or shuts a card, and asks for its document the first time it is
  /// opened.
  @override
  void toggle(Sale sale) => _toggle(_expanded, sale);

  void _toggle(Set<int> open, Sale sale) {
    if (!open.remove(sale.id)) {
      open.add(sale.id);
      if (sale.needsDocument) loadDocument(sale.id);
    }
    notify();
  }

  /// What a card shows: its row, with its document laid over it once known.
  Sale view(Sale sale) {
    final Sale? document = _documents[sale.id];
    return document == null ? sale : sale.mergedWith(document);
  }

  bool isDocumentLoading(int id) => _documentsLoading.contains(id);

  /// Why the document could not be read, or null.
  String? documentError(int id) => _documentErrors[id];

  /// Fetches a document unless it is here already or on its way.
  Future<void> loadDocument(int id) async {
    if (_documents.containsKey(id) || _documentsLoading.contains(id)) return;

    final int asked = generation;
    _documentsLoading.add(id);
    _documentErrors.remove(id);
    notify();

    try {
      final Sale document = await _api.sale(id);
      if (asked != generation) return;
      _remember(id, document);
    } on ApiException catch (error) {
      if (asked != generation) return;
      _documentErrors[id] = error.message;
    } finally {
      if (asked == generation) {
        _documentsLoading.remove(id);
        notify();
      }
    }
  }

  /// Keeps [document], forgetting the oldest one that is not on an open card
  /// once there are more than [kSaleDocumentMemory].
  void _remember(int id, Sale document) {
    _documents
      ..remove(id)
      ..[id] = document;
    if (_documents.length <= kSaleDocumentMemory) return;
    for (final int old in _documents.keys) {
      if (!_expanded.contains(old) && !_filteredExpanded.contains(old)) {
        _documents.remove(old);
        return;
      }
    }
  }

  // ── The filter ──────────────────────────────────────────────────────────

  SalesFilter _filter = SalesFilter.none;

  /// What the list is narrowed to.
  SalesFilter get filter => _filter;

  SalesFilterView? _view;

  /// The filtered list, while there is a filter; null shows every document.
  @override
  SalesFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Cards opened in a filtered list. Kept apart from the list's own, so a
  /// card opened while filtering does not shift the list the filter hid.
  final Set<int> _filteredExpanded = <int>{};

  /// Filtered answers, by their question, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<Sale>> _feeds =
      LinkedHashMap<String, DatabaseFeed<Sale>>();

  /// How many documents a `search` finds, once asked.
  final Map<String, int?> _counts = <String, int?>{};

  int _rowsStamp = 0;

  /// Bumped whenever documents arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every document on the phone: the list's, and every filtered answer's.
  /// The values a filter column offers before anything is typed are theirs.
  Iterable<Sale> get knownSales sync* {
    yield* base.rows;
    for (final DatabaseFeed<Sale> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  SalesFilterValues? _values;

  /// The values each filter column offers.
  SalesFilterValues get values => _values ??= SalesFilterValues(this, _api);

  @override
  List<SalesColumn> get filterColumns => SalesColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(SalesColumn column) => _filter.has(column);

  @override
  bool isChosen(SalesColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  SalesFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(SalesFilter next) {
    if (next == _filter) return _view?.ready ?? Future<void>.value();
    _filter = next;
    _view?._close();
    if (next.isEmpty) {
      _view = null;
      _filteredExpanded.clear();
      notify();
      return Future<void>.value();
    }
    return _replan(fresh: false);
  }

  @override
  Future<void> toggleFilter(SalesColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(SalesColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(SalesFilter.none);

  /// Asks [filter] again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final SalesFilterView view = SalesFilterView._(
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
    _counts.clear();
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

  static String _feedKey(String? search, int start) =>
      '${search ?? ''}\u0000$start';

  /// The answer to [search] from [start] on, kept or new.
  DatabaseFeed<Sale> _feedFor(String? search, int start) {
    final String key = _feedKey(search, start);
    final DatabaseFeed<Sale> feed =
        _feeds.remove(key) ??
        DatabaseFeed<Sale>(
          _api.salesPage,
          idOf: _idOf,
          search: search,
          start: start,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kSalesFeedMemory) {
      _feeds.remove(_feeds.keys.first);
    }
    return feed;
  }

  /// A feed already holding every document of [date] among [search]'s — the
  /// list's own pages, when they reach back past it — so a day seen today
  /// or yesterday costs no request at all.
  DatabaseFeed<Sale>? _covering(
    String? search,
    String date, {
    required bool fresh,
  }) {
    bool covers(DatabaseFeed<Sale> feed) {
      if (feed.start != 0) return false;
      if (feed.exhausted) return true;
      final List<Sale> rows = feed.rows;
      if (rows.isEmpty) return false;
      final String? last = rows.last.date;
      return last != null && last.compareTo(date) < 0;
    }

    if (search == null && !fresh && hasLoaded && covers(base)) return base;
    final DatabaseFeed<Sale>? kept = _feeds[_feedKey(search, 0)];
    return kept != null && covers(kept) ? kept : null;
  }

  /// The longest start of [search]'s answer already on the phone — the
  /// list's own pages, for no search at all.
  List<Sale> _knownStart(String? search, {required bool fresh}) {
    final List<Sale> kept = _feeds[_feedKey(search, 0)]?.rows ?? const <Sale>[];
    if (search != null || fresh || base.rows.length <= kept.length) {
      return kept;
    }
    return base.rows;
  }

  /// How many documents [search] finds — what is known already, or one
  /// one-row request.
  Future<int?> _count(String? search) async {
    final String key = search ?? '';
    if (_counts.containsKey(key)) return _counts[key];
    final int? known = search == null
        ? base.total
        : _feeds[_feedKey(search, 0)]?.total;
    if (known != null) return known;

    final DatabasePage<Sale> page = await _api.salesPage(
      page: 1,
      pageSize: 1,
      search: search,
    );
    final int? total = page.total ?? (page.received == 0 ? 0 : null);
    _counts[key] = total;
    return total;
  }

  /// Where the documents dated [date] begin among [search]'s [total] — to the
  /// page, as a place a feed can start from.
  ///
  /// The bridge orders every answer newest first and nothing else (not one
  /// inversion in 7,547 documents), so the place can be found without
  /// reading what comes before it: one row is asked for at a time, and the
  /// dates on the rows already seen say where to look next. [known] is the
  /// start of the answer if some of it has been read.
  Future<int> _seek({
    required String? search,
    required String date,
    required int total,
    required List<Sale> known,
  }) async {
    // Rows up to [lo] are newer than [date]; [hi] and after are not.
    int lo = -1;
    String? loDate;
    int hi = total;
    String? hiDate;
    for (int i = 0; i < known.length; i++) {
      final String? day = known[i].date;
      // An undated document sorts first in a newest-first answer.
      if (day == null || day.compareTo(date) > 0) {
        lo = i;
        loDate = day ?? loDate;
      } else {
        hi = i;
        hiDate = day;
        break;
      }
    }

    int probes = 0;
    bool bisect = false;
    while (hi - lo > pageSize && probes < kSalesSeekProbes) {
      final int width = hi - lo;
      final bool guess;
      final int at;
      if (loDate == null && lo == -1) {
        // The newest and the oldest first: everything after is
        // interpolated between them.
        at = 0;
        guess = false;
      } else if (hiDate == null && hi == total) {
        at = total - 1;
        guess = false;
      } else {
        at = _probe(
          lo: lo,
          loDate: loDate,
          hi: hi,
          hiDate: hiDate,
          date: date,
          bisect: bisect,
        );
        guess = !bisect;
      }
      probes++;

      final DatabasePage<Sale> page = await _api.salesPage(
        page: at + 1,
        pageSize: 1,
        search: search,
      );
      if (isDisposed) return 0;
      if (page.received == 0) {
        // The answer is shorter than it was a moment ago.
        hi = at;
        continue;
      }
      final String? day = page.rows.isEmpty ? null : page.rows.first.date;
      if (day == null || day.compareTo(date) > 0) {
        lo = at;
        loDate = day ?? loDate;
      } else {
        hi = at;
        hiDate = day;
      }
      // A guess that did not halve the gap is followed by a halving, so a
      // lopsided run of dates can never make this slower than a bisection;
      // a halving is followed by a guess again.
      bisect = guess && (hi - lo) * 2 > width;
    }

    final int first = lo + 1;
    return first - first % pageSize;
  }

  static int _probe({
    required int lo,
    required String? loDate,
    required int hi,
    required String? hiDate,
    required String date,
    required bool bisect,
  }) {
    int at = lo + (hi - lo) ~/ 2;
    final int? newer = _dayNumber(loDate);
    final int? older = _dayNumber(hiDate);
    final int? target = _dayNumber(date);
    if (!bisect &&
        newer != null &&
        older != null &&
        target != null &&
        newer > older) {
      // Aim between [date] and the day after it: that is where its first
      // document is.
      final double share = (newer - (target + 0.5)) / (newer - older);
      at = lo + ((hi - lo) * share).round();
    }
    return at.clamp(lo + 1, hi - 1);
  }

  static int? _dayNumber(String? iso) {
    if (iso == null) return null;
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  @override
  void dispose() {
    _view?._close();
    _values?.dispose();
    super.dispose();
  }
}

/// The documents a filter lets through, found in the whole of the 1C
/// database.
///
/// The bridge can narrow an answer by one thing only — `search`, a substring
/// of the number, the customer or the manager — so the rest is done here:
///
/// * the most selective value the bridge *can* search for is sent as
///   `search`: the document number when there is one, otherwise whichever of
///   the customer and the manager finds fewer documents;
/// * a day is sought rather than read towards: the answer is newest first,
///   so the page where the day begins is found with a few one-row requests,
///   and reading stops at the first document older than it;
/// * every other column is checked against each document read, a page at a
///   time as the list asks for more — the page growing while matches are
///   few, since most of a scan's time is the bridge's per-request cost.
class SalesFilterView implements SalesRows, DatabaseFilteredRows<Sale> {
  SalesFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final SalesController _owner;

  final SalesFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<Sale> _matches = <Sale>[];

  @override
  late final List<Sale> rows = UnmodifiableListView<Sale>(_matches);

  DatabaseFeed<Sale>? _feed;
  int _epoch = -1;

  /// How many of the feed's documents have been checked.
  int _examined = 0;

  /// Reached a document older than the day filtered on: nothing after it
  /// can match.
  bool _pastEnd = false;

  int _scanSize;

  /// The column whose value went to the bridge as `search`.
  SalesColumn? _searched;

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
    final DatabaseFeed<Sale>? feed = _feed;
    if (feed == null || _pastEnd) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    for (final SalesColumn column in filter.columns) {
      if (column != _searched && column != SalesColumn.date) return true;
    }
    return false;
  }

  @override
  int get read => _examined;

  /// How many there are to check, when the bridge says and no day bounds
  /// the reading.
  @override
  int? get readOf {
    final DatabaseFeed<Sale>? feed = _feed;
    final int? total = feed?.total;
    if (feed == null || total == null || filter.has(SalesColumn.date)) {
      return null;
    }
    return math.max(0, total - feed.start);
  }

  Future<void> _start() async {
    try {
      final SalesColumn? searched = await _chooseSearch();
      if (_closed) return;
      _searched = searched;
      final String? search = searched == null ? null : filter.valueOf(searched);

      DatabaseFeed<Sale> feed = _owner._feedFor(search, 0);
      final String? date = filter.valueOf(SalesColumn.date);
      if (date != null) {
        final DatabaseFeed<Sale>? covering = _owner._covering(
          search,
          date,
          fresh: fresh,
        );
        if (covering != null) {
          feed = covering;
        } else {
          final int? total = await _owner._count(search);
          if (_closed) return;
          if (total != null && total > kSalesSeekThreshold) {
            final int at = await _owner._seek(
              search: search,
              date: date,
              total: total,
              known: _owner._knownStart(search, fresh: fresh),
            );
            if (_closed) return;
            if (at > 0) feed = _owner._feedFor(search, at);
          }
        }
      }

      _feed = feed;
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

  /// The column worth sending as `search`: the number, which names one
  /// document; otherwise the customer or the manager, whichever the bridge
  /// says finds fewer.
  Future<SalesColumn?> _chooseSearch() async {
    if (filter.has(SalesColumn.number)) return SalesColumn.number;
    final List<SalesColumn> candidates = <SalesColumn>[
      for (final SalesColumn column in const <SalesColumn>[
        SalesColumn.customer,
        SalesColumn.manager,
      ])
        if (filter.has(column)) column,
    ];
    if (candidates.length < 2) {
      return candidates.isEmpty ? null : candidates.single;
    }

    SalesColumn best = candidates.first;
    int? fewest;
    for (final SalesColumn column in candidates) {
      final int? total = await _owner._count(filter.valueOf(column));
      if (_closed) return best;
      if (total != null && (fewest == null || total < fewest)) {
        best = column;
        fewest = total;
      }
    }
    return best;
  }

  /// Checks whatever the feed has read since last time.
  void _sync() {
    final DatabaseFeed<Sale>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
      _pastEnd = false;
    }

    final List<Sale> all = feed.rows;
    final String? date = filter.valueOf(SalesColumn.date);
    while (!_pastEnd && _examined < all.length) {
      final Sale sale = all[_examined];
      final String? day = sale.date;
      if (date != null && day != null && day.compareTo(date) < 0) {
        _pastEnd = true;
        return;
      }
      _examined++;
      if (filter.matches(sale)) _matches.add(sale);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<Sale> feed = _feed!;
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

  @override
  bool isExpanded(int id) => _owner._filteredExpanded.contains(id);

  @override
  void toggle(Sale sale) => _owner._toggle(_owner._filteredExpanded, sale);

  void _close() => _closed = true;
}
