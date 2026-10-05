import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/products_controller.dart';
import 'package:guven_mobile/src/features/database/application/products_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/product.dart';
import 'package:guven_mobile/src/features/database/domain/products_filter.dart';

/// `Məhsullar` asks the bridge for as little as it can — and its filter
/// finds what it is asked for in the whole catalogue: a code through the
/// bridge, a price, a stock or a VAT rate between a minimum and a maximum on
/// the phone.
void main() {
  group('reading a product', () {
    test('the live row\'s fields', () {
      // Product 1 as the bridge answered it on 2026-09-29.
      final Product product = Product.fromJson(<String, Object?>{
        'id': 1,
        'onec_guid': 'a75d31cb-8828-11f1-ac06-bc24113ee005',
        'code': 'NT000001093',
        'barcode': null,
        'name': '20/20 Şəffaf paket (1696)',
        'price': 0,
        'purchase_price': 0,
        'wholesale_price': 0,
        'stock_qty': 77.371,
        'unit': 'kq',
        'category': 'NM MENU',
        'description': null,
        'is_active': true,
        'article': '',
        'product_type': 'xammal',
        'base_unit': 'kq',
        'vat_rate': 0.0,
        'folder_id': 'b3a9288c-4c6c-11f1-abff-bc24113ee005',
        'folder_name': 'NM MENU',
        'folder_path': 'NM MENU',
        'name_full': '',
        'baza_id': 18,
      })!;

      expect(product.id, 1);
      expect(product.code, 'NT000001093');
      expect(product.name, '20/20 Şəffaf paket (1696)');
      expect(product.category, 'NM MENU');
      expect(product.price, 0);
      expect(product.unit, 'kq');
      expect(product.stock, 77.371);
      expect(product.type, 'xammal');
      expect(product.hasNoVat, isTrue);
      expect(product.isActive, isTrue);
      // A list row carries no warehouses: they are the product's own
      // answer's.
      expect(product.balances, isNull);
    });

    test('the category is the whole path, as the design prints it', () {
      final Product product = Product.fromJson(<String, Object?>{
        'id': 7,
        'category': 'SOUSLAR',
        'folder_name': 'SOUSLAR',
        'folder_path': 'NM MENU / SOUSLAR',
      })!;
      expect(product.category, 'NM MENU / SOUSLAR');
    });

    test('the product\'s own answer brings its warehouses', () {
      final Product row = Product.fromJson(<String, Object?>{
        'id': 5,
        'stock_qty': 87,
      })!;
      final Product detail = Product.fromJson(<String, Object?>{
        'status': 'active',
        'warehouses': <Object?>[
          <String, Object?>{
            'warehouse_id': 'c8c991c0-49d9-11f1-abff-bc24113ee005',
            'warehouse': 'Badamdar Anbar',
            'quantity': 2.0,
            'balance_date': '2026-09-23',
          },
          <String, Object?>{
            'warehouse': 'istehsalat',
            'quantity': 82.0,
            'balance_date': '2026-09-23',
          },
        ],
      }, knownId: 5)!;

      final Product merged = row.mergedWith(detail);
      expect(merged.stock, 87);
      expect(merged.balances, hasLength(2));
      expect(merged.balances!.last.warehouse, 'istehsalat');
      expect(merged.balances!.last.quantity, 82);
      expect(merged.balances!.first.date, '2026-09-23');
    });

    test('only an explicit `false` is deactivated', () {
      expect(Product.fromJson(<String, Object?>{'id': 1})!.isActive, isTrue);
      expect(
        Product.fromJson(<String, Object?>{
          'id': 1,
          'is_active': false,
        })!.isActive,
        isFalse,
      );
    });
  });

  group('a span', () {
    test('either end may be open, and a wrong way round is turned', () {
      const FilterRange any = FilterRange.any;
      expect(any.isEmpty, isTrue);
      expect(any.contains(-1e9), isTrue);

      const FilterRange from = FilterRange(min: 10);
      expect(from.contains(10), isTrue);
      expect(from.contains(9.99), isFalse);

      const FilterRange backwards = FilterRange(min: 50, max: 10);
      expect(backwards.ordered, const FilterRange(min: 10, max: 50));
      expect(backwards.contains(20), isTrue);
      expect(backwards.contains(60), isFalse);

      // What a sum in 1C leaves a hair off is still the figure typed.
      expect(const FilterRange(max: 15.6).contains(15.600000000000001), isTrue);
    });

    test('a figure typed with a point, a comma, or not yet a figure', () {
      expect(parseFilterFigure('15.6'), 15.6);
      expect(parseFilterFigure('15,6'), 15.6);
      expect(parseFilterFigure(' 15 '), 15);
      expect(parseFilterFigure('-41'), -41);
      expect(parseFilterFigure(''), isNull);
      expect(parseFilterFigure('-'), isNull);
      expect(parseFilterFigure('.'), isNull);

      expect(writeFilterFigure(15), '15');
      expect(writeFilterFigure(15.6), '15.6');
      expect(writeFilterFigure(-41), '-41');
    });
  });

  group('the filter\'s rules', () {
    const Product noVat = Product(id: 1, price: 15.6, stock: -3, vat: 0);
    const Product withVat = Product(id: 2, price: 145, stock: 26, vat: 18);
    const Product blank = Product(id: 3);

    test('a price, a stock or a rate nobody gave is 0, as the website '
        'reads it', () {
      final ProductsFilter upTo = ProductsFilter.none.withRange(
        ProductsColumn.price,
        const FilterRange(max: 0),
      );
      expect(upTo.matches(blank), isTrue);
      expect(upTo.matches(noVat), isFalse);
    });

    test('a span and `ƏDV yoxdur` let go of one another', () {
      final ProductsFilter span = ProductsFilter.none.withRange(
        ProductsColumn.vat,
        const FilterRange(min: 10),
      );
      expect(span.matches(withVat), isTrue);
      expect(span.matches(noVat), isFalse);

      final ProductsFilter none = span.toggle(ProductsColumn.vat, kNoVatValue);
      expect(none.rangeOf(ProductsColumn.vat).isEmpty, isTrue);
      expect(none.matches(noVat), isTrue);
      expect(none.matches(blank), isTrue);
      expect(none.matches(withVat), isFalse);
      expect(none.columnCount, 1);

      // The fields emptied when `ƏDV yoxdur` was chosen do not take it back.
      expect(none.withRange(ProductsColumn.vat, FilterRange.any), none);

      final ProductsFilter again = none.withRange(
        ProductsColumn.vat,
        const FilterRange(max: 5),
      );
      expect(again.valueOf(ProductsColumn.vat), isNull);
      expect(again.matches(noVat), isTrue);
      expect(again.matches(withVat), isFalse);
    });

    test('every column counts once on the funnel, and `Hamısı` lets go', () {
      final ProductsFilter filter = ProductsFilter.none
          .withRange(ProductsColumn.price, const FilterRange(min: 1))
          .withRange(ProductsColumn.stock, const FilterRange(max: 0))
          .toggle(ProductsColumn.status, ProductStatus.active.name);
      expect(filter.columnCount, 3);
      expect(filter.columns, <ProductsColumn>[
        ProductsColumn.price,
        ProductsColumn.stock,
        ProductsColumn.status,
      ]);
      // Priced, short, active: the first; the second is not short.
      expect(filter.matches(noVat), isTrue);
      expect(filter.matches(withVat), isFalse);
      expect(
        filter.cleared(ProductsColumn.stock).cleared(ProductsColumn.price),
        ProductsFilter.none.toggle(
          ProductsColumn.status,
          ProductStatus.active.name,
        ),
      );
    });

    test('a category is matched with its spacing set aside', () {
      final ProductsFilter filter = ProductsFilter.none.toggle(
        ProductsColumn.category,
        'NM MENU / PARÇALANAN YERLİ  (P)',
      );
      expect(
        filter.matches(
          const Product(id: 1, category: 'NM MENU / PARÇALANAN YERLİ (P)'),
        ),
        isTrue,
      );
    });
  });

  group('the controller', () {
    test('twenty at a time, and a span is looked for in the whole '
        'catalogue', () async {
      final _Bridge bridge = _Bridge();
      final ProductsController products = bridge.controller();
      await products.ensureLoaded();
      expect(products.products, hasLength(20));
      bridge.requests.clear();

      // Only the last products are this dear.
      await products.setRange(
        ProductsColumn.price,
        const FilterRange(min: 1000),
      );
      final ProductsFilterView view = products.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((Product p) => p.id), <int>[98, 99, 100]);
      expect(view.scans, isTrue);
      expect(view.readOf, 100);
      // Every product read was the list's own, and the page grew while
      // nothing matched.
      expect(products.products, hasLength(100));
      expect(bridge.searches, isEmpty);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '40', '80'],
      );
    });

    test('a code goes to the bridge, and only that code comes back', () async {
      final _Bridge bridge = _Bridge();
      final ProductsController products = bridge.controller();
      await products.ensureLoaded();

      await products.toggleFilter(ProductsColumn.code, 'NT000001050');
      final ProductsFilterView view = products.filtered!;
      expect(bridge.searches, <String>['NT000001050']);
      expect(view.rows.map((Product p) => p.code), <String>['NT000001050']);
      expect(view.scans, isFalse);
    });

    test('an open card asks for its product once; a pull forgets it', () async {
      final _Bridge bridge = _Bridge();
      final ProductsController products = bridge.controller();
      await products.ensureLoaded();
      final Product first = products.products.first;

      products.toggle(first);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(products.isExpanded(first.id), isTrue);
      expect(products.view(first).balances, hasLength(1));
      products.toggle(first);
      products.toggle(first);
      expect(bridge.details, <int>[first.id]);

      await products.refresh();
      expect(products.isExpanded(first.id), isFalse);
      expect(products.view(first).balances, isNull);
    });

    test('a category opens onto the whole catalogue, read once', () async {
      final _Bridge bridge = _Bridge();
      final ProductsController products = bridge.controller();
      await products.ensureLoaded();
      final ProductsFilterValues values = products.values;

      values.open(ProductsColumn.category);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 100 məhsul oxundu');
      while (products.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(products.hasEveryProduct, isTrue);
      expect(values.isSearching, isFalse);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'KOLBASA',
        'NM MENU / SOUSLAR',
        'QEYRİ QİDA',
      ]);

      // The other columns of words list theirs at once now.
      values.close();
      values.open(ProductsColumn.unit);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'əd',
        'kq',
      ]);
      final int asked = bridge.requests.length;
      values.open(ProductsColumn.type);
      expect(bridge.requests, hasLength(asked));
    });

    test('Status offers both, ƏDV offers `ƏDV yoxdur`, a price nothing', () {
      final ProductsController products = _Bridge().controller();
      final ProductsFilterValues values = products.values;

      values.open(ProductsColumn.status);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Aktiv',
        'Deaktiv',
      ]);
      values.open(ProductsColumn.vat);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        kNoVatLabel,
      ]);
      values.open(ProductsColumn.price);
      expect(values.values, isEmpty);
      expect(
        products.rangeFieldOf(ProductsColumn.price)!.minHint,
        'Min qiymət',
      );
      expect(products.rangeFieldOf(ProductsColumn.stock)!.signed, isTrue);
      expect(products.rangeFieldOf(ProductsColumn.category), isNull);
    });
  });
}

/// The catalogue: a hundred products, lowest id first, the last three the
/// dearest.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  /// The id of every product asked for on its own.
  final List<int> details = <int>[];

  static const int count = 100;

  ProductsController controller() {
    final ProductsController products = ProductsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(products.dispose);
    return products;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': i + 1,
    'code': 'NT${(1000 + i).toString().padLeft(9, '0')}',
    'name': 'Məhsul $i',
    'price': i >= count - 3 ? 1000.0 + i : i * 1.5,
    'stock_qty': i * 2.0,
    'unit': i.isEven ? 'əd' : 'kq',
    'folder_path': <String>[
      'QEYRİ QİDA',
      'NM MENU / SOUSLAR',
      'KOLBASA',
    ][i % 3],
    'product_type': i.isEven ? 'xammal' : 'Mal',
    'vat_rate': i % 4 == 0 ? 18.0 : 0.0,
    'is_active': true,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final String path = request.url.path;
    final RegExpMatch? one = RegExp(r'/products/(\d+)$').firstMatch(path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      return _json(<String, Object?>{
        ..._rows[id - 1],
        'warehouses': <Object?>[
          <String, Object?>{'warehouse': 'istehsalat', 'quantity': 4.0},
        ],
      });
    }

    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['code']} ${row['name']}'.toLowerCase().contains(
              search.toLowerCase(),
            ))
          row,
    ];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
      'total': found.length,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
