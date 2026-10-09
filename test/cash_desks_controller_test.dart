import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/cash_desks_controller.dart';
import 'package:guven_mobile/src/features/database/application/cash_desks_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/cash_desk.dart';
import 'package:guven_mobile/src/features/database/domain/cash_desks_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';

/// `Kassalar` reads a desk the way the website does — the guid set aside,
/// a missing currency as `AZN` — and its filter finds what it is asked for
/// in the whole catalogue: a code or a name through the bridge, a currency
/// or a status on the phone.
void main() {
  group('reading a desk', () {
    test('the live row\'s fields', () {
      // Desk 14 as the bridge answered on 2026-10-05.
      final CashDesk desk = CashDesk.fromJson(<String, Object?>{
        'id': 14,
        'onec_guid': '72523f6a-5e66-11f1-ac01-bc24113ee005',
        'code': 'NT0000002',
        'name': 'Nərimanov kassası',
        'currency': 'AZN',
        'is_active': true,
        'created_at': '2026-09-18T13:58:33.727513',
        'updated_at': '2026-09-18T13:58:33.727513',
        'baza_id': 18,
      })!;

      expect(desk.id, 14);
      expect(desk.code, 'NT0000002');
      expect(desk.name, 'Nərimanov kassası');
      expect(desk.currency, 'AZN');
      expect(desk.active, isTrue);
    });

    test('a desk 1C names no currency for is in manat, as on the website', () {
      final CashDesk desk = CashDesk.fromJson(<String, Object?>{
        'id': 3,
        'code': 'NT0000009',
        'name': 'Yeni kassa',
        'currency': '',
        'is_active': false,
      })!;
      expect(desk.currency, 'AZN');
      expect(desk.active, isFalse);

      // And with no id, no desk.
      expect(CashDesk.fromJson(<String, Object?>{'code': '1'}), isNull);
    });
  });

  group('the filter\'s rules', () {
    const CashDesk main = CashDesk(
      id: 13,
      code: 'NT0000001',
      name: 'Əsas  Kassa',
      active: true,
    );
    const CashDesk dollars = CashDesk(
      id: 20,
      code: 'NT0000008',
      name: 'Dollar kassası',
      currency: 'USD',
      active: false,
    );

    CashDesksFilter only(CashDesksColumn column, String value) =>
        CashDesksFilter.none.toggle(column, value);

    test('a value in every column', () {
      expect(only(CashDesksColumn.code, 'NT0000001').matches(main), isTrue);
      expect(only(CashDesksColumn.code, 'NT0000001').matches(dollars), isFalse);
      // A name is matched with its spacing set aside.
      expect(only(CashDesksColumn.name, 'Əsas Kassa').matches(main), isTrue);
      expect(only(CashDesksColumn.currency, 'AZN').matches(main), isTrue);
      expect(only(CashDesksColumn.currency, 'usd').matches(dollars), isTrue);
      expect(only(CashDesksColumn.currency, 'AZN').matches(dollars), isFalse);
      expect(only(CashDesksColumn.status, 'active').matches(main), isTrue);
      expect(only(CashDesksColumn.status, 'inactive').matches(dollars), isTrue);
      expect(only(CashDesksColumn.status, 'active').matches(dollars), isFalse);
    });

    test('the code goes to the bridge first, then the name; nothing else '
        'does', () {
      final CashDesksFilter filter = CashDesksFilter.none
          .toggle(CashDesksColumn.currency, 'AZN')
          .toggle(CashDesksColumn.status, 'active');
      expect(filter.searchColumn, isNull);
      expect(
        filter.toggle(CashDesksColumn.name, 'Əsas Kassa').searchColumn,
        CashDesksColumn.name,
      );
      expect(
        filter
            .toggle(CashDesksColumn.name, 'Əsas Kassa')
            .toggle(CashDesksColumn.code, 'NT0000001')
            .searchColumn,
        CashDesksColumn.code,
      );
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(
        filter.toggle(CashDesksColumn.status, 'active').columns,
        <CashDesksColumn>[CashDesksColumn.currency],
      );
      expect(filter.cleared(CashDesksColumn.currency).columnCount, 1);
      expect(
        filter
            .cleared(CashDesksColumn.currency)
            .cleared(CashDesksColumn.status),
        CashDesksFilter.none,
      );
    });
  });

  group('the controller', () {
    test('twenty at a time, and a status is looked for in the whole '
        'catalogue', () async {
      final _Bridge bridge = _Bridge();
      final CashDesksController desks = bridge.controller();
      await desks.ensureLoaded();
      expect(desks.desks, hasLength(20));
      // The bridge's order: the newest first.
      expect(desks.desks.first.id, 30);
      bridge.requests.clear();

      // Only every seventh is switched off.
      await desks.toggleFilter(CashDesksColumn.status, 'inactive');
      final CashDesksFilterView view = desks.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((CashDesk d) => d.id), <int>[28, 21, 14, 7]);
      expect(view.scans, isTrue);
      expect(view.readOf, 30);
      // Every desk read was the list's own.
      expect(desks.desks, hasLength(30));
      expect(bridge.searches, isEmpty);
    });

    test('a name goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final CashDesksController desks = bridge.controller();
      await desks.ensureLoaded();

      await desks.toggleFilter(CashDesksColumn.name, 'Nərimanov kassası');
      final CashDesksFilterView view = desks.filtered!;
      expect(bridge.searches, <String>['Nərimanov kassası']);
      // `Nərimanov kassası 2` holds the words too, but is another desk.
      expect(view.rows.map((CashDesk d) => d.id), <int>[10]);
      expect(view.scans, isFalse);

      // Let go, the list is the list again.
      await desks.clearFilter();
      expect(desks.filtered, isNull);
      expect(desks.desks, hasLength(20));
    });

    test('Valyuta opens onto the whole catalogue, read once', () async {
      final _Bridge bridge = _Bridge();
      final CashDesksController desks = bridge.controller();
      await desks.ensureLoaded();
      final CashDesksFilterValues values = desks.values;

      values.open(CashDesksColumn.currency);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 30 kassa oxundu');
      while (desks.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(desks.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      // The most common first.
      expect(values.values, const <FilterValue>[
        FilterValue('AZN', 'AZN'),
        FilterValue('USD', 'USD'),
      ]);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20'],
      );

      // The other columns list theirs at once now, asking nothing.
      final int asked = bridge.requests.length;
      values.open(CashDesksColumn.name);
      expect(values.values, hasLength(30));
      values.open(CashDesksColumn.code);
      expect(values.values.first, const FilterValue('NT0000030', 'NT0000030'));
      expect(bridge.requests, hasLength(asked));
    });

    test('Status offers both', () {
      final CashDesksController desks = _Bridge().controller();
      final CashDesksFilterValues values = desks.values;
      values.open(CashDesksColumn.status);
      expect(values.values, const <FilterValue>[
        FilterValue('active', 'Aktiv'),
        FilterValue('inactive', 'Deaktiv'),
      ]);
    });
  });
}

/// The catalogue: thirty desks, newest first as the bridge gives them. Every
/// fifth from the fifth keeps dollars, the rest manat; every seventh is
/// switched off; desk 10 is `Nərimanov kassası` and desk 11 `Nərimanov
/// kassası 2`.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 30;

  CashDesksController controller() {
    final CashDesksController desks = CashDesksController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(desks.dispose);
    return desks;
  }

  Map<String, Object?> _row(int id) => <String, Object?>{
    'id': id,
    'onec_guid': '00000000-0000-0000-0000-${id.toString().padLeft(12, '0')}',
    'code': 'NT00000${id.toString().padLeft(2, '0')}',
    'name': switch (id) {
      10 => 'Nərimanov kassası',
      11 => 'Nərimanov kassası 2',
      _ => 'Kassa $id',
    },
    'currency': id % 5 == 0 ? 'USD' : 'AZN',
    'is_active': id % 7 != 0,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int id = count; id >= 1; id--) _row(id),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
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
