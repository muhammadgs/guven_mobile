import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/database_api.dart';
import '../domain/database_filter.dart';
import '../domain/database_page.dart';
import '../domain/product.dart';
import '../domain/products_filter.dart';
import '../presentation/database_format.dart';
import 'database_filter_source.dart';
import 'products_controller.dart';

/// How long typing has to pause before the bridge is asked.
const Duration kProductsValueSearchDelay = Duration(milliseconds: 300);

/// A query shorter than this is matched against what is on the phone only.
/// One letter finds half the catalogue; the second one is worth waiting for.
const int kProductsValueSearchMin = 2;

/// How many products a typed search reads for its values: the list shows
/// five or six at a time, and another letter narrows it further.
const int kProductsValueSearchSize = 20;

/// The values the open column of the `Məhsullar` filter offers, for what
/// has been typed into its search — each column its own, and all of them:
///
/// * `Kod`, `Məhsul` — the ones on the phone, and while typing the ones the
///   bridge finds, since its `search` reads codes and names;
/// * `Kateqoriya`, `Vahid`, `Növ` — every one in the catalogue. The bridge
///   cannot list them, so the first time one of them opens the rest of the
///   catalogue is read ([ProductsController.readAll]) and the column says
///   how far that has got rather than listing values that would still move
///   under a finger. Categories alphabetically, so a folder's children sit
///   under it; units and kinds by how many products have them;
/// * `Status` — `Aktiv` and `Deaktiv`;
/// * `ƏDV` — `ƏDV yoxdur`, beside its span. `Qiymət` and `Stok` are only a
///   span, and list nothing.
class ProductsFilterValues extends ChangeNotifier
    implements DatabaseFilterValues {
  ProductsFilterValues(this._owner, this._api) {
    _owner.addListener(_ownerChanged);
  }

  final ProductsController _owner;
  final DatabaseApi _api;

  ProductsColumn? _column;

  @override
  ProductsColumn? get column => _column;

  String _query = '';
  String get query => _query;

  List<FilterValue> _values = const <FilterValue>[];

  @override
  List<FilterValue> get values => _values;

  bool _searching = false;

  /// True while the open column waits for every product before it lists
  /// anything.
  bool _waiting = false;

  @override
  bool get isSearching => _searching || _waiting;

  @override
  String? get progress {
    if (!_waiting || !_owner.isReadingAll) return null;
    final int? total = _owner.total;
    final int read = _owner.rows.length;
    if (total == null || total == 0) return 'Məhsullar oxunur…';
    return '${formatCount(read)} / ${formatCount(total)} məhsul oxundu';
  }

  /// Shown first: what the column held when it opened, and what was chosen
  /// since. Nothing moves when a value is tapped — the list is only
  /// reordered when it is rebuilt for another reason.
  final List<String> _pinned = <String>[];

  Timer? _debounce;
  int _serial = 0;
  bool _disposed = false;

  /// What the bridge answered, by column and query, for the session.
  final Map<String, List<String>> _answers = <String, List<String>>{};

  final Map<ProductsColumn, List<String>> _local =
      <ProductsColumn, List<String>>{};
  int _localStamp = -1;

  @override
  void open(ProductsColumn column) {
    _column = column;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _pinned
      ..clear()
      ..addAll(_owner.filter.valuesOf(column));

    _waiting = false;
    if (column.needsEveryProduct && !_owner.hasEveryProduct) {
      // Returns at once if the reading is already under way.
      _owner.readAll();
      _waiting = _owner.isReadingAll;
    }
    _rebuild();
    notifyListeners();
  }

  @override
  void close() {
    _column = null;
    _query = '';
    _debounce?.cancel();
    _searching = false;
    _waiting = false;
    _values = const <FilterValue>[];
  }

  @override
  void remember(String value) {
    if (!_pinned.contains(value)) _pinned.add(value);
  }

  /// Narrows the list to [text], and asks the bridge once typing pauses.
  @override
  void search(String text) {
    final ProductsColumn? column = _column;
    if (column == null || text == _query) return;
    _query = text;
    _debounce?.cancel();
    _rebuild();

    final String query = text.trim();
    final bool ask =
        column.searchable &&
        !_owner.hasEveryProduct &&
        query.length >= kProductsValueSearchMin &&
        !_answers.containsKey(_answerKey(column, query));
    _searching = ask;
    if (ask) {
      _debounce = Timer(kProductsValueSearchDelay, () => _ask(column, query));
    }
    notifyListeners();
  }

  static String _answerKey(ProductsColumn column, String query) =>
      '${column.name}\u0000${filterSearchKey(query)}';

  /// What [product] says in [column], for the columns a value is read off.
  static String? _field(ProductsColumn column, Product product) =>
      switch (column) {
        ProductsColumn.code => product.code,
        ProductsColumn.name => product.name,
        ProductsColumn.category => product.category,
        ProductsColumn.unit => product.unit,
        ProductsColumn.type => product.type,
        _ => null,
      };

  /// The codes or names of the products the bridge finds for [query]. Its
  /// `search` reads both, so the answer is narrowed to the values that
  /// actually hold what was typed.
  Future<void> _ask(ProductsColumn column, String query) async {
    final int serial = ++_serial;
    try {
      final DatabasePage<Product> page = await _api.productsPage(
        page: 1,
        pageSize: kProductsValueSearchSize,
        search: query,
      );
      final String key = filterSearchKey(query);
      _answers[_answerKey(column, query)] = <String>[
        for (final Product product in page.rows)
          if (_field(column, product) case final String value
              when filterSearchKey(value).contains(key))
            value,
      ];
    } on ApiException {
      // What is on the phone is still listed, and the next letter typed asks
      // again.
    } finally {
      if (!_disposed && serial == _serial) {
        _searching = false;
        if (_column == column) _rebuild();
        notifyListeners();
      }
    }
  }

  /// The owner has moved on: rows arrived, or the catalogue has been read.
  void _ownerChanged() {
    final ProductsColumn? column = _column;
    if (column == null || !_waiting || _owner.isReadingAll) return;
    _waiting = false;
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    final ProductsColumn? column = _column;
    if (column == null || _waiting) {
      _values = const <FilterValue>[];
      return;
    }

    final String query = filterSearchKey(_query.trim());
    final Set<String> seen = <String>{};
    final List<FilterValue> out = <FilterValue>[];

    void add(String value) {
      final FilterValue item = _valueOf(column, value);
      if (query.isNotEmpty && !filterSearchKey(item.label).contains(query)) {
        return;
      }
      if (seen.add(_identity(column, value))) out.add(item);
    }

    if (query.isEmpty) _pinned.forEach(add);

    switch (column) {
      case ProductsColumn.code || ProductsColumn.name:
        _localValues(column).forEach(add);
        _answered(column)?.forEach(add);
      case ProductsColumn.category ||
          ProductsColumn.unit ||
          ProductsColumn.type:
        _localValues(column).forEach(add);
      case ProductsColumn.status:
        for (final ProductStatus status in ProductStatus.values) {
          add(status.name);
        }
      case ProductsColumn.vat:
        add(kNoVatValue);
      case ProductsColumn.price || ProductsColumn.stock:
        break;
    }
    _values = List<FilterValue>.unmodifiable(out);
  }

  /// The bridge's answer to what is typed — or, while that is on its way,
  /// to the longest start of it already asked, narrowed here.
  List<String>? _answered(ProductsColumn column) {
    final String query = _query.trim();
    for (int end = query.length; end >= kProductsValueSearchMin; end--) {
      final List<String>? answer =
          _answers[_answerKey(column, query.substring(0, end))];
      if (answer != null) return answer;
    }
    return null;
  }

  static String _identity(ProductsColumn column, String value) =>
      switch (column) {
        ProductsColumn.status || ProductsColumn.vat => value,
        _ => filterKey(value),
      };

  static FilterValue _valueOf(ProductsColumn column, String value) =>
      switch (column) {
        ProductsColumn.status => FilterValue(
          value,
          ProductStatus.byName(value)?.label ?? value,
        ),
        ProductsColumn.vat => FilterValue(
          value,
          value == kNoVatValue ? kNoVatLabel : value,
        ),
        _ => FilterValue(value, tidySpaces(value)),
      };

  /// Every value of [column] among the products on the phone: codes and
  /// names in the list's order, categories alphabetically, units and kinds
  /// most common first.
  List<String> _localValues(ProductsColumn column) {
    if (_localStamp != _owner.rowsStamp) {
      _local.clear();
      _localStamp = _owner.rowsStamp;
    }
    return _local.putIfAbsent(column, () {
      final Map<String, String> first = <String, String>{};
      final Map<String, int> counts = <String, int>{};
      for (final Product product in _owner.knownProducts) {
        final String? value = _field(column, product);
        if (value == null) continue;
        final String identity = _identity(column, value);
        if (identity.isEmpty) continue;
        first.putIfAbsent(identity, () => value);
        counts[identity] = (counts[identity] ?? 0) + 1;
      }
      final List<String> identities = first.keys.toList();
      switch (column) {
        case ProductsColumn.category:
          identities.sort();
        case ProductsColumn.unit || ProductsColumn.type:
          // Stable: equally common values keep the order they were met in.
          final Map<String, int> met = <String, int>{
            for (int i = 0; i < identities.length; i++) identities[i]: i,
          };
          identities.sort((String a, String b) {
            final int byCount = counts[b]!.compareTo(counts[a]!);
            return byCount != 0 ? byCount : met[a]!.compareTo(met[b]!);
          });
        default:
          break;
      }
      return <String>[
        for (final String identity in identities) first[identity]!,
      ];
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _owner.removeListener(_ownerChanged);
    super.dispose();
  }
}
