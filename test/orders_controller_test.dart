import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/orders_controller.dart';
import 'package:guven_mobile/src/features/database/application/orders_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/order.dart';
import 'package:guven_mobile/src/features/database/domain/orders_filter.dart';

/// `Sifarişlər` asks the bridge for as little as it can: a page at a time,
/// an order's own answer once, the whole table only when a column's values
/// need it — and a filter finds what it is asked for anywhere in the table.
void main() {
  group('reading an order', () {
    test('the live row\'s fields', () {
      final Order order = Order.fromJson(<String, Object?>{
        'id': 43798,
        'onec_guid': '9e3d52e6-b653-11f1-ac09-bc24113ee005',
        'order_number': 'NT000007510',
        'order_date': '2026-09-16T00:00:00',
        'total_amount': 117.93,
        'status': 'delivered',
        'payment_status': 'paid',
        'created_at': '2026-09-23T13:05:34.683803',
        'updated_at': '2026-09-23T13:05:34.683803',
        'synced_at': '2026-09-23T17:04:51',
        'baza_id': 18,
      })!;

      expect(order.id, 43798);
      expect(order.number, 'NT000007510');
      expect(order.date, '2026-09-16');
      expect(order.amount, 117.93);
      expect(order.status, 'delivered');
      expect(order.payment, 'paid');
      // A row never carries these: only the order's own answer does.
      expect(order.discount, isNull);
      expect(order.hasDetail, isFalse);
    });

    test('the order\'s own answer lays its figures over the row', () {
      final Order row = Order.fromJson(<String, Object?>{
        'id': 43798,
        'order_number': 'NT000007510',
        'total_amount': 117.93,
      })!;
      final Order detail = Order.fromJson(<String, Object?>{
        'order_number': 'NT000007510',
        'customer_id': 274,
        'total_amount': 117.93,
        'paid_amount': 0.0,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'status': 'delivered',
        'payment_status': 'paid',
        'company_id': null,
        'is_deleted': false,
      }, knownId: 43798)!;

      final Order merged = row.mergedWith(detail);
      expect(merged.id, 43798);
      expect(merged.hasDetail, isTrue);
      expect(merged.discount, 0);
      expect(merged.tax, 0);
      expect(merged.paid, 0);
      // Sent by neither answer.
      expect(merged.remaining, isNull);
      expect(merged.status, 'delivered');
    });

    test('the website\'s words, and the bridge\'s own for the rest', () {
      expect(OrderStatus.labelOf('delivered'), 'Çatdırıldı');
      expect(OrderStatus.labelOf('new'), 'Yeni');
      expect(OrderStatus.labelOf('returned'), 'returned');
      expect(OrderPayment.labelOf('paid'), 'Ödənilib');
      expect(OrderPayment.labelOf('unpaid'), 'Ödənilməyib');
      expect(OrderStatus.byCode('delivered')!.tone, OrderTone.done);
      expect(OrderStatus.byCode('new')!.tone, OrderTone.underway);
      expect(OrderPayment.byCode('unpaid')!.tone, OrderTone.stopped);
    });
  });

  group('paging', () {
    test('twenty at a time, and never past the total', () async {
      final _Bridge bridge = _Bridge(count: 40);
      final OrdersController orders = bridge.controller();

      await orders.ensureLoaded();
      expect(bridge.requests.single.path, endsWith('/orders/'));
      expect(bridge.requests.single.queryParameters, <String, String>{
        'page': '1',
        'page_size': '20',
      });
      expect(orders.orders, hasLength(20));

      await orders.loadMore();
      expect(orders.orders, hasLength(40));
      expect(orders.hasMore, isFalse);

      await orders.loadMore();
      await orders.ensureLoaded();
      expect(bridge.requests, hasLength(2));
    });

    test('a second wait for page one waits for the same request', () async {
      final _Bridge bridge = _Bridge();
      final OrdersController orders = bridge.controller();
      final Future<void> first = orders.ensureLoaded();
      final Future<void> second = orders.ensureLoaded();
      await Future.wait(<Future<void>>[first, second]);
      expect(bridge.requests, hasLength(1));
      expect(orders.orders, hasLength(20));
    });
  });

  group('open cards', () {
    test('a card asks for its order\'s own answer once', () async {
      final _Bridge bridge = _Bridge();
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      final Order first = orders.orders.first;
      bridge.requests.clear();

      orders.toggle(first);
      expect(orders.isExpanded(first.id), isTrue);
      expect(orders.isDetailLoading(first.id), isTrue);
      await pumpEventQueue();

      expect(bridge.requests.single.path, endsWith('/orders/${first.id}'));
      final Order shown = orders.view(first);
      expect(shown.discount, 0);
      expect(shown.paid, 0);
      expect(shown.remaining, isNull);

      // Shut and opened again: kept, not asked for.
      orders.toggle(first);
      orders.toggle(first);
      await pumpEventQueue();
      expect(bridge.requests, hasLength(1));
    });

    test('an answer that fails says why, and can be asked again', () async {
      final _Bridge bridge = _Bridge()..failDetail = true;
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      final Order first = orders.orders.first;

      orders.toggle(first);
      await pumpEventQueue();
      expect(orders.detailError(first.id), 'Server xətası');
      expect(orders.view(first).hasDetail, isFalse);

      bridge.failDetail = false;
      await orders.loadDetail(first.id);
      expect(orders.detailError(first.id), isNull);
      expect(orders.view(first).hasDetail, isTrue);
    });

    test('a pull shuts every card and forgets their answers', () async {
      final _Bridge bridge = _Bridge();
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      final Order first = orders.orders.first;
      orders.toggle(first);
      await pumpEventQueue();

      await orders.refresh();
      expect(orders.isExpanded(first.id), isFalse);
      expect(orders.view(first).hasDetail, isFalse);
    });
  });

  group('every order', () {
    test('the rest of the table is read into the list\'s own pages, as '
        'large as they go', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      await orders.readAll();
      expect(orders.hasEveryOrder, isTrue);
      expect(orders.isReadingAll, isFalse);
      expect(orders.orders, hasLength(300));
      // Each page as large as the place it starts at allows, up to 160.
      expect(
        <String>[
          for (final Uri uri in bridge.requests)
            '${uri.queryParameters['page']}x'
                '${uri.queryParameters['page_size']}',
        ],
        <String>['2x20', '2x40', '2x80', '2x160'],
      );

      // The list has nothing left to ask for.
      await orders.loadMore();
      expect(bridge.requests, hasLength(4));
      await orders.readAll();
      expect(bridge.requests, hasLength(4));
    });

    test('before page one, the reading waits for it', () async {
      final _Bridge bridge = _Bridge(count: 60);
      final OrdersController orders = bridge.controller();
      await orders.readAll();
      expect(orders.orders, hasLength(60));
      expect(orders.hasEveryOrder, isTrue);
    });

    test('a failure stops the reading and says why', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.failList = true;

      await orders.readAll();
      expect(orders.readAllError, 'Server xətası');
      expect(orders.hasEveryOrder, isFalse);
      expect(orders.isReadingAll, isFalse);
    });
  });

  group('the filter', () {
    test('a number goes to the bridge, and only that number comes '
        'back', () async {
      final _Bridge bridge = _Bridge();
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      // `NT00000759` would find ten numbers: the match is exact here.
      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.number, 'NT000007595'),
      );
      final OrdersFilterView view = orders.filtered!;
      expect(bridge.listQueries.single['search'], 'NT000007595');
      expect(view.rows.map((Order o) => o.number), <String>['NT000007595']);
      expect(view.hasMore, isFalse);
      expect(view.scans, isFalse);
    });

    test('a status is the bridge\'s own filter', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.status, 'new'),
      );
      final OrdersFilterView view = orders.filtered!;
      await _drain(view);
      expect(bridge.listQueries.first['status'], 'new');
      expect(view.rows, hasLength(6));
      expect(view.rows.every((Order o) => o.status == 'new'), isTrue);
      expect(view.scans, isFalse);
      // Six orders, one page: the rest of the table was never read.
      expect(bridge.requests, hasLength(1));
    });

    test('a number and a status go to the bridge together', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      await orders.setFilter(
        OrdersFilter.none
            .toggle(OrdersColumn.number, 'NT000007543')
            .toggle(OrdersColumn.status, 'new'),
      );
      expect(bridge.listQueries.single, containsPair('search', 'NT000007543'));
      expect(bridge.listQueries.single, containsPair('status', 'new'));
      expect(orders.filtered!.rows.single.number, 'NT000007543');
    });

    test('a day is looked for in the list\'s own pages, which keep '
        'what was read', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.date, '2026-05-10'),
      );
      final OrdersFilterView view = orders.filtered!;
      expect(view.scans, isTrue);
      await _drain(view);

      expect(view.rows, hasLength(bridge.onDay('2026-05-10')));
      expect(view.rows, isNotEmpty);
      expect(view.rows.every((Order o) => o.date == '2026-05-10'), isTrue);
      expect(view.readOf, 300);
      // No question the bridge could narrow: none was put to it.
      expect(
        bridge.listQueries.every(
          (Map<String, String> q) =>
              !q.containsKey('search') && !q.containsKey('status'),
        ),
        isTrue,
      );
      // What was read was the list's: letting go asks for nothing more.
      expect(orders.orders, hasLength(300));
      final int asked = bridge.requests.length;
      await orders.clearFilter();
      await orders.loadMore();
      expect(bridge.requests, hasLength(asked));
    });

    test('an amount is matched to the qəpik', () async {
      final _Bridge bridge = _Bridge(count: 60);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();

      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.amount, amountValue(27.9)),
      );
      await _drain(orders.filtered!);
      expect(orders.filtered!.rows.map((Order o) => o.id), <int>[
        44000 - 5,
        44000 - 6,
      ]);
    });

    test('once every order is on the phone, a filter asks for '
        'nothing', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      await orders.readAll();
      bridge.requests.clear();

      await orders.setFilter(
        OrdersFilter.none
            .toggle(OrdersColumn.status, 'new')
            .toggle(OrdersColumn.payment, 'unpaid'),
      );
      expect(orders.filtered!.rows, hasLength(6));
      expect(orders.filtered!.hasMore, isFalse);
      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.number, 'NT000007595'),
      );
      expect(orders.filtered!.rows, hasLength(1));
      expect(bridge.requests, isEmpty);
    });

    test('letting go puts the list back as it was', () async {
      final _Bridge bridge = _Bridge();
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      await orders.loadMore();
      final List<Order> before = List<Order>.of(orders.orders);

      await orders.toggleFilter(OrdersColumn.status, 'new');
      expect(orders.filterCount, 1);
      await orders.clearFilterColumn(OrdersColumn.status);

      expect(orders.filtered, isNull);
      expect(orders.isFiltered, isFalse);
      expect(orders.orders, before);
    });

    test('a card opened in the filtered list is its own', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.status, 'new'),
      );
      final OrdersFilterView view = orders.filtered!;
      final Order found = view.rows.first;

      view.toggle(found);
      expect(view.isExpanded(found.id), isTrue);
      expect(orders.isExpanded(found.id), isFalse);
      await pumpEventQueue();
      expect(orders.view(found).hasDetail, isTrue);
    });

    test('a pull on the filtered list asks it again, from nothing', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      await orders.setFilter(
        OrdersFilter.none.toggle(OrdersColumn.date, '2026-09-16'),
      );
      bridge.requests.clear();

      await orders.filtered!.refresh();
      // Not the list's pages: a question of its own, from page one.
      expect(bridge.listQueries.first['page'], '1');
      expect(orders.filtered!.rows, isNotEmpty);
    });
  });

  group('the values a column offers', () {
    test('Sifariş: the numbers on the phone, highest first, and while '
        'typing the bridge\'s', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      final OrdersFilterValues values = orders.values
        ..open(OrdersColumn.number);
      expect(values.values.first.value, 'NT000007600');
      expect(values.values, hasLength(20));
      expect(bridge.requests, isEmpty);

      values.search('740');
      expect(values.isSearching, isTrue);
      // Nothing loaded carries it yet.
      expect(values.values, isEmpty);
      await Future<void>.delayed(
        kOrdersValueSearchDelay + const Duration(milliseconds: 150),
      );
      expect(bridge.listQueries.single['search'], '740');
      expect(values.isSearching, isFalse);
      expect(values.values.map((FilterValue v) => v.value), contains(
        'NT000007400',
      ));
    });

    test('Tarix: says how far the table has been read, then every day, '
        'newest first', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();

      final OrdersFilterValues values = orders.values..open(OrdersColumn.date);
      expect(orders.isReadingAll, isTrue);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 300 sifariş oxundu');

      await _settle(orders);
      expect(values.isSearching, isFalse);
      expect(values.progress, isNull);
      final List<String> days = <String>[
        for (final FilterValue v in values.values) v.value,
      ];
      expect(days, bridge.days);
      expect(days.first, '2026-09-21');
      expect(days.last, '2026-04-25');

      // `10.05` and `1005` find 2026-05-10.
      values.search('10.05');
      expect(values.values.map((FilterValue v) => v.value), <String>[
        '2026-05-10',
      ]);
      values.search('1005');
      expect(values.values.map((FilterValue v) => v.value), <String>[
        '2026-05-10',
      ]);
    });

    test('Məbləğ: every amount, largest first, each once — and 6720 finds '
        '6,720.00 ₼', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();

      final OrdersFilterValues values = orders.values
        ..open(OrdersColumn.amount);
      await _settle(orders);

      final List<double> amounts = <double>[
        for (final FilterValue v in values.values) double.parse(v.value),
      ];
      expect(amounts.first, 6720);
      expect(
        amounts,
        List<double>.of(amounts)..sort((double a, double b) => b.compareTo(a)),
      );
      // 27.90 twice in the table, once in the list.
      expect(amounts.where((double a) => a == 27.9), hasLength(1));
      expect(amounts, hasLength(299));

      values.search('6720');
      expect(values.values.map((FilterValue v) => v.label), <String>[
        '6,720.00 ₼',
      ]);
      values.search('6,720');
      expect(values.values.map((FilterValue v) => v.label), <String>[
        '6,720.00 ₼',
      ]);
      // A comma before anything but three digits is a decimal point: every
      // amount holding `27.9`, and no `279`.
      values.search('27,9');
      final List<String> found = <String>[
        for (final FilterValue v in values.values) v.value,
      ];
      expect(found, contains('27.90'));
      expect(found.every((String v) => v.contains('27.9')), isTrue);
    });

    test('Status: the statuses the bridge counts orders for, in the '
        'website\'s order', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      bridge.requests.clear();

      final OrdersFilterValues values = orders.values
        ..open(OrdersColumn.status);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      for (int i = 0; i < 200 && values.isSearching; i++) {
        await pumpEventQueue();
      }

      // One one-row count for each of the website's seven, one at a time.
      expect(
        bridge.listQueries.map((Map<String, String> q) => q['status']),
        OrderStatus.values.map((OrderStatus s) => s.code),
      );
      expect(
        bridge.listQueries.every((Map<String, String> q) => q['page_size'] == '1'),
        isTrue,
      );
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Yeni',
        'Çatdırıldı',
      ]);
      // Asked once.
      values
        ..close()
        ..open(OrdersColumn.status);
      await pumpEventQueue();
      expect(bridge.requests, hasLength(7));
      expect(values.values, hasLength(2));
    });

    test('Ödəniş: every payment state in the table, in the website\'s '
        'order', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();

      final OrdersFilterValues values = orders.values
        ..open(OrdersColumn.payment);
      await _settle(orders);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Ödənilməyib',
        'Qismən',
        'Ödənilib',
      ]);
    });

    test('once every order is on the phone, Status counts nothing', () async {
      final _Bridge bridge = _Bridge(count: 300);
      final OrdersController orders = bridge.controller();
      await orders.ensureLoaded();
      await orders.readAll();
      bridge.requests.clear();

      final OrdersFilterValues values = orders.values
        ..open(OrdersColumn.status);
      expect(values.isSearching, isFalse);
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Yeni',
        'Çatdırıldı',
      ]);
      expect(bridge.requests, isEmpty);
    });
  });
}

/// Reads [view] to its end, the way a list scrolled to the bottom would.
Future<void> _drain(OrdersFilterView view) async {
  await view.ready;
  for (int i = 0; i < 100 && view.hasMore; i++) {
    await view.loadMore();
  }
}

/// Lets the table's reading run to its end.
Future<void> _settle(OrdersController orders) async {
  for (int i = 0; i < 200 && orders.isReadingAll; i++) {
    await pumpEventQueue();
  }
}

/// The 1C bridge's orders table: [count] orders, highest id first, as it
/// answers. Their days come in two runs, each oldest first, the way the
/// live table's do; six orders are new and unpaid, one is partly paid, and
/// two share an amount.
class _Bridge {
  _Bridge({this.count = 60});

  final int count;

  bool failList = false;
  bool failDetail = false;

  final List<Uri> requests = <Uri>[];

  /// The query of every list request.
  List<Map<String, String>> get listQueries => <Map<String, String>>[
    for (final Uri uri in requests)
      if (uri.path.endsWith('/orders/')) uri.queryParameters,
  ];

  OrdersController controller() {
    final OrdersController orders = OrdersController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(orders.dispose);
    return orders;
  }

  static String _day(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// The first thirty orders fall on 2026-09-16 onwards, five a day; the
  /// rest on 2026-04-25 onwards, three a day.
  static String dayOf(int i) => i < 30
      ? _day(DateTime.utc(2026, 9, 16 + i ~/ 5))
      : _day(DateTime.utc(2026, 4, 25).add(Duration(days: (i - 30) ~/ 3)));

  static double amountOf(int i) => switch (i) {
    0 => 6720,
    5 || 6 => 27.9,
    _ => (i * 7919 % 100000) / 100,
  };

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': 44000 - i,
    'onec_guid': 'guid-$i',
    'order_number': 'NT${(7600 - i).toString().padLeft(9, '0')}',
    'order_date': '${dayOf(i)}T00:00:00',
    'total_amount': amountOf(i),
    'status': i % 50 == 7 ? 'new' : 'delivered',
    'payment_status': i % 50 == 7
        ? 'unpaid'
        : i == 100
        ? 'partial'
        : 'paid',
    'baza_id': 18,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  /// Every day an order falls on, newest first.
  List<String> get days =>
      <String>{for (int i = 0; i < count; i++) dayOf(i)}.toList()
        ..sort((String a, String b) => b.compareTo(a));

  int onDay(String day) =>
      <int>[for (int i = 0; i < count; i++) i].where((int i) => dayOf(i) == day).length;

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final String path = request.url.path;

    final RegExpMatch? one = RegExp(r'/orders/(\d+)$').firstMatch(path);
    if (one != null) {
      if (failDetail) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      final int id = int.parse(one.group(1)!);
      final Map<String, Object?> row = _rows.firstWhere(
        (Map<String, Object?> r) => r['id'] == id,
      );
      return _json(<String, Object?>{
        ...row,
        'customer_id': 127,
        'paid_amount': 0.0,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'company_id': null,
        'is_deleted': false,
      });
    }
    if (failList) {
      return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
    }

    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search']?.toLowerCase();
    final String? status = query['status'];
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if ((search == null ||
                '${row['order_number']}'.toLowerCase().contains(search)) &&
            (status == null || row['status'] == status))
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
