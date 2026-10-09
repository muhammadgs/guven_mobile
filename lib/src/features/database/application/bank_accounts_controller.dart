import 'dart:collection';
import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/bank_account.dart';
import '../domain/bank_accounts_filter.dart';
import 'bank_accounts_filter_values.dart';
import 'database_feed.dart';
import 'database_filter_source.dart';
import 'database_list_controller.dart';

/// How many accounts one request asks for: the other lists' page. The
/// whole catalogue was ten accounts, ~3 KB (read 2026-10-08).
const int kBankAccountsPageSize = 20;

/// The largest page read when the whole catalogue is wanted at once
/// ([BankAccountsController.readAll]): the bridge's own ceiling — one
/// request for any company's accounts.
const int kBankAccountsReadAllPageMax = 500;

/// How many opened accounts' own answers are remembered. Past this the
/// oldest is forgotten and asked for again should its card open again.
const int kBankAccountDetailMemory = 150;

/// How many filtered answers are kept, with the accounts read for them, for
/// when the filter comes back to one.
const int kBankAccountsFeedMemory = 8;

/// A list of account cards — every account, or only the ones a filter lets
/// through — whose cards open, each list its own.
abstract interface class BankAccountsRows implements DatabaseRows<BankAccount> {
  bool isExpanded(int id);
  void toggle(BankAccount account);
}

/// Drives `Bank Hesabları`: the accounts loaded so far, the next page, the
/// figures behind the cards that have been opened — and the filter.
///
/// The paging is every `Baza` list's ([DatabaseListController]). On top of
/// it:
///
/// * an open card shows how many payments went through the account, what
///   came in, what went out and the balance, which only the account's own
///   answer carries. Money moves, so that is asked for every time the card
///   opens, while the card shows what was last known of it;
/// * the filter. The bridge can search a code, a name or a number and
///   nothing else, so everything else is checked against the accounts
///   read. The catalogue is small, so the first time a column whose values
///   can only be known by reading all of it opens (`Bank`, `Valyuta`), the
///   rest is read into the list's own pages ([readAll]); from then on every
///   value is listed and every filter is answered on the phone.
///
/// A filter never touches the list it narrows. It is a second list
/// ([filtered]) with its own open cards and its own place in the scroll, so
/// letting go of it puts the reader back exactly where they were.
class BankAccountsController extends DatabaseListController<BankAccount>
    implements BankAccountsRows, DatabaseFilterSource {
  /// [pageSize] is the seam the tests reach through.
  BankAccountsController(this._api, {int pageSize = kBankAccountsPageSize})
    : super(_api.bankAccountsPage, idOf: _idOf, pageSize: pageSize);

  final DatabaseApi _api;

  static Object _idOf(BankAccount account) => account.id;

  /// Every account loaded so far, in the bridge's order — by name.
  List<BankAccount> get accounts => rows;

  final Set<int> _expanded = <int>{};
  final LinkedHashMap<int, BankAccount> _details =
      LinkedHashMap<int, BankAccount>();
  final Set<int> _detailsLoading = <int>{};

  /// Accounts whose answer is known and being asked for again.
  final Set<int> _detailsRefreshing = <int>{};
  final Map<int, String> _detailErrors = <int, String>{};

  /// A pull's page one has replaced the list: opened cards shut, their
  /// accounts' answers are forgotten, and so is everything read for the
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

  /// Opens or shuts a card, and asks for its account's own answer every
  /// time it is opened.
  @override
  void toggle(BankAccount account) => _toggle(_expanded, account);

  void _toggle(Set<int> open, BankAccount account) {
    if (!open.remove(account.id)) {
      open.add(account.id);
      loadDetail(account.id, again: true);
    }
    notify();
  }

  /// What a card shows: its row, with the account's own answer laid over it
  /// once that is known.
  BankAccount view(BankAccount account) {
    final BankAccount? detail = _details[account.id];
    return detail == null ? account : account.mergedWith(detail);
  }

  /// True while the account's own answer is on its way and nothing of it is
  /// known yet. Asking again for one already known is not loading: the card
  /// goes on showing what it knows.
  bool isDetailLoading(int id) => _detailsLoading.contains(id);

  /// Why the account's own answer could not be read, or null.
  String? detailError(int id) => _detailErrors[id];

  /// Asks for an account's own answer unless it is on its way — or, unless
  /// [again], already here.
  ///
  /// Asked [again], a known answer stays on the card until the new one
  /// replaces it, and stays there if the new one cannot be read: an older
  /// balance is still better than an error over it.
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
      final BankAccount detail = await _api.bankAccount(id);
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
  /// once there are more than [kBankAccountDetailMemory].
  void _remember(int id, BankAccount detail) {
    _details
      ..remove(id)
      ..[id] = detail;
    if (_details.length <= kBankAccountDetailMemory) return;
    for (final int old in _details.keys) {
      if (!_expanded.contains(old) && !_filteredExpanded.contains(old)) {
        _details.remove(old);
        return;
      }
    }
  }

  // ── Every account ───────────────────────────────────────────────────────

  bool _readingAll = false;

  /// True while the rest of the catalogue is being read.
  bool get isReadingAll => _readingAll;

  String? _readAllError;

  /// Why reading the rest of the catalogue stopped short, or null.
  String? get readAllError => _readAllError;

  /// Whether every account is on the phone: the list's own pages reach the
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
        await base.next(kBankAccountsReadAllPageMax);
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

  BankAccountsFilter _filter = BankAccountsFilter.none;

  /// What the list is narrowed to.
  BankAccountsFilter get filter => _filter;

  BankAccountsFilterView? _view;

  /// The filtered list, while there is a filter; null shows every account.
  @override
  BankAccountsFilterView? get filtered => _view;

  int _viewSerial = 0;

  /// Cards opened in a filtered list. Kept apart from the list's own, so a
  /// card opened while filtering does not shift the list the filter hid.
  final Set<int> _filteredExpanded = <int>{};

  /// Filtered answers, by their `search`, most recently used last.
  final LinkedHashMap<String, DatabaseFeed<BankAccount>> _feeds =
      LinkedHashMap<String, DatabaseFeed<BankAccount>>();

  int _rowsStamp = 0;

  /// Bumped whenever accounts arrive, anywhere.
  int get rowsStamp => _rowsStamp;

  /// Every account on the phone: the list's, and every filtered answer's.
  /// The values a filter column offers are theirs.
  Iterable<BankAccount> get knownAccounts sync* {
    yield* base.rows;
    for (final DatabaseFeed<BankAccount> feed in _feeds.values) {
      yield* feed.rows;
    }
  }

  BankAccountsFilterValues? _values;

  /// The values each filter column offers.
  BankAccountsFilterValues get values =>
      _values ??= BankAccountsFilterValues(this, _api);

  @override
  List<BankAccountsColumn> get filterColumns => BankAccountsColumn.values;

  @override
  bool get isFiltered => _filter.isNotEmpty;

  @override
  int get filterCount => _filter.columnCount;

  @override
  bool narrows(BankAccountsColumn column) => _filter.has(column);

  @override
  bool isChosen(BankAccountsColumn column, String value) =>
      _filter.isChosen(column, value);

  @override
  BankAccountsFilterValues get filterValues => values;

  /// Narrows the list to [next] — or, when it is empty, lets it go and puts
  /// the reader back where they were. Completes once the first answer to the
  /// new filter has settled.
  Future<void> setFilter(BankAccountsFilter next) {
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
  Future<void> toggleFilter(BankAccountsColumn column, String value) =>
      setFilter(_filter.toggle(column, value));

  @override
  Future<void> clearFilterColumn(BankAccountsColumn column) =>
      setFilter(_filter.cleared(column));

  @override
  Future<void> clearFilter() => setFilter(BankAccountsFilter.none);

  /// Asks the filter again from the start.
  ///
  /// [fresh] is a pull: nothing read before it is trusted, the list's own
  /// pages included.
  Future<void> _replan({required bool fresh}) {
    _view?._close();
    final BankAccountsFilterView view = BankAccountsFilterView._(
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
  /// already hold every account, or when the question is the list's own —
  /// no search. Not while they are on their way in again, and not for a
  /// pull, which wants nothing old.
  DatabaseFeed<BankAccount> _feedFor(String? search, {required bool fresh}) {
    if (!fresh &&
        hasLoaded &&
        !isLoadingFirst &&
        (base.exhausted || search == null)) {
      return base;
    }
    final String key = search ?? '';
    final DatabaseFeed<BankAccount> feed =
        _feeds.remove(key) ??
        DatabaseFeed<BankAccount>(
          _api.bankAccountsPage,
          idOf: _idOf,
          search: search,
          unit: pageSize,
          onRows: onRowsChanged,
        );
    _feeds[key] = feed;
    while (_feeds.length > kBankAccountsFeedMemory) {
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

/// The accounts a filter lets through, found in the whole catalogue.
///
/// The bridge narrows an answer one way only — `search`, a substring of the
/// code, the name or the number — so the most telling of those that is
/// chosen goes to it, and is checked exactly here as well. Everything else
/// — a bank, a currency, a kind, a status — is checked against each account
/// read, a page at a time as the list asks for more, the page growing while
/// matches are few.
class BankAccountsFilterView
    implements BankAccountsRows, DatabaseFilteredRows<BankAccount> {
  BankAccountsFilterView._(
    this._owner,
    this.filter,
    this.serial, {
    required this.fresh,
  }) : _scanSize = _owner.pageSize;

  final BankAccountsController _owner;

  final BankAccountsFilter filter;

  @override
  final int serial;

  /// Set by a pull: nothing read before it is trusted.
  final bool fresh;

  final List<BankAccount> _matches = <BankAccount>[];

  @override
  late final List<BankAccount> rows = UnmodifiableListView<BankAccount>(
    _matches,
  );

  DatabaseFeed<BankAccount>? _feed;
  int _epoch = -1;

  /// How many of the feed's accounts have been checked.
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
    final DatabaseFeed<BankAccount>? feed = _feed;
    if (feed == null) return false;
    return !feed.exhausted || _examined < feed.rows.length;
  }

  @override
  bool get scans {
    final BankAccountsColumn? searched = filter.searchColumn;
    for (final BankAccountsColumn column in filter.columns) {
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
      final BankAccountsColumn? searched = filter.searchColumn;
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
    final DatabaseFeed<BankAccount>? feed = _feed;
    if (feed == null || _closed) return;
    if (feed.epoch != _epoch) {
      _epoch = feed.epoch;
      _examined = 0;
      _matches.clear();
    }

    final List<BankAccount> all = feed.rows;
    while (_examined < all.length) {
      final BankAccount account = all[_examined++];
      if (filter.matches(account)) _matches.add(account);
    }
  }

  Future<void> _fetch() async {
    final DatabaseFeed<BankAccount> feed = _feed!;
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
  void toggle(BankAccount account) =>
      _owner._toggle(_owner._filteredExpanded, account);

  void _close() => _closed = true;
}
