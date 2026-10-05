import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/customer.dart';
import '../domain/customers_filter.dart';
import 'customers_filter_values.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';

/// How many customers one request asks for.
///
/// Twenty customer rows are ~9.7 KB of JSON and the bridge answers them in
/// under a second (measured 2026-10-04) — four or five screens of the shut
/// cards, the other lists' page for the same reasons.
const int kCustomersPageSize = 20;

/// The largest page read when the whole directory is wanted at once
/// ([CustomersController.readAll]): the bridge's own ceiling. The directory
/// is 310 customers, ~150 KB — one request at this size.
const int kCustomersReadAllPageMax = 500;

/// How many opened customers' own answers are remembered. Past this the
/// oldest is forgotten and asked for again should its card open again.
const int kCustomerDetailMemory = 150;

/// How many filtered answers are kept, with the customers read for them,
/// for when the filter comes back to one.
const int kCustomersFeedMemory = 8;

/// A list of customer cards — every customer, or only the ones a filter
/// lets through — whose cards open, each list its own.
abstract interface class CustomersRows implements DatabaseRows<Customer> {
  bool isExpanded(int id);
  void toggle(Customer customer);
}

/// Drives `Müştərilər`: the customers loaded so far, the next page, the
/// roles and legal statuses behind the cards that have been opened — and
/// the filter.
///
/// The paging is every `Baza` list's ([DatabaseListController]). On top of
/// it:
///
/// * an open card shows the customer's role and legal status, which only
///   the customer's own answer carries, so that is asked for every time the
///   card opens — a field filled in 1C since shows up the next time — while
///   the card shows what was last known of it;
/// * the filter. The bridge can search a name, a code or a VÖEN and nothing
///   else, so everything else is checked against the customers read. The
///   directory is small — 310 customers, ~150 KB — so the first time a
///   column whose values can only be known by reading all of it opens
///   (`Ödəniş müddəti`), the rest is read into the list's own pages
///   ([readAll]); from then on every value is listed and every filter is
///   answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own open cards and its own place in the scroll, so
/// letting go of it puts the reader back exactly where they were.
class CustomersController extends DatabaseListController<Customer>
    implements CustomersRows, DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  CustomersController(this._api, {int pageSize = kCustomersPageSize})
    : super(_api.customersPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(Customer customer) => customer.id;

  /// Every customer loaded so far, in the bridge's order.
  List<Customer> get customers => rows;

  final Set<int> _expanded = <int>{};
  final LinkedHashMap<int, Customer> _details = LinkedHashMap<int, Customer>();
  final Set<int> _detailsLoading = <int>{};

  /// Customers whose answer is known and being asked for again.
  final Set<int> _detailsRefreshing = <int>{};
  final Map<int, String> _detailErrors = <int, String>{};

  /// A pull's page one has replaced the list: opened cards shut, their
  /// customers' answers are forgotten, and so is everything read for the
  /// filter.
  @override
  void didRestart() {
    _expanded.clear();
    _filteredExpanded.clear();
    _details.clear();
    _detailsLoading.clear();
    _detailsRefreshing.clear();
    _detailErrors.clear();
    _readAllError = null;

    // Every filtered answer is as old as the list just replaced.
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Open cards ──────────────────────────────────────────────────────────

  @override
  bool isExpanded(int id) => _expanded.contains(id);

  /// Opens or shuts a card, and asks for its customer's own answer every
  /// time it is opened.
  @override
  void toggle(Customer customer) => _toggle(_expanded, customer);

  void _toggle(Set<int> open, Customer customer) {
    if (!open.remove(customer.id)) {
      open.add(customer.id);
      loadDetail(customer.id, again: true);
    }
    notify();
  }

  /// What a card shows: its row, with the customer's own answer laid over
  /// it once that is known.
  Customer view(Customer customer) {
    final Customer? detail = _details[customer.id];
    return detail == null ? customer : customer.mergedWith(detail);
  }

  /// True while the customer's own answer is on its way and nothing of it
  /// is known yet. Asking again for one already known is not loading: the
  /// card goes on showing what it knows.
  bool isDetailLoading(int id) => _detailsLoading.contains(id);

  /// Why the customer's own answer could not be read, or null.
  String? detailError(int id) => _detailErrors[id];

  /// Asks for a customer's own answer unless it is on its way — or, unless
  /// [again], already here.
  ///
  /// Asked [again], a known answer stays on the card until the new one
  /// replaces it, and stays there if the new one cannot be read: an older
  /// answer is still better than an error over it.
  Future<void> loadDetail(int id, {bool again = false}) async {
    if (_detailsLoading.contains(id) || _detailsRefreshing.contains(id)) {
      return;
    }
    final bool known = _details.containsKey(id);
    if (known && !again) return;

    final int asked = generation;
    final Set<int> pending = known ? _detailsRefreshing : _detailsLoading;
    pending.add(id);
    _detailErrors.remove(id);
    notify();

    try {
      final Customer detail = await _api.customer(id);
      if (asked != generation) return;
      _remember(id, detail);
    } on ApiException catch (error) {
      if (asked != generation || known) return;
      _detailErrors[id] = error.message;
    } finally {
      if (asked == generation) {
        pending.remove(id);
        notify();
      }
    }
  }

  /// Keeps [detail], forgetting the oldest one that is not on an open card
  /// once there are more than [kCustomerDetailMemory].
  void _remember(int id, Customer detail) {
    _details
      ..remove(id)
      ..[id] = detail;
    if (_details.length <= kCustomerDetailMemory) return;
    for (final int old in _details.keys) {
      if (!_expanded.contains(old) && !_filteredExpanded.contains(old)) {
        _details.remove(old);
        return;
      }
    }
  }

  // ── Every customer ──────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the directory is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the directory stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every customer in the directory is on the phone: the list's
  /// own pages reach its end.
  bool get hasEveryCustomer => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the directory into the list's own pages, as large as
  /// a page goes, so that a filter column can list every value it has.
  ///
  /// The rows read are the list's own — nothing is read twice, and the list
  /// then scrolls to its end without asking again. Stops where a pull
  /// starts the list over.
  Future<void> readAll() async {
    if (_readingAll || hasEveryCustomer) return;
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
        await base.next(kCustomersReadAllPageMax);
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

  CustomersFilter _filter = CustomersFilter.none;

  /// What the list is narrowed to.
  CustomersFilter get filter => _filter;

  CustomersFilterView? _view;

  /// The filtered list, while there is a filter; null shows every customer.
  @override
  CustomersFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Cards opened in a filtered list. Kept apart from the list's own, so a
  /// card opened while filtering does not shift the list the filter hid.
  final Set<int> _filteredExpanded = <int>{};

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<Customer>> _feeds =
      LinkedHashMap<String, DatabaseFeed<Customer>>();

  int _rowsStamp = 0;

  /// Bumped whenever customers arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every customer on the phone: the list's, and every filtered answer's.
  /// The values a filter column offers are theirs.
  Iterable<Customer> get knownCustomers sync* {
    yield* base.rows;
    for (final DatabaseFeed<Customer> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  CustomersFilterValues? _values;

  /// The values each filter column offers.
  CustomersFilterValues get values =>
      _values ??= CustomersFilterValues(this, _api);

  @override
  List<CustomersColumn> get filterColumns => CustomersColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(CustomersColumn column) => _filter.has(column);

  @override
  bool isChosen(CustomersColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  CustomersFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(CustomersFilter next) {
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
  Future<void> toggleFilter(CustomersColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(CustomersColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(CustomersFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final CustomersFilterView view = CustomersFilterView._(
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
  /// already hold every customer, or when the question is the list's own —
  /// no search — in which case every customer already read is checked for
  /// free and every one read for the filter is one the list will not ask
  /// for again. Not while they are on their way in again, and not for a
  /// pull, which wants nothing old.
  DatabaseFeed<Customer> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<Customer> feed =
        _feeds.remove(key) ??
        DatabaseFeed<Customer>(
          _api.customersPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kCustomersFeedMemory) {
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

/// The customers a filter lets through, found in the whole directory.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// name, the code or the VÖEN — so the code, or else the name, goes to it
/// when chosen and is checked exactly here as well. Everything else — a
/// kind, a payment term — is checked against each customer read, a page at
/// a time as the list asks for more, the page growing while matches are
/// few. At its worst that is all of it: 310 customers, ~150 KB — and
/// nothing at all once [CustomersController.readAll] has put every customer
/// on the phone.
class CustomersFilterView
    implements CustomersRows, DatabaseFilteredRows<Customer> {
  CustomersFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final CustomersController _owner;

  final CustomersFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<Customer> _matches = <Customer>[];

  @override
  late final List<Customer> rows = UnmodifiableListView<Customer>(_matches);

  DatabaseFeed<Customer>? _feed;
  int _epoch = -1;

  /// How many of the feed's customers have been checked.
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
    final DatabaseFeed<Customer>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final CustomersColumn? searched = filter.searchColumn;
    for (final CustomersColumn column in filter.columns) {
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
      final CustomersColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<Customer>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<Customer> all = feed.rows;
    while (_examined < all.length) {
      final Customer customer = all[_examined++];
      if (filter.matches(customer)) _matches.add(customer);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<Customer> feed = _feed!;
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
  void toggle(Customer customer) =>
      _owner._toggle(_owner._filteredExpanded, customer);

  void _close() => _closed = true;
}
