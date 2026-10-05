import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/product.dart';
import '../domain/products_filter.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';
import 'products_filter_values.dart';

/// How many products one request asks for.
///
/// Twenty product rows are ~12 KB of JSON and the bridge answers them in a
/// quarter of a second (measured 2026-09-29) — four or five screens of the
/// shut cards, the other lists' page for the same reasons.
const int kProductsPageSize = 20;

/// The largest page read when the whole catalogue is wanted at once
/// ([ProductsController.readAll]): the bridge's own ceiling. The catalogue
/// is 593 products, ~354 KB — a handful of requests at this size.
const int kProductsReadAllPageMax = 500;

/// How many opened products' own answers are remembered. Past this the
/// oldest is forgotten and asked for again should its card open again.
const int kProductDetailMemory = 150;

/// How many filtered answers are kept, with the products read for them, for
/// when the filter comes back to one.
const int kProductsFeedMemory = 8;

/// The price's, the stock's and the VAT rate's fields.
const Map<ProductsColumn, FilterRangeField> kProductRangeFields =
    <ProductsColumn, FilterRangeField>{
      ProductsColumn.price: FilterRangeField(
        minHint: 'Min qiymət',
        maxHint: 'Maks qiymət',
        suffix: '₼',
      ),
      ProductsColumn.stock: FilterRangeField(
        minHint: 'Min stok',
        maxHint: 'Maks stok',
        // 1C lets a balance go below nothing, and "what is short" is a
        // question worth being able to ask.
        signed: true,
      ),
      ProductsColumn.vat: FilterRangeField(
        minHint: 'Min ƏDV',
        maxHint: 'Maks ƏDV',
        suffix: '%',
      ),
    };

/// A list of product cards — every product, or only the ones a filter lets
/// through — whose cards open, each list its own.
abstract interface class ProductsRows implements DatabaseRows<Product> {
  bool isExpanded(int id);
  void toggle(Product product);
}

/// Drives `Məhsullar`: the products loaded so far, the next page, the
/// warehouses behind the cards that have been opened — and the filter.
///
/// The paging is every `Baza` list's ([DatabaseListController]). On top of
/// it:
///
/// * an open card shows the product's balance in each warehouse, which only
///   the product's own answer carries, so that is asked for the first time
///   the card opens and kept for the session;
/// * the filter. The bridge can search a code or a name and nothing else,
///   so everything else is checked against the products read. The catalogue
///   is small — 593 products, ~354 KB — so the first time a column whose
///   values can only be known by reading all of it opens (`Kateqoriya`,
///   `Vahid`, `Növ`), the rest is read into the list's own pages
///   ([readAll]); from then on every value is listed and every filter is
///   answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own open cards and its own place in the scroll, so
/// letting go of it puts the reader back exactly where they were.
class ProductsController extends DatabaseListController<Product>
    implements ProductsRows, DatabaseRangeFilterSource {
  /// [pageSize] is the seam the tests reach through.
  ProductsController(this._api, {int pageSize = kProductsPageSize})
    : super(_api.productsPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(Product product) => product.id;

  /// Every product loaded so far, in the bridge's order.
  List<Product> get products => rows;

  final Set<int> _expanded = <int>{};
  final LinkedHashMap<int, Product> _details = LinkedHashMap<int, Product>();
  final Set<int> _detailsLoading = <int>{};
  final Map<int, String> _detailErrors = <int, String>{};

  /// A pull's page one has replaced the list: opened cards shut, their
  /// products' answers are forgotten, and so is everything read for the
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

  /// Opens or shuts a card, and asks for its product's own answer the first
  /// time it is opened.
  @override
  void toggle(Product product) => _toggle(_expanded, product);

  void _toggle(Set<int> open, Product product) {
    if (!open.remove(product.id)) {
      open.add(product.id);
      loadDetail(product.id);
    }
    notify();
  }

  /// What a card shows: its row, with the product's own answer laid over it
  /// once that is known.
  Product view(Product product) {
    final Product? detail = _details[product.id];
    return detail == null ? product : product.mergedWith(detail);
  }

  bool isDetailLoading(int id) => _detailsLoading.contains(id);

  /// Why the product's own answer could not be read, or null.
  String? detailError(int id) => _detailErrors[id];

  /// Asks for a product's own answer unless it is here already or on its
  /// way.
  Future<void> loadDetail(int id) async {
    if (_details.containsKey(id) || _detailsLoading.contains(id)) return;

    final int asked = generation;
    _detailsLoading.add(id);
    _detailErrors.remove(id);
    notify();

    try {
      final Product detail = await _api.product(id);
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
  /// once there are more than [kProductDetailMemory].
  void _remember(int id, Product detail) {
    _details
      ..remove(id)
      ..[id] = detail;
    if (_details.length <= kProductDetailMemory) return;
    for (final int old in _details.keys) {
      if (!_expanded.contains(old) && !_filteredExpanded.contains(old)) {
        _details.remove(old);
        return;
      }
    }
  }

  // ── Every product ───────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the catalogue is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the catalogue stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every product in the catalogue is on the phone: the list's own
  /// pages reach its end.
  bool get hasEveryProduct => hasLoaded && !isLoadingFirst && base.exhausted;

  /// Reads the rest of the catalogue into the list's own pages, as large as
  /// a page goes, so that a filter column can list every value it has.
  ///
  /// The rows read are the list's own — nothing is read twice, and the list
  /// then scrolls to its end without asking again. Stops where a pull
  /// starts the list over.
  Future<void> readAll() async {
    if (_readingAll || hasEveryProduct) return;
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
        await base.next(kProductsReadAllPageMax);
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

  ProductsFilter _filter = ProductsFilter.none;

  /// What the list is narrowed to.
  ProductsFilter get filter => _filter;

  ProductsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every product.
  @override
  ProductsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Cards opened in a filtered list. Kept apart from the list's own, so a
  /// card opened while filtering does not shift the list the filter hid.
  final Set<int> _filteredExpanded = <int>{};

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<Product>> _feeds =
      LinkedHashMap<String, DatabaseFeed<Product>>();

  int _rowsStamp = 0;

  /// Bumped whenever products arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every product on the phone: the list's, and every filtered answer's.
  /// The values a filter column offers are theirs.
  Iterable<Product> get knownProducts sync* {
    yield* base.rows;
    for (final DatabaseFeed<Product> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  ProductsFilterValues? _values;

  /// The values each filter column offers.
  ProductsFilterValues get values =>
      _values ??= ProductsFilterValues(this, _api);

  @override
  List<ProductsColumn> get filterColumns => ProductsColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(ProductsColumn column) => _filter.has(column);

  @override
  bool isChosen(ProductsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  ProductsFilterValues get filterValues => values;

  @override
  FilterRangeField? rangeFieldOf(ProductsColumn column) =>
      kProductRangeFields[column];

  @override
  FilterRange rangeOf(ProductsColumn column) => _filter.rangeOf(column);

  @override
  Future<void> setRange(ProductsColumn column, FilterRange range) =>
      setFilter(_filter.withRange(column, range));

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(ProductsFilter next) {
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
  Future<void> toggleFilter(ProductsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(ProductsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(ProductsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final ProductsFilterView view = ProductsFilterView._(
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
  /// already hold every product, or when the question is the list's own —
  /// no search — in which case every product already read is checked for
  /// free and every one read for the filter is one the list will not ask
  /// for again. Not while they are on their way in again, and not for a
  /// pull, which wants nothing old.
  DatabaseFeed<Product> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<Product> feed =
        _feeds.remove(key) ??
        DatabaseFeed<Product>(
          _api.productsPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kProductsFeedMemory) {
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

/// The products a filter lets through, found in the whole catalogue.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// code or the name — so the code, or else the name, goes to it when chosen
/// and is checked exactly here as well. Everything else — a category, a
/// span of prices, `ƏDV yoxdur` — is checked against each product read, a
/// page at a time as the list asks for more, the page growing while matches
/// are few. The catalogue is in no order a figure could stop early on, so
/// at its worst that is all of it: 593 products, ~354 KB — and nothing at
/// all once [ProductsController.readAll] has put every product on the
/// phone.
class ProductsFilterView
    implements ProductsRows, DatabaseFilteredRows<Product> {
  ProductsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final ProductsController _owner;

  final ProductsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<Product> _matches = <Product>[];

  @override
  late final List<Product> rows = UnmodifiableListView<Product>(_matches);

  DatabaseFeed<Product>? _feed;
  int _epoch = -1;

  /// How many of the feed's products have been checked.
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
    final DatabaseFeed<Product>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final ProductsColumn? searched = filter.searchColumn;
    for (final ProductsColumn column in filter.columns) {
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
      final ProductsColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<Product>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<Product> all = feed.rows;
    while (_examined < all.length) {
      final Product product = all[_examined++];
      if (filter.matches(product)) _matches.add(product);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<Product> feed = _feed!;
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
  void toggle(Product product) =>
      _owner._toggle(_owner._filteredExpanded, product);

  void _close() => _closed = true;
}
