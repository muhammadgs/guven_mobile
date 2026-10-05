import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import 'database_feed.dart';

/// What a list of `Baza` cards needs from whatever feeds it: every row, or
/// only the ones a filter lets through.
abstract interface class DatabaseRows<T> {
  List<T> get rows;

  /// True once the first answer has settled, however it settled.
  bool get hasLoaded;

  /// True while the first answer is on its way.
  bool get isLoadingFirst;

  bool get isLoadingMore;

  /// Whether more rows may yet come.
  bool get hasMore;

  /// Why the first answer did not come.
  String? get error;

  /// Why a later one did not. While it is set nothing further is asked for
  /// on its own — [retryMore] clears it.
  String? get moreError;

  Future<void> refresh();
  Future<void> loadMore();
  Future<void> retryMore();
}

/// The rows a filter lets through, found in the whole of a 1C table rather
/// than in the pages read so far.
abstract interface class DatabaseFilteredRows<T> implements DatabaseRows<T> {
  /// Tells one filtered list from the next, so the one on screen can start
  /// at the top when the question changes.
  int get serial;

  /// Whether rows are being read and checked one by one — some column is one
  /// the bridge cannot apply, so matches may be few and far between.
  bool get scans;

  /// How many rows have been checked so far.
  int get read;

  /// How many there are to check, when that is known and worth saying.
  int? get readOf;
}

/// A whole `Baza` list: its rows, and — while a filter is on — the rows the
/// filter lets through, as a second list laid over the first.
abstract interface class DatabaseListSource<T>
    implements DatabaseRows<T>, Listenable {
  /// The filtered list, while there is a filter; null shows every row.
  DatabaseFilteredRows<T>? get filtered;

  /// Where the list was scrolled to, so that coming back to the page lands
  /// where it was left rather than at the top.
  double get scrollOffset;
  set scrollOffset(double value);

  /// Page one, unless it is already here or on its way.
  Future<void> ensureLoaded();
}

/// Pages through one of the bridge's lists, asking it as little as possible:
///
/// * one page at a time, and never past the last one — the answer's `total`
///   says where that is;
/// * nothing again when the page is left and come back to — only a pull
///   goes back to the network, the rule the task list and `Əsas panel`
///   keep;
/// * an answer to a question that has since been replaced — a page that
///   lands after a pull started over — is thrown away rather than mixed in;
/// * a page that failed is not asked for again until somebody says so, so a
///   phone without a signal is not asked again on every frame of a scroll.
///
/// What a page adds on top — cards that open, a filter — it adds through
/// [didRestart] and [onRowsChanged].
abstract class DatabaseListController<T> extends ChangeNotifier
    implements DatabaseListSource<T> {
  DatabaseListController(
    DatabasePageFetch<T> fetch, {
    required Object Function(T row) idOf,
    required this.pageSize,
  }) {
    base = DatabaseFeed<T>(
      fetch,
      idOf: idOf,
      unit: pageSize,
      onRows: onRowsChanged,
    );
  }

  /// How many rows one request asks for.
  final int pageSize;

  /// Every row of the list, read from the top.
  @protected
  late final DatabaseFeed<T> base;

  @override
  List<T> get rows => base.rows;

  /// Rows in all, when the bridge says.
  int? get total => base.total;

  @override
  bool get hasMore => !base.exhausted;

  bool _loaded = false;

  @override
  bool get hasLoaded => _loaded;

  bool _loadingFirst = false;

  /// True while page one is on its way — the first load, or a pull.
  @override
  bool get isLoadingFirst => _loadingFirst;

  bool _loadingMore = false;

  @override
  bool get isLoadingMore => _loadingMore;

  String? _error;

  /// Why page one did not come back — the first time, or on a pull. Null
  /// once one has.
  @override
  String? get error => _error;

  String? _moreError;

  @override
  String? get moreError => _moreError;

  @override
  double scrollOffset = 0;

  /// Bumped whenever the list starts over. An answer carrying an older
  /// number belongs to a question nobody is asking any more.
  int _generation = 0;

  @protected
  int get generation => _generation;

  bool _disposed = false;

  @protected
  bool get isDisposed => _disposed;

  /// Page one's request while it is out — the first load's, or a pull's.
  Future<void>? _firstPage;

  /// Page one, unless it is already here — and if it is on its way, the
  /// same request rather than a second one: whoever waits on this waits for
  /// the page that is coming.
  @override
  Future<void> ensureLoaded() {
    if (_loadingFirst) return _firstPage ?? Future<void>.value();
    if (_loaded) return Future<void>.value();
    return _firstPage = _loadFirstPage();
  }

  /// Starts the list over from page one: a pull.
  ///
  /// The old rows stay on screen until the new ones arrive, and stay for good
  /// if they do not.
  @override
  Future<void> refresh() => _firstPage = _loadFirstPage();

  Future<void> _loadFirstPage() async {
    final int generation = ++_generation;
    _loadingFirst = true;
    // Whatever page was on its way belongs to the list being replaced.
    _loadingMore = false;
    _moreError = null;
    notify();

    try {
      await base.restart();
      if (generation != _generation) return;
      _error = null;
      didRestart();
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _error = error.message;
    } finally {
      if (generation == _generation) {
        _loadingFirst = false;
        _loaded = true;
        notify();
      }
    }
  }

  /// Called once a pull's page one has replaced the list: whatever was built
  /// on the old rows is as old as they are.
  @protected
  void didRestart() {}

  /// The next page, if there is one and nothing is stopping it.
  ///
  /// Safe to call as often as the list likes — on every frame of a scroll —
  /// because it does nothing at all unless a request is actually due.
  @override
  Future<void> loadMore() async {
    if (!_loaded ||
        _loadingFirst ||
        _loadingMore ||
        base.exhausted ||
        _moreError != null ||
        base.rows.isEmpty) {
      return;
    }

    final int generation = _generation;
    _loadingMore = true;
    notify();

    try {
      await base.next(pageSize);
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _moreError = error.message;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        notify();
      }
    }
  }

  /// Asks for the page that failed, once more.
  @override
  Future<void> retryMore() {
    _moreError = null;
    return loadMore();
  }

  /// Called whenever rows arrive in [base] — or in any other feed a subclass
  /// hands this as its `onRows`.
  @protected
  void onRowsChanged() => notify();

  @protected
  void notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
