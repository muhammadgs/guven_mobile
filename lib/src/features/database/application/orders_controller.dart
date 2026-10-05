import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/order.dart';
import '../domain/orders_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'orders_filter_values.dart';

/// How many orders one request asks for.
///
/// An order's row is small: twenty of them are ~6.5 KB of JSON and the
/// bridge answers them in ~0.15 s (measured 2026-09-27). Twenty is four
/// screens of the short cards — the other lists' page, for the same reasons.
const int kOrdersPageSize = 20;

/// How many opened orders' own answers are remembered. Past this the oldest
/// is forgotten and asked for again should its card open again.
const int kOrderDetailMemory = 150;

/// How many filtered answers are kept, with the orders read for them, for
/// when the filter comes back to one.
const int kOrdersFeedMemory = 8;

/// A list of order cards — every order, or only the ones a filter lets
/// through — whose cards open, each list its own.
abstract interface class OrdersRows implements DatabaseRows<Order> {
  bool isExpanded(int id);
  void toggle(Order order);
}

/// Drives `Sifarişlər`: the orders loaded so far, the next page, the orders
/// behind the cards that have been opened — and the filter.
///
/// The paging is every `Baza` list's ([DatabaseListController]). On top of
/// it:
///
/// * an open card shows what only the order's own answer carries — the
///   discount, the tax, what has been paid — so that is asked for the first
///   time the card opens, and kept for the session;
/// * the filter's values. The bridge can search an order's number and match
///   its status, and nothing else: which days, amounts and payment states
///   exist can only be known by reading every order. So the first time one
///   of those columns is opened the rest of the table is read into the
///   list's own pages ([readAll]) — 7,519 orders, ~2.5 MB, ~7 s on
///   2026-09-27 — and from then on every value is listed and every filter is
///   answered on the phone, without another request.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own open cards and its own place in the scroll, so
/// letting go of it puts the reader back exactly where they were.
class OrdersController extends DatabaseListController<Order>
    implements OrdersRows, DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  OrdersController(this._api, {int pageSize = kOrdersPageSize})
    : super(_api.ordersPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(Order order) => order.id;

  /// Every order loaded so far, in the bridge's order.
  List<Order> get orders => rows;

  final Set<int> _expanded = <int>{};
  final LinkedHashMap<int, Order> _details = LinkedHashMap<int, Order>();
  final Set<int> _detailsLoading = <int>{};
  final Map<int, String> _detailErrors = <int, String>{};

  /// A pull's page one has replaced the list: opened cards shut, their
  /// orders' answers are forgotten, and so is everything read for the
  /// filter.
  @override
  void didRestart() {
    _expanded.clear();
    _filteredExpanded.clear();
    _details.clear();
    _detailsLoading.clear();
    _detailErrors.clear();
    _readAllError = null;

    // Every filtered answer is as old as the list just replaced.
    _forgetAnswers();
    if (_view != null) _replan(fresh: false);
  }

  // ── Open cards ──────────────────────────────────────────────────────────

  @override
  bool isExpanded(int id) => _expanded.contains(id);

  /// Opens or shuts a card, and asks for its order's own answer the first
  /// time it is opened.
  @override
  void toggle(Order order) => _toggle(_expanded, order);

  void _toggle(Set<int> open, Order order) {
    if (!open.remove(order.id)) {
      open.add(order.id);
      loadDetail(order.id);
    }
    notify();
  }

  /// What a card shows: its row, with the order's own answer laid over it
  /// once that is known.
  Order view(Order order) {
    final Order? detail = _details[order.id];
    return detail == null ? order : order.mergedWith(detail);
  }

  bool isDetailLoading(int id) => _detailsLoading.contains(id);

  /// Why the order's own answer could not be read, or null.
  String? detailError(int id) => _detailErrors[id];

  /// Asks for an order's own answer unless it is here already or on its way.
  Future<void> loadDetail(int id) async {
    if (_details.containsKey(id) || _detailsLoading.contains(id)) return;

    final int asked = generation;
    _detailsLoading.add(id);
    _detailErrors.remove(id);
    notify();

    try {
      final Order detail = await _api.order(id);
      if (asked != generation) return;
      _remember(id, detail);
    } on ApiException catch (error) {
      if (asked != generation) return;
      _detailErrors[id] = error.message;
    } finally {
      if (asked == generation) {
        _detailsLoading.remove(id);
        notify();
      }
    }
  }

  /// Keeps [detail], forgetting the oldest one that is not on an open card
  /// once there are more than [kOrderDetailMemory].
  void _remember(int id, Order detail) {
    _details
      ..remove(id)
      ..[id] = detail;
    if (_details.length <= kOrderDetailMemory) return;
    for (final int old in _details.keys) {
      if (!_expanded.contains(old) && !_filteredExpanded.contains(old)) {
        _details.remove(old);
        return;
      }
    }
  }

  // ── Every order ─────────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the table is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the table stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every order in the table is on the phone: the list's own pages
  /// reach its end.
  bool get hasEveryOrder => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the table into the list's own pages, as large as a
  /// page goes, so that a filter column can list every value it has.
  ///
  /// The rows read are the list's own — nothing is read twice, and the list
  /// then scrolls to its end without asking again. Stops where a pull starts
  /// the list over.
  Future<void> readAll() async {
    if (_readingAll || hasEveryOrder) return;
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
        await base.next(kDatabaseScanPageMax);
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

  OrdersFilter _filter = OrdersFilter.none;

  /// What the list is narrowed to.
  OrdersFilter get filter => _filter;

  OrdersFilterView? _view;

  /// The filtered list, while there is a filter; null shows every order.
  @override
  OrdersFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Cards opened in a filtered list. Kept apart from the list's own, so a
  /// card opened while filtering does not shift the list the filter hid.
  final Set<int> _filteredExpanded = <int>{};

  /// Filtered answers, by their question, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<Order>> _feeds =
      LinkedHashMap<String, DatabaseFeed<Order>>();

  int _rowsStamp = 0;

  /// Bumped whenever orders arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every order on the phone: the list's, and every filtered answer's. The
  /// values a filter column offers are theirs.
  Iterable<Order> get knownOrders sync* {
    yield* base.rows;
    for (final DatabaseFeed<Order> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  OrdersFilterValues? _values;

  /// The values each filter column offers.
  OrdersFilterValues get values => _values ??= OrdersFilterValues(this, _api);

  @override
  List<OrdersColumn> get filterColumns => OrdersColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(OrdersColumn column) => _filter.has(column);

  @override
  bool isChosen(OrdersColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  OrdersFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(OrdersFilter next) {
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
  Future<void> toggleFilter(OrdersColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(OrdersColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(OrdersFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final OrdersFilterView view = OrdersFilterView._(
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

  static String _feedKey(String? search, String? status) =>
      '${search ?? ''}\u0000${status ?? ''}';

  /// The answer to [search] and [status], kept or new.
  ///
  /// The list's own pages answer it instead whenever they can: when they
  /// already hold every order, or when the question is the list's own — no
  /// search, no status — in which case every order already read is checked
  /// for free and every order read for the filter is one the list will not
  /// ask for again. Not while they are on their way in again, and not for a
  /// pull, which wants nothing old.
  DatabaseFeed<Order> _feedFor(
    String? search,
    String? status, {
    required bool fresh,
  }) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || (search == null && status == null))) {
      return base;
    }
    final String key = _feedKey(search, status);
    final DatabaseFeed<Order> feed =
        _feeds.remove(key) ??
        DatabaseFeed<Order>(
          _fetchFor(status),
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kOrdersFeedMemory) {
      _feeds.remove(_feeds.keys.first);
    }
    return feed;
  }

  /// One page of the answer narrowed to [status] by the bridge itself.
  DatabasePageFetch<Order> _fetchFor(String? status) {
    if (status == null) return _api.ordersPage;
    return ({required int page, required int pageSize, String? search}) =>
        _api.ordersPage(
          page: page,
          pageSize: pageSize,
          search: search,
          status: status,
        );
  }

  @override
  void dispose() {
    _view?._close();
    _values?.dispose();
    super.dispose();
  }
}

/// The orders a filter lets through, found in the whole table.
///
/// The bridge narrows an answer two ways — `search`, a substring of the
/// number, and `status`, matched exactly — so both go to it when chosen; the
/// number is checked exactly here as well. A day, an amount and a payment
/// state are checked against each order read, a page at a time as the list
/// asks for more, the page growing while matches are few. The answer is in
/// no order a day or an amount could stop early on, so at its worst that is
/// the whole table: 7,519 orders, ~2.5 MB — and nothing at all once
/// [OrdersController.readAll] has put every order on the phone.
class OrdersFilterView implements OrdersRows, DatabaseFilteredRows<Order> {
  OrdersFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final OrdersController _owner;

  final OrdersFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<Order> _matches = <Order>[];

  @override
  late final List<Order> rows = UnmodifiableListView<Order>(_matches);

  DatabaseFeed<Order>? _feed;
  int _epoch = -1;

  /// How many of the feed's orders have been checked.
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
    final DatabaseFeed<Order>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    for (final OrdersColumn column in filter.columns) {
      if (column != OrdersColumn.number && column != OrdersColumn.status) {
        return true;
      }
    }
    return false;
  }

  @override
  int get read => _examined;

  @override
  int? get readOf => _feed?.total;

  Future<void> _start() async {
    try {
      final String? search = filter.valueOf(OrdersColumn.number)?.trim();
      _feed = _owner._feedFor(
        search == null || search.isEmpty ? null : search,
        filter.valueOf(OrdersColumn.status),
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
    final DatabaseFeed<Order>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<Order> all = feed.rows;
    while (_examined < all.length) {
      final Order order = all[_examined++];
      if (filter.matches(order)) _matches.add(order);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<Order> feed = _feed!;
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
  void toggle(Order order) => _owner._toggle(_owner._filteredExpanded, order);

  void _close() => _closed = true;
}
