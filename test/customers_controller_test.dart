import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/customers_controller.dart';
import 'package:guven_mobile/src/features/database/application/customers_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/customer.dart';
import 'package:guven_mobile/src/features/database/domain/customers_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';

/// `Müştərilər` asks the bridge for as little as it can — and its filter
/// finds what it is asked for in the whole directory: a code or a name
/// through the bridge, a kind or a payment term on the phone.
void main() {
  group('reading a customer', () {
    test('the live row\'s fields', () {
      // Customer 1 as the bridge answered it on 2026-10-04.
      final Customer customer = Customer.fromJson(<String, Object?>{
        'id': 1,
        'onec_guid': 'b7b91b6b-52a8-11f1-abff-bc24113ee005',
        'code': 'NT0000275',
        'name': '(İŞÇİ) -  FİDAN S.',
        'inn': '',
        'phone': null,
        'email': null,
        'customer_type': 'legal',
        'customer_group': '',
        'price_group': null,
        'credit_limit': 0,
        'discount_percent': 0,
        'payment_deadline_days': 30,
        'legal_address': null,
        'actual_address': null,
        'is_active': true,
        'is_blocked': false,
        'baza_id': 18,
      })!;

      expect(customer.id, 1);
      expect(customer.name, '(İŞÇİ) -  FİDAN S.');
      // No VÖEN: the code stands in for it, as on the website.
      expect(customer.taxId, isNull);
      expect(customer.taxIdOrCode, 'NT0000275');
      expect(customer.typeLabel, 'Hüquqi');
      expect(customer.paymentTerm, '30 gün');
      // A list row carries neither the role nor the legal status: they are
      // the customer's own answer's.
      expect(customer.hasDetail, isFalse);
      expect(customer.roleLabel, isNull);
      expect(customer.legalStatus, isNull);
    });

    test('a VÖEN is shown before the code', () {
      final Customer customer = Customer.fromJson(<String, Object?>{
        'id': 9,
        'code': 'NT0000385',
        'inn': '1800158551',
        'customer_type': 'physical',
      })!;
      expect(customer.taxIdOrCode, '1800158551');
      expect(customer.typeLabel, 'Fiziki');
    });

    test('the customer\'s own answer brings the role and the legal status', () {
      final Customer row = Customer.fromJson(<String, Object?>{
        'id': 5,
        'payment_deadline_days': 30,
      })!;
      final Customer detail = Customer.fromJson(<String, Object?>{
        'legal_type': 'Hüq. şəxs',
        'is_buyer': true,
        'is_supplier': true,
      }, knownId: 5)!;

      final Customer merged = row.mergedWith(detail);
      expect(merged.hasDetail, isTrue);
      expect(merged.roleLabel, 'Alıcı, Təchizatçı');
      expect(merged.legalStatus, 'Hüq. şəxs');
      expect(merged.paymentTerm, '30 gün');

      // Neither: nothing to say.
      final Customer neither = row.mergedWith(
        Customer.fromJson(<String, Object?>{
          'is_buyer': false,
          'is_supplier': false,
        }, knownId: 5)!,
      );
      expect(neither.hasDetail, isTrue);
      expect(neither.roleLabel, isNull);
    });

    test('a term of 0 or none is not a term, as on the website', () {
      expect(
        Customer.fromJson(<String, Object?>{
          'id': 1,
          'payment_deadline_days': 0,
        })!.paymentTerm,
        isNull,
      );
      expect(
        Customer.fromJson(<String, Object?>{'id': 1})!.paymentTerm,
        isNull,
      );
      expect(Customer.fromJson(<String, Object?>{'id': 1})!.typeLabel, isNull);
    });
  });

  group('the filter\'s rules', () {
    const Customer legal = Customer(
      id: 1,
      code: 'NT0000275',
      name: 'ABŞERON  2000',
      type: 'legal',
      paymentDays: 30,
    );
    const Customer physical = Customer(
      id: 2,
      code: 'NT0000353',
      taxId: '1800158551',
      type: 'physical',
      paymentDays: 15,
    );

    test('a kind, a term, a code or VÖEN and a name', () {
      CustomersFilter only(CustomersColumn column, String value) =>
          CustomersFilter.none.toggle(column, value);

      expect(only(CustomersColumn.type, 'legal').matches(legal), isTrue);
      expect(only(CustomersColumn.type, 'legal').matches(physical), isFalse);
      expect(only(CustomersColumn.type, 'physical').matches(physical), isTrue);
      expect(only(CustomersColumn.payment, '15').matches(physical), isTrue);
      expect(only(CustomersColumn.payment, '15').matches(legal), isFalse);
      // The column is what the card shows: the VÖEN where there is one.
      expect(
        only(CustomersColumn.code, '1800158551').matches(physical),
        isTrue,
      );
      expect(
        only(CustomersColumn.code, 'NT0000353').matches(physical),
        isFalse,
      );
      // A name is matched with its spacing set aside.
      expect(only(CustomersColumn.name, 'ABŞERON 2000').matches(legal), isTrue);
    });

    test('every column counts once on the funnel, and `Hamısı` lets go', () {
      final CustomersFilter filter = CustomersFilter.none
          .toggle(CustomersColumn.type, 'legal')
          .toggle(CustomersColumn.type, 'physical')
          .toggle(CustomersColumn.payment, '30');
      expect(filter.columnCount, 2);
      expect(filter.valueOf(CustomersColumn.type), 'physical');
      expect(filter.searchColumn, isNull);
      expect(filter.cleared(CustomersColumn.type).columnCount, 1);
      // Tapped again, a value is let go.
      expect(
        filter.toggle(CustomersColumn.payment, '30').columns,
        <CustomersColumn>[CustomersColumn.type],
      );
      // The code goes to the bridge before the name.
      expect(
        filter
            .toggle(CustomersColumn.name, 'ABŞERON 2000')
            .toggle(CustomersColumn.code, 'NT0000275')
            .searchColumn,
        CustomersColumn.code,
      );
    });
  });

  group('the controller', () {
    test('twenty at a time, and a kind is looked for in the whole '
        'directory', () async {
      final _Bridge bridge = _Bridge();
      final CustomersController customers = bridge.controller();
      await customers.ensureLoaded();
      expect(customers.customers, hasLength(20));
      bridge.requests.clear();

      // Only the last customers are people.
      await customers.toggleFilter(CustomersColumn.type, 'physical');
      final CustomersFilterView view = customers.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((Customer c) => c.id), <int>[98, 99, 100]);
      expect(view.scans, isTrue);
      expect(view.readOf, 100);
      // Every customer read was the list's own, and the page grew while
      // nothing matched.
      expect(customers.customers, hasLength(100));
      expect(bridge.searches, isEmpty);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '40', '80'],
      );
    });

    test(
      'a VÖEN goes to the bridge, and only that customer comes back',
      () async {
        final _Bridge bridge = _Bridge();
        final CustomersController customers = bridge.controller();
        await customers.ensureLoaded();

        await customers.toggleFilter(CustomersColumn.code, '1700000050');
        final CustomersFilterView view = customers.filtered!;
        expect(bridge.searches, <String>['1700000050']);
        expect(view.rows.map((Customer c) => c.id), <int>[51]);
        expect(view.scans, isFalse);
      },
    );

    test('an open card asks for its customer every time it opens, and '
        'shows what it knew meanwhile; a pull forgets it', () async {
      final _Bridge bridge = _Bridge();
      final CustomersController customers = bridge.controller();
      await customers.ensureLoaded();
      final Customer first = customers.customers.first;

      // No status in 1C yet.
      bridge.legalTypes[first.id] = '';
      customers.toggle(first);
      expect(customers.isDetailLoading(first.id), isTrue);
      await _settle();
      expect(customers.isExpanded(first.id), isTrue);
      expect(customers.view(first).roleLabel, 'Alıcı');
      expect(customers.view(first).legalStatus, isNull);

      // Somebody fills it in 1C. Opened again, the card is asked again —
      // and while that is on its way it is not loading: it shows what it
      // knew.
      bridge.legalTypes[first.id] = 'Hüq. şəxs';
      customers.toggle(first);
      customers.toggle(first);
      expect(customers.isDetailLoading(first.id), isFalse);
      expect(customers.view(first).roleLabel, 'Alıcı');
      await _settle();
      expect(customers.view(first).legalStatus, 'Hüq. şəxs');
      expect(bridge.details, <int>[first.id, first.id]);

      // Asked again and failing, it keeps the last answer and says nothing.
      bridge.failDetails = true;
      customers.toggle(first);
      customers.toggle(first);
      await _settle();
      expect(customers.view(first).legalStatus, 'Hüq. şəxs');
      expect(customers.detailError(first.id), isNull);

      await customers.refresh();
      expect(customers.isExpanded(first.id), isFalse);
      expect(customers.view(first).hasDetail, isFalse);
    });

    test('a payment term opens onto the whole directory, read once', () async {
      final _Bridge bridge = _Bridge();
      final CustomersController customers = bridge.controller();
      await customers.ensureLoaded();
      final CustomersFilterValues values = customers.values;

      values.open(CustomersColumn.payment);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 100 müştəri oxundu');
      while (customers.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(customers.hasEveryCustomer, isTrue);
      expect(values.isSearching, isFalse);
      // Shortest first; a customer with no term offers none.
      expect(values.values, const <FilterValue>[
        FilterValue('15', '15 gün'),
        FilterValue('30', '30 gün'),
      ]);
      // Page one, then the rest in pages as large as their places allow.
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20', '40', '80'],
      );

      // The other columns list theirs at once now, asking nothing.
      final int asked = bridge.requests.length;
      values.open(CustomersColumn.name);
      expect(values.values, hasLength(100));
      expect(bridge.requests, hasLength(asked));
    });

    test('Növ offers both kinds', () {
      final CustomersFilterValues values = _Bridge().controller().values;
      values.open(CustomersColumn.type);
      expect(values.values, const <FilterValue>[
        FilterValue('legal', 'Hüquqi'),
        FilterValue('physical', 'Fiziki'),
      ]);
    });
  });
}

/// Lets every answer already asked for land.
Future<void> _settle() async {
  for (int i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The directory: a hundred customers, lowest id first, the last three
/// people rather than companies, every tenth on a 15-day term and the first
/// on none, and a VÖEN on every other one.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  /// The id of every customer asked for on its own.
  final List<int> details = <int>[];

  /// What 1C says a customer's legal status is, where it is not the usual.
  final Map<int, String> legalTypes = <int, String>{};

  /// Every customer's own answer fails.
  bool failDetails = false;

  static const int count = 100;

  CustomersController controller() {
    final CustomersController customers = CustomersController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(customers.dispose);
    return customers;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': i + 1,
    'code': 'NT${(100 + i).toString().padLeft(7, '0')}',
    'name': 'Müştəri $i',
    'inn': i.isEven ? '${1700000000 + i}' : '',
    'customer_type': i >= count - 3 ? 'physical' : 'legal',
    'payment_deadline_days': i == 0
        ? 0
        : i % 10 == 0
        ? 15
        : 30,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final String path = request.url.path;
    final RegExpMatch? one = RegExp(r'/customers/(\d+)$').firstMatch(path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      if (failDetails) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      return _json(<String, Object?>{
        ..._rows[id - 1],
        'legal_type': legalTypes[id] ?? 'Hüq. şəxs',
        'is_buyer': true,
        'is_supplier': false,
      });
    }

    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['code']} ${row['inn']} ${row['name']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
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
