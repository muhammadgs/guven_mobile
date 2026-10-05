import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/database_feed.dart';
import 'package:guven_mobile/src/features/database/application/sales_controller.dart';
import 'package:guven_mobile/src/features/database/application/sales_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/sale.dart';
import 'package:guven_mobile/src/features/database/domain/sales_filter.dart';

/// The `Satışlar` filter finds what it is asked for in the whole of the 1C
/// database — not in the pages read so far — and asks the bridge for as
/// little as it can to do it. Letting go of it puts the list back exactly
/// as it was.
void main() {
  group('choosing values', () {
    test('one value a column, and the same value again lets it go', () {
      SalesFilter filter = SalesFilter.none
          .toggle(SalesColumn.customer, 'COFFEMANİA')
          .toggle(SalesColumn.customer, '150 BAR JAZZ CLUB');
      expect(filter.valuesOf(SalesColumn.customer), <String>[
        '150 BAR JAZZ CLUB',
      ]);
      expect(filter.columnCount, 1);

      filter = filter.toggle(SalesColumn.customer, '150 BAR JAZZ CLUB');
      expect(filter.isEmpty, isTrue);
    });

    test('Status takes one of each pair', () {
      SalesFilter filter = SalesFilter.none
          .toggle(SalesColumn.status, SaleFlag.posted.name)
          .toggle(SalesColumn.status, SaleFlag.unsold.name);
      expect(filter.valuesOf(SalesColumn.status), <String>['posted', 'unsold']);

      filter = filter.toggle(SalesColumn.status, SaleFlag.unposted.name);
      expect(filter.valuesOf(SalesColumn.status), <String>[
        'unsold',
        'unposted',
      ]);
      expect(filter.columnCount, 1);
      expect(filter.cleared(SalesColumn.status).isEmpty, isTrue);
    });

    test('a value matches however 1C spaced and cased it', () {
      final Sale sale = Sale(
        id: 1,
        customer: 'THE GARDEN CENTRAL RESTORAN   N.Ö.',
        manager: 'S_Vurğun_S1',
        docType: 'invoice',
        posted: false,
        sold: true,
        date: '2026-09-18',
        lines: const <SaleLine>[SaleLine(product: 'Beef  Topside / Dana Tikə')],
      );
      bool matches(SalesColumn column, String value) =>
          SalesFilter.none.toggle(column, value).matches(sale);

      expect(
        matches(SalesColumn.customer, 'THE GARDEN CENTRAL RESTORAN N.Ö.'),
        isTrue,
      );
      expect(matches(SalesColumn.customer, 'THE GARDEN'), isFalse);
      expect(matches(SalesColumn.kind, 'INVOICE'), isTrue);
      expect(matches(SalesColumn.product, 'Beef Topside / Dana Tikə'), isTrue);
      expect(matches(SalesColumn.status, 'unposted'), isTrue);
      expect(matches(SalesColumn.status, 'unsold'), isFalse);
      expect(matches(SalesColumn.date, '2026-09-18'), isTrue);
      expect(matches(SalesColumn.warehouse, 'Nizami'), isFalse);
    });

    test('a search finds names typed without Azerbaijani letters', () {
      expect(filterKey('FAVORİT'), filterKey('favorit'));
      expect(filterKey('FAVORIT'), filterKey('Favorıt'));
      expect(
        filterSearchKey('ŞƏBƏKƏSİ (URP)').contains(filterSearchKey('sebeke')),
        isTrue,
      );
    });
  });

  group('finding documents', () {
    test('a document four thousand rows down is found by its number, with '
        'one request', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      expect(sales.sales, hasLength(20));

      final _Doc wanted = bridge.docs[4000];
      bridge.requests.clear();
      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.number, wanted.number),
      );

      final SalesFilterView view = sales.filtered!;
      expect(view.rows.map((Sale s) => s.id), <int>[wanted.id]);
      expect(view.hasMore, isFalse);
      expect(bridge.requests, hasLength(1));
      expect(bridge.requests.single['search'], wanted.number);
    });

    test('letting go of the filter puts the list back as it was', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      await sales.loadMore();
      sales.toggle(sales.sales[3]);
      sales.scrollOffset = 1234;
      final List<int> before = sales.sales.map((Sale s) => s.id).toList();

      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.number, bridge.docs[4000].number),
      );
      final Sale found = sales.filtered!.rows.single;
      sales.filtered!.toggle(found);
      expect(sales.filtered!.isExpanded(found.id), isTrue);

      bridge.requests.clear();
      await sales.clearFilter();

      expect(sales.filtered, isNull);
      expect(sales.sales.map((Sale s) => s.id), before);
      expect(sales.isExpanded(sales.sales[3].id), isTrue);
      expect(sales.isExpanded(found.id), isFalse);
      expect(sales.scrollOffset, 1234);
      // The found document is not added to the list: it goes back to its
      // own place, four thousand rows down.
      expect(sales.sales.map((Sale s) => s.id), isNot(contains(found.id)));
      expect(bridge.requests, isEmpty);
    });

    test('customer and manager: whichever finds fewer goes to the '
        'bridge', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.requests.clear();
      await sales.setFilter(
        SalesFilter.none
            .toggle(SalesColumn.customer, _Bridge.favorit)
            .toggle(SalesColumn.manager, 'Nizami_S2'),
      );

      // One one-row request each to count them, then the narrower one.
      final List<Map<String, String>> counts = bridge.requests
          .where((Map<String, String> q) => q['page_size'] == '1')
          .toList();
      expect(counts.map((Map<String, String> q) => q['search']), <String>[
        _Bridge.favorit,
        'Nizami_S2',
      ]);
      expect(bridge.requests.last['search'], 'Nizami_S2');

      final SalesFilterView view = sales.filtered!;
      await _drain(view);
      final List<_Doc> expected = bridge.docs
          .where((_Doc d) => d.customer == _Bridge.favorit)
          .where((_Doc d) => d.manager == 'Nizami_S2')
          .toList();
      expect(view.rows.map((Sale s) => s.id), expected.map((_Doc d) => d.id));
    });

    test('a day deep in the list is sought, not read towards', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      final String day = bridge.docs[3010].date;
      bridge.requests.clear();
      await sales.setFilter(SalesFilter.none.toggle(SalesColumn.date, day));
      final SalesFilterView view = sales.filtered!;
      await _drain(view);

      final List<int> expected = <int>[
        for (final _Doc d in bridge.docs)
          if (d.date == day) d.id,
      ];
      expect(view.rows.map((Sale s) => s.id), expected);
      expect(view.hasMore, isFalse);

      final int probes = bridge.requests
          .where((Map<String, String> q) => q['page_size'] == '1')
          .length;
      final int rows = bridge.requests.fold<int>(
        0,
        (int sum, Map<String, String> q) => sum + int.parse(q['page_size']!),
      );
      expect(probes, lessThanOrEqualTo(6));
      // A day is fifty documents; what was read to find them is barely more.
      expect(rows, lessThan(expected.length * 3));
    });

    test('a day already on the phone costs nothing', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      await sales.loadMore();
      await sales.loadMore();
      await sales.loadMore();

      bridge.requests.clear();
      final String day = bridge.docs[10].date;
      await sales.setFilter(SalesFilter.none.toggle(SalesColumn.date, day));

      expect(bridge.requests, isEmpty);
      expect(sales.filtered!.rows, hasLength(50));
      expect(sales.filtered!.hasMore, isFalse);
    });

    test('a column the bridge cannot search is read out of every document, '
        'in pages that grow while matches are few', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.requests.clear();
      await sales.setFilter(SalesFilter.none.toggle(SalesColumn.kind, 'order'));
      final SalesFilterView view = sales.filtered!;
      expect(view.scans, isTrue);
      await _drain(view);

      final List<int> expected = <int>[
        for (final _Doc d in bridge.docs)
          if (d.kind == 'order') d.id,
      ];
      expect(view.rows.map((Sale s) => s.id), expected);
      expect(view.read, bridge.docs.length);
      expect(view.readOf, bridge.docs.length);

      final List<int> sizes = <int>[
        for (final Map<String, String> q in bridge.requests)
          int.parse(q['page_size']!),
      ];
      expect(sizes.first, kSalesPageSize);
      for (int i = 1; i < sizes.length; i++) {
        expect(sizes[i], greaterThanOrEqualTo(sizes[i - 1]));
      }
      expect(sizes.last, kDatabaseScanPageMax);
      expect(sizes.length, lessThan(bridge.docs.length ~/ kSalesPageSize ~/ 5));
    });

    test('a new filter throws away what the old one was still waiting '
        'for', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.hold();
      final Future<void> first = sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, _Bridge.bar),
      );
      await pumpEventQueue();
      final SalesFilterView old = sales.filtered!;

      bridge.release();
      final Future<void> second = sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, _Bridge.coffee),
      );
      await Future.wait(<Future<void>>[first, second]);

      expect(old.rows, isEmpty);
      final SalesFilterView view = sales.filtered!;
      expect(view, isNot(same(old)));
      expect(view.rows.every((Sale s) => s.customer == _Bridge.coffee), isTrue);
      expect(view.rows, isNotEmpty);
    });

    test('an answer comes back instantly when the filter returns to '
        'it', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, _Bridge.bar),
      );
      await sales.setFilter(
        SalesFilter.none
            .toggle(SalesColumn.customer, _Bridge.bar)
            .toggle(SalesColumn.status, SaleFlag.unposted.name),
      );
      bridge.requests.clear();
      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, _Bridge.bar),
      );
      expect(bridge.requests, isEmpty);
      expect(sales.filtered!.rows, isNotEmpty);
    });

    test('a pull on a filtered list asks again, and leaves the list it '
        'narrows alone', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      await sales.loadMore();
      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, _Bridge.bar),
      );

      bridge.requests.clear();
      await sales.filtered!.refresh();

      expect(bridge.requests, isNotEmpty);
      expect(
        bridge.requests.every((Map<String, String> q) => q['search'] != null),
        isTrue,
      );
      expect(sales.sales, hasLength(40));
    });
  });

  group('values', () {
    test('the documents on the phone first, newest first', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      final SalesFilterValues values = sales.values..open(SalesColumn.customer);
      // A set literal keeps the order things were first added in.
      expect(
        values.values.map((FilterValue v) => v.value).toList(),
        <String>{
          for (final _Doc d in bridge.docs.take(20)) d.customer,
        }.toList(),
      );
      // The design's spacing, not 1C's.
      expect(
        values.values.map((FilterValue v) => v.label),
        contains('THE GARDEN CENTRAL RESTORAN N.Ö.'),
      );
    });

    test(
      'typing narrows at once, and asks the bridge once it pauses',
      () async {
        final _Bridge bridge = _Bridge();
        final SalesController sales = bridge.controller();
        await sales.ensureLoaded();

        final SalesFilterValues values = sales.values
          ..open(SalesColumn.customer);
        values.search('ga');
        values.search('gar');
        expect(values.values.map((FilterValue v) => v.label), <String>[
          'THE GARDEN CENTRAL RESTORAN N.Ö.',
        ]);
        expect(values.isSearching, isTrue);
        expect(bridge.catalogue, isEmpty);

        await Future<void>.delayed(
          kSalesValueSearchDelay + const Duration(milliseconds: 150),
        );
        // Only what was typed last, once.
        expect(bridge.catalogue, <String>['/customers/?gar']);
        expect(values.isSearching, isFalse);
        expect(values.values.map((FilterValue v) => v.label), <String>[
          'THE GARDEN CENTRAL RESTORAN N.Ö.',
          'GARAJ MMC',
        ]);
      },
    );

    test('a chosen value is listed first when its column opens', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      await sales.setFilter(
        SalesFilter.none.toggle(SalesColumn.customer, 'GARAJ MMC'),
      );

      final SalesFilterValues values = sales.values..open(SalesColumn.customer);
      expect(values.values.first.value, 'GARAJ MMC');
    });

    test('Status offers its four flags, Növ its kinds in words', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      final SalesFilterValues values = sales.values..open(SalesColumn.status);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Postlanıb',
        'Postlanmayıb',
        'Satılıb',
        'Satılmayıb',
      ]);

      values.open(SalesColumn.kind);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Qaimə',
        'Sifariş',
      ]);
    });

    test('the days run from the newest document back to the oldest', () async {
      final _Bridge bridge = _Bridge();
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      final SalesFilterValues values = sales.values..open(SalesColumn.date);
      await pumpEventQueue();
      final List<String> days = values.values
          .map((FilterValue v) => v.value)
          .toList();
      expect(days.first, bridge.docs.first.date);
      expect(days.last, bridge.docs.last.date);
      expect(days, hasLength(bridge.docs.length ~/ _Bridge.perDay));

      values.search('18.09');
      expect(values.values.map((FilterValue v) => v.value), <String>[
        '2026-09-18',
      ]);
    });
  });
}

/// Reads [view] to its end, the way a list scrolled to the bottom would.
Future<void> _drain(SalesFilterView view) async {
  await view.ready;
  int guard = 0;
  while (view.hasMore && guard++ < 1000) {
    await view.loadMore();
  }
  expect(view.moreError, isNull);
}

class _Doc {
  _Doc(int index)
    : id = 100000 - index,
      number = 'NT${(5000 - index).toString().padLeft(9, '0')}',
      date = _dayBefore(index ~/ _Bridge.perDay),
      customer = _Bridge.customers[index % _Bridge.customers.length],
      manager = _Bridge.managers[index % _Bridge.managers.length],
      kind = index % 250 == 7 ? 'order' : 'invoice',
      posted = index % 3 != 0;

  final int id;
  final String number;
  final String date;
  final String customer;
  final String manager;
  final String kind;
  final bool posted;

  static String _dayBefore(int days) {
    final DateTime day = DateTime.utc(
      2026,
      9,
      23,
    ).subtract(Duration(days: days));
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'order_number': number,
    'order_date': date,
    'customer': customer,
    'manager': manager,
    'organization': 'NaTural-İD',
    'warehouse': '',
    'doc_type': kind,
    'total_amount': 58.2,
    'currency': 'AZN',
    'is_posted': posted,
    'is_sold': kind == 'invoice',
    'lines': <Object?>[
      <String, Object?>{
        'product_name': 'Beef Topside / Dana Tikə',
        'quantity': 1,
        'price': 58.2,
        'amount': 58.2,
      },
    ],
  };
}

/// The 1C bridge as probed on 2026-09-24: newest first, `search` a substring
/// of the number, the customer and the manager, fifty documents a day.
class _Bridge {
  _Bridge() : docs = <_Doc>[for (int i = 0; i < 5000; i++) _Doc(i)];

  static const int perDay = 50;
  static const String favorit = 'FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)';
  static const String bar = '150 BAR JAZZ CLUB';
  static const String coffee = 'COFFEMANİA';
  static const List<String> customers = <String>[
    favorit,
    favorit,
    favorit,
    bar,
    coffee,
    'THE GARDEN CENTRAL RESTORAN   N.Ö.',
  ];
  static const List<String> managers = <String>[
    'S_Vurğun_S1',
    'Nizami_S2',
    'Mühasib-istehsal',
    'Ağ Şəhər_S1',
  ];

  final List<_Doc> docs;

  /// Every sales request, by its query.
  final List<Map<String, String>> requests = <Map<String, String>>[];

  /// Every catalogue request, as `path?search`.
  final List<String> catalogue = <String>[];

  Completer<void>? _gate;
  void hold() => _gate = Completer<void>();
  void release() => _gate?.complete();

  SalesController controller() {
    final SalesController sales = SalesController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(sales.dispose);
    return sales;
  }

  Future<http.Response> _answer(http.Request request) async {
    final String path = request.url.path;
    final Map<String, String> query = request.url.queryParameters;

    if (path.endsWith('/customers/')) {
      catalogue.add('/customers/?${query['search'] ?? ''}');
      return _json(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{'name': 'GARAJ MMC'},
          <String, Object?>{'name': 'THE GARDEN CENTRAL RESTORAN   N.Ö.'},
        ],
        'total': 2,
      });
    }
    if (!path.endsWith('/onec-data/sales/')) {
      return _json(<String, Object?>{'data': <Object?>[], 'total': 0});
    }

    requests.add(query);
    final Completer<void>? gate = _gate;
    if (gate != null) await gate.future;

    final String? search = query['search'];
    final String key = search == null ? '' : filterSearchKey(search);
    final List<_Doc> found = search == null
        ? docs
        : docs
              .where(
                (_Doc d) =>
                    filterSearchKey(d.number).contains(key) ||
                    filterSearchKey(d.customer).contains(key) ||
                    filterSearchKey(d.manager).contains(key),
              )
              .toList();
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'data': <Object?>[
        for (int i = start; i < start + size && i < found.length; i++)
          found[i].toJson(),
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
