import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/stock_controller.dart';
import 'package:guven_mobile/src/features/database/application/stock_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_page.dart';
import 'package:guven_mobile/src/features/database/domain/stock_filter.dart';
import 'package:guven_mobile/src/features/database/domain/stock_item.dart';

/// `Stok` asks the bridge for as little as it can: a page at a time, never
/// past the end — and a filter finds what it is asked for in the whole
/// table, reading only as far as it has to.
void main() {
  group('reading a row', () {
    test('the live row\'s fields', () {
      final StockItem item = StockItem.fromJson(<String, Object?>{
        'id': 770,
        'product_guid': '8e9c1e0c-7aa5-11f1-ac05-bc24113ee005',
        'product_code': 'NT000001046',
        'product_name': 'tullantı ',
        'warehouse_id': '51b2d535-22b2-11f1-abf9-bc24113ee005',
        'warehouse': 'Nərimanov Anbar ',
        'quantity': 4469.891,
        'balance_date': '2026-09-23',
        'baza_id': 18,
        'synced_at': '2026-09-23T17:04:50',
      })!;

      expect(item.id, 770);
      expect(item.code, 'NT000001046');
      expect(item.product, 'tullantı');
      expect(item.warehouse, 'Nərimanov Anbar');
      expect(item.quantity, 4469.891);
      expect(item.date, '2026-09-23');
    });

    test('a row with no id is left out, and still counts towards a page', () {
      final DatabasePage<StockItem> page = DatabasePage<StockItem>.fromJson(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 1, 'quantity': '2.5'},
            <String, Object?>{'product_code': 'NT1'},
          ],
          'total': 2,
        },
        StockItem.fromJson,
      );
      expect(page.rows, hasLength(1));
      expect(page.rows.single.quantity, 2.5);
      expect(page.received, 2);
      expect(page.total, 2);
    });
  });

  group('paging', () {
    test('twenty at a time, and never past the total', () async {
      final _Bridge bridge = _Bridge(count: 40);
      final StockController stock = bridge.controller();

      await stock.ensureLoaded();
      expect(bridge.requests.single.queryParameters, <String, String>{
        'page': '1',
        'page_size': '20',
      });
      expect(stock.items, hasLength(20));
      expect(stock.hasMore, isTrue);

      await stock.loadMore();
      expect(stock.items, hasLength(40));
      expect(stock.hasMore, isFalse);

      await stock.loadMore();
      await stock.ensureLoaded();
      expect(bridge.requests, hasLength(2));
    });

    test('only a pull goes back to the bridge', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      await stock.ensureLoaded();
      expect(bridge.requests, hasLength(1));

      await stock.refresh();
      expect(bridge.requests, hasLength(2));
      expect(stock.items, hasLength(20));
    });
  });

  group('the filter', () {
    test('a code goes to the bridge, and only that code comes back', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      bridge.requests.clear();

      // `NT000001003` is a substring of nothing else here, but the bridge's
      // search is a substring: `NT00000100` would find ten codes.
      await stock.setFilter(
        StockFilter.none.toggle(StockColumn.code, 'NT000001003'),
      );
      final StockFilterView view = stock.filtered!;
      expect(bridge.searches, <String>['NT000001003']);
      expect(view.rows.map((StockItem i) => i.code).toSet(), <String>{
        'NT000001003',
      });
      expect(view.hasMore, isFalse);
      // One column, and the bridge did all of it.
      expect(view.scans, isFalse);
    });

    test('a warehouse is searched for, and matched exactly', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      bridge.requests.clear();

      await stock.setFilter(
        StockFilter.none.toggle(StockColumn.warehouse, 'istehsalat'),
      );
      final StockFilterView view = stock.filtered!;
      await _drain(view);

      expect(bridge.searches.toSet(), <String>{'istehsalat'});
      // The bridge also finds `istehsalat qabı`, a product; the filter does
      // not.
      expect(
        bridge.found('istehsalat'),
        greaterThan(bridge.rowsIn('istehsalat')),
      );
      expect(view.rows, hasLength(bridge.rowsIn('istehsalat')));
      expect(
        view.rows.every((StockItem i) => i.warehouse == 'istehsalat'),
        isTrue,
      );
    });

    test('a warehouse 1C spelt with a trailing space is still found', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();

      // As the catalogue and every row read through [readString] give it.
      await stock.setFilter(
        StockFilter.none.toggle(StockColumn.warehouse, 'Nərimanov Anbar'),
      );
      await _drain(stock.filtered!);
      expect(
        stock.filtered!.rows,
        hasLength(bridge.rowsIn('Nərimanov Anbar ')),
      );
      expect(stock.filtered!.rows, isNotEmpty);
    });

    test(
      '"10-dan çox" reads the list\'s own pages and stops where they end',
      () async {
        final _Bridge bridge = _Bridge(count: 300, plenty: 30);
        final StockController stock = bridge.controller();
        await stock.ensureLoaded();
        bridge.requests.clear();

        await stock.setFilter(
          StockFilter.none.toggle(StockColumn.quantity, StockLevel.plenty.name),
        );
        final StockFilterView view = stock.filtered!;
        // The first twenty are the list's, already on the phone: no request.
        expect(bridge.requests, isEmpty);
        expect(view.rows, hasLength(20));
        expect(view.readOf, isNull);

        await _drain(view);
        expect(view.rows, hasLength(30));
        expect(view.rows.every((StockItem i) => i.quantity! > 10), isTrue);
        expect(view.hasMore, isFalse);
        // It stopped at the first small balance: nowhere near all 300 rows.
        expect(stock.items.length, lessThan(100));
        expect(bridge.searches, everyElement(isEmpty));
      },
    );

    test(
      '"10 və daha az" reads on until it finds them, for the list too',
      () async {
        final _Bridge bridge = _Bridge(count: 300, plenty: 30);
        final StockController stock = bridge.controller();
        await stock.ensureLoaded();

        await stock.setFilter(
          StockFilter.none.toggle(StockColumn.quantity, StockLevel.low.name),
        );
        final StockFilterView view = stock.filtered!;
        await _drain(view);
        expect(view.rows, hasLength(270));
        expect(view.readOf, 300);
        expect(view.rows.every((StockItem i) => i.quantity! <= 10), isTrue);

        // What it read was the list's own question: the list has it all now,
        // and letting go of the filter asks for nothing.
        expect(stock.items, hasLength(300));
        final int asked = bridge.requests.length;
        await stock.clearFilter();
        expect(stock.filtered, isNull);
        await stock.loadMore();
        expect(bridge.requests, hasLength(asked));
      },
    );

    test(
      'a day is checked row by row, with a search when there is one',
      () async {
        final _Bridge bridge = _Bridge();
        final StockController stock = bridge.controller();
        await stock.ensureLoaded();
        bridge.requests.clear();

        await stock.setFilter(
          StockFilter.none
              .toggle(StockColumn.date, '2026-09-18')
              .toggle(StockColumn.warehouse, 'Ulduz Anbarı'),
        );
        final StockFilterView view = stock.filtered!;
        expect(view.scans, isTrue);
        await _drain(view);

        expect(bridge.searches.toSet(), <String>{'Ulduz Anbarı'});
        expect(view.rows, isNotEmpty);
        expect(
          view.rows.every(
            (StockItem i) =>
                i.date == '2026-09-18' && i.warehouse == 'Ulduz Anbarı',
          ),
          isTrue,
        );
      },
    );

    test('letting go puts the list back as it was', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      await stock.loadMore();
      final List<StockItem> before = List<StockItem>.of(stock.items);

      await stock.toggleFilter(StockColumn.code, 'NT000001003');
      expect(stock.filterCount, 1);
      await stock.clearFilterColumn(StockColumn.code);

      expect(stock.filtered, isNull);
      expect(stock.isFiltered, isFalse);
      expect(stock.items, before);
    });

    test('a pull on the filtered list asks it again, from nothing', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      await stock.setFilter(
        StockFilter.none.toggle(StockColumn.quantity, StockLevel.plenty.name),
      );
      bridge.requests.clear();

      await stock.filtered!.refresh();
      // Not the list's pages: a question of its own, from page one.
      expect(bridge.requests.first.queryParameters['page'], '1');
      expect(stock.filtered!.rows, isNotEmpty);
    });
  });

  group('the values a column offers', () {
    test('Anbar: the catalogue, in its order', () async {
      final _Bridge bridge = _Bridge();
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();

      final StockFilterValues values = stock.values
        ..open(StockColumn.warehouse);
      await pumpEventQueue();
      expect(values.values.map((FilterValue v) => v.label).toList(), <String>[
        'Nizami (6-cı Paralel) Anbarı',
        'Nərimanov Anbar',
        'Ulduz Anbarı',
        'istehsalat',
      ]);
      // Kept as the bridge spells it.
      expect(values.values.first.value, 'Nizami (6-cı Paralel)  Anbarı');
    });

    test('Miqdar: the website\'s two colours', () {
      final StockController stock = _Bridge().controller();
      final StockFilterValues values = stock.values..open(StockColumn.quantity);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        '10-dan çox',
        '10 və daha az',
      ]);
    });

    test(
      'Tarix: the days the loaded rows were counted on, newest first',
      () async {
        final StockController stock = _Bridge().controller();
        await stock.ensureLoaded();
        final StockFilterValues values = stock.values..open(StockColumn.date);
        expect(values.values.map((FilterValue v) => v.value), <String>[
          '2026-09-23',
          '2026-09-18',
        ]);
      },
    );

    test('Kod: typing asks the bridge once it pauses', () async {
      final _Bridge bridge = _Bridge(count: 60);
      final StockController stock = bridge.controller();
      await stock.ensureLoaded();
      bridge.requests.clear();

      final StockFilterValues values = stock.values..open(StockColumn.code);
      values.search('105');
      values.search('1059');
      expect(values.isSearching, isTrue);
      // Nothing loaded carries it yet.
      expect(values.values, isEmpty);

      await Future<void>.delayed(
        kStockValueSearchDelay + const Duration(milliseconds: 150),
      );
      // Only what was typed last, once — and its code is offered though no
      // loaded row carries it.
      expect(bridge.searches, <String>['1059']);
      expect(values.isSearching, isFalse);
      expect(values.values.map((FilterValue v) => v.value), <String>[
        'NT000001059',
      ]);
    });
  });
}

/// Reads [view] to its end, the way a list scrolled to the bottom would.
Future<void> _drain(StockFilterView view) async {
  await view.ready;
  for (int i = 0; i < 100 && view.hasMore; i++) {
    await view.loadMore();
  }
}

/// The 1C bridge's stock table: [count] balances, the most first, in four
/// warehouses — one of them spelt with a trailing space, another with a
/// double one, as 1C spells them.
class _Bridge {
  _Bridge({this.count = 60, this.plenty = 25});

  final int count;

  /// How many balances are more than ten.
  final int plenty;

  static const List<String> warehouses = <String>[
    'istehsalat',
    'Nərimanov Anbar ',
    'Nizami (6-cı Paralel)  Anbarı',
    'Ulduz Anbarı',
  ];

  final List<Uri> requests = <Uri>[];

  /// The `search` of every stock request, `''` for none.
  List<String> get searches => <String>[
    for (final Uri uri in requests)
      if (uri.path.endsWith('/onec-data/stock/'))
        uri.queryParameters['search'] ?? '',
  ];

  StockController controller() {
    final StockController stock = StockController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(stock.dispose);
    return stock;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': 5000 - i,
    'product_code': 'NT${(1000 + i).toString().padLeft(9, '0')}',
    // A product whose name holds a warehouse's, as some do.
    'product_name': i % 9 == 4 ? 'istehsalat qabı' : 'Məhsul ${i % 7}',
    'warehouse': warehouses[i % warehouses.length],
    'quantity': i < plenty ? 500.0 - i * 3 : (count - i) * 10 / count,
    'balance_date': i % 5 == 3 ? '2026-09-18' : '2026-09-23',
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  List<Map<String, Object?>> _search(String? search) {
    if (search == null || search.isEmpty) return _rows;
    final String key = search.toLowerCase();
    return <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (<Object?>[
          row['product_code'],
          row['product_name'],
          row['warehouse'],
        ].any((Object? field) => '$field'.toLowerCase().contains(key)))
          row,
    ];
  }

  /// Rows the bridge's `search` finds for [search].
  int found(String search) => _search(search).length;

  /// Rows kept in [warehouse], spelt exactly.
  int rowsIn(String warehouse) => _rows
      .where((Map<String, Object?> r) => r['warehouse'] == warehouse)
      .length;

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final String path = request.url.path;
    if (path.endsWith('/warehouses/')) {
      // The catalogue's order: alphabetical, as Postgres sorts it.
      return _json(<String, Object?>{
        'data': <Object?>[
          for (final String name in <String>[
            'Nizami (6-cı Paralel)  Anbarı',
            'Nərimanov Anbar ',
            'Ulduz Anbarı',
            'istehsalat',
          ])
            <String, Object?>{'name': name},
        ],
        'total': 4,
      });
    }

    final Map<String, String> query = request.url.queryParameters;
    final List<Map<String, Object?>> found = _search(query['search']);
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
      'total': found.length,
      'table': 'product_stock',
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
