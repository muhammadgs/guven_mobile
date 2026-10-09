import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/warehouses_controller.dart';
import 'package:guven_mobile/src/features/database/application/warehouses_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/warehouse.dart';
import 'package:guven_mobile/src/features/database/domain/warehouses_filter.dart';

/// `Anbarlar` reads a warehouse the way the website does — a blank code as
/// none, the kind in the website's words — and its filter finds what it is
/// asked for in the whole catalogue: a name through the bridge, a code, a
/// kind or a status on the phone. `Kod` is offered only once a warehouse
/// has one.
void main() {
  group('reading a warehouse', () {
    test('the live row\'s fields', () {
      // Warehouse 4 as the bridge answered on 2026-10-09.
      final Warehouse warehouse = Warehouse.fromJson(<String, Object?>{
        'id': 4,
        'onec_guid': '301d21fb-0646-11f1-abf7-bc24113ee005',
        'code': '',
        'name': 'Nərimanov Anbar ',
        'warehouse_type': 'default',
        'is_active': true,
        'created_at': '2026-09-18T13:46:20.169681',
        'updated_at': '2026-09-18T13:46:20.169681',
        'baza_id': 18,
      })!;

      expect(warehouse.id, 4);
      // Blank, so none: the card has no line for it.
      expect(warehouse.code, isNull);
      expect(warehouse.name, 'Nərimanov Anbar');
      expect(warehouse.type, 'default');
      expect(warehouse.typeLabel, 'Standart');
      expect(warehouse.active, isTrue);
    });

    test('a kind in the website\'s words, and a code when 1C gives one', () {
      Warehouse kind(Object? type) => Warehouse.fromJson(<String, Object?>{
        'id': 1,
        'code': 'ANB001',
        'warehouse_type': type,
      })!;

      expect(kind('wholesale').typeLabel, 'Topdansatış');
      expect(kind('retail').typeLabel, 'Pərakəndə');
      expect(kind('virtual').typeLabel, 'Virtual');
      // A kind the website has no word for is shown as 1C writes it; none
      // at all is `Standart`.
      expect(kind('tranzit').typeLabel, 'tranzit');
      expect(kind('').typeLabel, 'Standart');
      expect(kind(null).typeLabel, 'Standart');
      expect(kind(null).code, 'ANB001');

      // And with no id, no warehouse.
      expect(Warehouse.fromJson(<String, Object?>{'name': 'Anbar'}), isNull);
    });
  });

  group('the filter\'s rules', () {
    const Warehouse nizami = Warehouse(
      id: 5,
      name: 'Nizami (6-cı Paralel)  Anbarı',
      type: 'default',
      active: true,
    );
    const Warehouse shop = Warehouse(
      id: 20,
      code: 'ANB020',
      name: 'Mağaza anbarı',
      type: 'retail',
      active: false,
    );

    WarehousesFilter only(WarehousesColumn column, String value) =>
        WarehousesFilter.none.toggle(column, value);

    test('a value in every column', () {
      expect(only(WarehousesColumn.code, 'ANB020').matches(shop), isTrue);
      // A warehouse with no code matches no code.
      expect(only(WarehousesColumn.code, 'ANB020').matches(nizami), isFalse);
      // A name is matched with its spacing set aside.
      expect(
        only(
          WarehousesColumn.name,
          'Nizami (6-cı Paralel) Anbarı',
        ).matches(nizami),
        isTrue,
      );
      // A kind is matched in the card's words.
      expect(only(WarehousesColumn.type, 'Standart').matches(nizami), isTrue);
      expect(only(WarehousesColumn.type, 'Pərakəndə').matches(shop), isTrue);
      expect(only(WarehousesColumn.type, 'Standart').matches(shop), isFalse);
      expect(only(WarehousesColumn.status, 'active').matches(nizami), isTrue);
      expect(only(WarehousesColumn.status, 'inactive').matches(shop), isTrue);
      expect(only(WarehousesColumn.status, 'active').matches(shop), isFalse);
    });

    test('only a name goes to the bridge', () {
      final WarehousesFilter filter = WarehousesFilter.none
          .toggle(WarehousesColumn.code, 'ANB020')
          .toggle(WarehousesColumn.type, 'Pərakəndə')
          .toggle(WarehousesColumn.status, 'inactive');
      expect(filter.searchColumn, isNull);
      expect(
        filter.toggle(WarehousesColumn.name, 'Mağaza anbarı').searchColumn,
        WarehousesColumn.name,
      );
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(
        filter.toggle(WarehousesColumn.status, 'inactive').columns,
        <WarehousesColumn>[WarehousesColumn.code, WarehousesColumn.type],
      );
      expect(
        filter
            .cleared(WarehousesColumn.code)
            .cleared(WarehousesColumn.type)
            .cleared(WarehousesColumn.status),
        WarehousesFilter.none,
      );
    });
  });

  group('the controller', () {
    test('twenty at a time, and a status is looked for in the whole '
        'catalogue', () async {
      final _Bridge bridge = _Bridge();
      final WarehousesController warehouses = bridge.controller();
      await warehouses.ensureLoaded();
      expect(warehouses.warehouses, hasLength(20));
      // The bridge's order: by name.
      expect(warehouses.warehouses.first.id, 1);
      bridge.requests.clear();

      // Only every seventh is switched off.
      await warehouses.toggleFilter(WarehousesColumn.status, 'inactive');
      final WarehousesFilterView view = warehouses.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((Warehouse w) => w.id), <int>[7, 14, 21, 28]);
      expect(view.scans, isTrue);
      expect(view.readOf, 30);
      // Every warehouse read was the list's own.
      expect(warehouses.warehouses, hasLength(30));
      expect(bridge.searches, isEmpty);
    });

    test('a name goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final WarehousesController warehouses = bridge.controller();
      await warehouses.ensureLoaded();

      await warehouses.toggleFilter(WarehousesColumn.name, 'Nərimanov Anbar');
      final WarehousesFilterView view = warehouses.filtered!;
      expect(bridge.searches, <String>['Nərimanov Anbar']);
      // `Nərimanov Anbar 2` holds the words too, but is another warehouse.
      expect(view.rows.map((Warehouse w) => w.id), <int>[10]);
      expect(view.scans, isFalse);

      // Let go, the list is the list again.
      await warehouses.clearFilter();
      expect(warehouses.filtered, isNull);
      expect(warehouses.warehouses, hasLength(20));
    });

    test('a code is never sent to the bridge: it is looked for on the '
        'phone', () async {
      final _Bridge bridge = _Bridge();
      final WarehousesController warehouses = bridge.controller();
      await warehouses.ensureLoaded();

      await warehouses.toggleFilter(WarehousesColumn.code, 'ANB027');
      final WarehousesFilterView view = warehouses.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((Warehouse w) => w.id), <int>[27]);
      expect(view.scans, isTrue);
      expect(bridge.searches, isEmpty);
    });

    test('Növü opens onto the whole catalogue, read once, the most common '
        'kind first', () async {
      final _Bridge bridge = _Bridge();
      final WarehousesController warehouses = bridge.controller();
      await warehouses.ensureLoaded();
      final WarehousesFilterValues values = warehouses.values;

      values.open(WarehousesColumn.type);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 30 anbar oxundu');
      while (warehouses.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(warehouses.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      expect(values.values, const <FilterValue>[
        FilterValue('Standart', 'Standart'),
        FilterValue('Pərakəndə', 'Pərakəndə'),
      ]);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20'],
      );

      // The other columns list theirs at once now, asking nothing: the
      // codes in the list's order, and no blank among them.
      final int asked = bridge.requests.length;
      values.open(WarehousesColumn.name);
      expect(values.values, hasLength(30));
      values.open(WarehousesColumn.code);
      expect(values.values.map((FilterValue v) => v.value), <String>[
        for (int id = 3; id <= 30; id += 3) 'ANB${'$id'.padLeft(3, '0')}',
      ]);
      expect(bridge.requests, hasLength(asked));
    });

    test('Kod is offered only once a warehouse has a code', () async {
      // The live catalogue: not one code.
      final WarehousesController blank = _Bridge(codes: false).controller();
      expect(blank.filterColumns, isNot(contains(WarehousesColumn.code)));
      await blank.ensureLoaded();
      expect(blank.filterColumns, <WarehousesColumn>[
        WarehousesColumn.name,
        WarehousesColumn.type,
        WarehousesColumn.status,
      ]);

      // Codes arrive with the rows that carry them.
      final WarehousesController coded = _Bridge().controller();
      expect(coded.filterColumns, isNot(contains(WarehousesColumn.code)));
      await coded.ensureLoaded();
      expect(coded.filterColumns, WarehousesColumn.values);
    });

    test('Status offers both', () {
      final WarehousesController warehouses = _Bridge().controller();
      final WarehousesFilterValues values = warehouses.values;
      values.open(WarehousesColumn.status);
      expect(values.values, const <FilterValue>[
        FilterValue('active', 'Aktiv'),
        FilterValue('inactive', 'Deaktiv'),
      ]);
    });
  });
}

/// The catalogue: thirty warehouses, by name as the bridge gives them. Every
/// third has a code (unless [codes] is false, as live); every fourth is a
/// shop's (`retail`), the rest `default`; every seventh is switched off;
/// warehouse 10 is `Nərimanov Anbar ` (1C's trailing space) and 11
/// `Nərimanov Anbar 2`.
class _Bridge {
  _Bridge({this.codes = true});

  final bool codes;

  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 30;

  WarehousesController controller() {
    final WarehousesController warehouses = WarehousesController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(warehouses.dispose);
    return warehouses;
  }

  Map<String, Object?> _row(int id) => <String, Object?>{
    'id': id,
    'onec_guid': '00000000-0000-0000-0000-${id.toString().padLeft(12, '0')}',
    'code': codes && id % 3 == 0 ? 'ANB${id.toString().padLeft(3, '0')}' : '',
    'name': switch (id) {
      10 => 'Nərimanov Anbar ',
      11 => 'Nərimanov Anbar 2',
      _ => 'Anbar $id',
    },
    'warehouse_type': id % 4 == 0 ? 'retail' : 'default',
    'is_active': id % 7 != 0,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int id = 1; id <= count; id++) _row(id),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        // The live bridge's `search`: the name only.
        if (search == null ||
            '${row['name']}'.toLowerCase().contains(search.toLowerCase()))
          row,
    ];
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'total': found.length,
      'page': page,
      'page_size': size,
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
