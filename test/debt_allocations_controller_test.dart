import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/debt_allocations_controller.dart';
import 'package:guven_mobile/src/features/database/application/debt_allocations_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/debt_allocation.dart';
import 'package:guven_mobile/src/features/database/domain/debt_allocations_filter.dart';

/// `Borc Bölgüsü`: what a row says, and the filter — a manager found
/// through the bridge, a run of months and a span of amounts on the phone,
/// the span's minimum ending the reading at the first amount under it.
void main() {
  group('reading a row', () {
    test('the live row\'s fields, without the sale\'s guid', () {
      // The first row as the bridge answered on 2026-10-22.
      final DebtAllocation row = DebtAllocation.fromJson(<String, Object?>{
        'id': 532,
        'sale_id': '491b97c3-c23e-11f1-ac09-bc24113ee005',
        'sale_date': '2026-10-07',
        'manager_id': '64317202-0ca2-11f1-abf8-bc24113ee005',
        'phys_id': 'd1077aff-b195-11f1-ac09-bc24113ee005',
        'manager': 'Mühasib-istehsal',
        'allocated': 36398.15,
        'baza_id': 18,
        'synced_at': null,
        'created_at': '2026-10-18T22:37:46.454674',
        'updated_at': '2026-10-18T22:37:46.454674',
      })!;

      expect(row.id, 532);
      expect(row.date, '2026-10-07');
      expect(row.month, const FilterMonth(2026, 10));
      expect(row.manager, 'Mühasib-istehsal');
      expect(row.allocated, 36398.15);
      // And with no id, no row.
      expect(
        DebtAllocation.fromJson(<String, Object?>{'manager': 'X'}),
        isNull,
      );
    });

    test('a date read as the day it names; none, no month', () {
      expect(
        DebtAllocation.fromJson(<String, Object?>{
          'id': 1,
          'sale_date': '2026-07-01T00:00:00',
        })!.date,
        '2026-07-01',
      );
      expect(const DebtAllocation(id: 1).month, isNull);
      expect(const DebtAllocation(id: 1, date: 'dünən').month, isNull);
    });
  });

  group('the filter\'s rules', () {
    const DebtAllocation top = DebtAllocation(
      id: 532,
      date: '2026-10-07',
      manager: 'Mühasib-istehsal',
      allocated: 36398.15,
    );
    const DebtAllocation small = DebtAllocation(
      id: 1845,
      date: '2026-08-29',
      manager: 'Badamdar_S2',
      allocated: 1.98,
    );
    const DebtAllocation bare = DebtAllocation(id: 3, manager: 'Boş');

    test('a manager is matched whole, its spacing and case set aside', () {
      DebtAllocationsFilter only(String name) => DebtAllocationsFilter.none
          .toggle(DebtAllocationsColumn.manager, name);
      expect(only('badamdar_s2').matches(small), isTrue);
      expect(only('Badamdar  S2').matches(small), isFalse);
      // `Mühasib` is in `Mühasib-istehsal`, but is not it.
      expect(only('Mühasib').matches(top), isFalse);
      expect(only('Mühasib-istehsal').matches(top), isTrue);
    });

    test('a run of months holds the sales dated in it', () {
      DebtAllocationsFilter months(FilterMonth? from, FilterMonth? to) =>
          DebtAllocationsFilter.none.withPeriod(
            FilterPeriod(from: from, to: to),
          );
      const FilterMonth august = FilterMonth(2026, 8);
      const FilterMonth october = FilterMonth(2026, 10);
      expect(months(october, october).matches(top), isTrue);
      expect(months(october, october).matches(small), isFalse);
      expect(months(august, october).matches(small), isTrue);
      // The ends the wrong way round mean the same months.
      expect(months(october, august).matches(small), isTrue);
      expect(months(null, august).matches(top), isFalse);
      // A sale with no date is in no month.
      expect(months(august, null).matches(bare), isFalse);
    });

    test('the amount is a span, and a row without one is in none', () {
      DebtAllocationsFilter span(double? min, double? max) =>
          DebtAllocationsFilter.none.withShare(FilterRange(min: min, max: max));
      expect(span(10000, null).matches(top), isTrue);
      expect(span(10000, null).matches(small), isFalse);
      expect(span(null, 2).matches(small), isTrue);
      expect(span(1.98, 1.98).matches(small), isTrue);
      expect(span(null, 1e12).matches(bare), isFalse);
    });

    test('an amount under the minimum ends the list; nothing else does', () {
      final DebtAllocationsFilter fromTen = DebtAllocationsFilter.none
          .withShare(const FilterRange(min: 10));
      expect(fromTen.endsAt(small), isTrue);
      expect(fromTen.endsAt(top), isFalse);
      // A row with no amount says nothing about the rows after it.
      expect(fromTen.endsAt(bare), isFalse);
      // A maximum, a month or a manager never ends it: the rows after an
      // amount over the span are smaller, and may well fit.
      expect(
        DebtAllocationsFilter.none
            .withShare(const FilterRange(max: 10))
            .endsAt(top),
        isFalse,
      );
      expect(
        DebtAllocationsFilter.none
            .toggle(DebtAllocationsColumn.manager, 'GF20')
            .endsAt(small),
        isFalse,
      );
    });

    test('choosing, letting go and counting', () {
      final DebtAllocationsFilter amounts = DebtAllocationsFilter.none
          .withShare(const FilterRange(max: 95));
      final DebtAllocationsFilter named = amounts.toggle(
        DebtAllocationsColumn.manager,
        'GF20',
      );
      final DebtAllocationsFilter dated = named.withPeriod(
        const FilterPeriod(from: FilterMonth(2026, 9)),
      );
      expect(dated.columns, DebtAllocationsColumn.values);
      expect(dated.columnCount, 3);
      expect(dated.isChosen(DebtAllocationsColumn.manager, 'GF20'), isTrue);
      expect(dated.valuesOf(DebtAllocationsColumn.manager), <String>['GF20']);
      expect(dated.valuesOf(DebtAllocationsColumn.share), isEmpty);
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(named.toggle(DebtAllocationsColumn.manager, 'GF20'), amounts);
      expect(dated.cleared(DebtAllocationsColumn.date), named);
      expect(dated.cleared(DebtAllocationsColumn.manager).columnCount, 2);
      expect(amounts.withShare(FilterRange.any), DebtAllocationsFilter.none);
      // A month or an amount is not a value to choose.
      expect(amounts.toggle(DebtAllocationsColumn.share, '95'), amounts);
    });

    test('the columns are the card\'s fields, in its order', () {
      expect(
        DebtAllocationsColumn.values.map((DebtAllocationsColumn c) => c.label),
        <String>['Menecer', 'Tarix', 'Bölgü'],
      );
      expect(
        DebtAllocationsColumn.values.where(
          (DebtAllocationsColumn c) => c.searchable,
        ),
        <DebtAllocationsColumn>[DebtAllocationsColumn.manager],
      );
    });
  });

  group('the controller', () {
    test('asks the bridge\'s address, twenty at a time', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();
      expect(
        bridge.requests.single.path,
        endsWith('/onec-data/manager-debt-allocations/'),
      );
      expect(bridge.requests.single.queryParameters['page_size'], '20');
      expect(shares.allocations, hasLength(20));
      expect(shares.allocations.first.allocated, 1000);
    });

    test('a minimum amount stops at the first share under it', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();
      bridge.requests.clear();

      // 1,000 ₼ down by 10 a row: 800 and up is the first 21.
      await shares.setRange(
        DebtAllocationsColumn.share,
        const FilterRange(min: 800),
      );
      final DebtAllocationsFilterView view = shares.filtered!;
      // The twenty on the phone all fit, so nothing is asked yet.
      expect(view.rows, hasLength(20));
      expect(bridge.requests, isEmpty);
      expect(view.hasMore, isTrue);

      await view.loadMore();
      expect(view.rows, hasLength(21));
      expect(view.rows.last.allocated, 800);
      // 790 ₼ was read, and nothing after it can fit: one page asked, not
      // the forty rows still left.
      expect(view.hasMore, isFalse);
      expect(bridge.requests, hasLength(1));
      expect(view.scans, isTrue);
    });

    test('a maximum reads on to the end', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();

      await shares.setRange(
        DebtAllocationsColumn.share,
        const FilterRange(max: 450),
      );
      final DebtAllocationsFilterView view = shares.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      // 450, 440, 430, 420, 410.
      expect(view.rows.map((DebtAllocation a) => a.allocated), <double>[
        450,
        440,
        430,
        420,
        410,
      ]);
      expect(view.readOf, _Bridge.count);
    });

    test('a run of months is looked for in the whole table', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();

      expect(shares.takesPeriod(DebtAllocationsColumn.date), isTrue);
      expect(shares.takesPeriod(DebtAllocationsColumn.share), isFalse);
      // The months of the sales on the phone are marked.
      expect(shares.periodMonthsOf(DebtAllocationsColumn.date), <FilterMonth>{
        const FilterMonth(2026, 7),
        const FilterMonth(2026, 8),
        const FilterMonth(2026, 9),
        const FilterMonth(2026, 10),
      });
      expect(shares.periodMonthsOf(DebtAllocationsColumn.share), isEmpty);

      const FilterPeriod october = FilterPeriod(
        from: FilterMonth(2026, 10),
        to: FilterMonth(2026, 10),
      );
      await shares.setPeriod(DebtAllocationsColumn.date, october);
      expect(shares.periodOf(DebtAllocationsColumn.date), october);
      final DebtAllocationsFilterView view = shares.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      // Every fourth sale is October's: 15 of the 60.
      expect(view.rows, hasLength(15));
      expect(
        view.rows.every((DebtAllocation a) => a.date!.startsWith('2026-10')),
        isTrue,
      );
      expect(bridge.searches, isEmpty);
      expect(shares.filterCount, 1);
    });

    test('a manager goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();

      await shares.toggleFilter(DebtAllocationsColumn.manager, 'Mühasib');
      expect(bridge.searches, <String>['Mühasib']);
      // `Mühasib-istehsal` holds `Mühasib` too, but is not it.
      final DebtAllocationsFilterView view = shares.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows, hasLength(20));
      expect(
        view.rows.every((DebtAllocation a) => a.manager == 'Mühasib'),
        isTrue,
      );
      expect(view.scans, isFalse);

      // Let go, the list is the list again.
      await shares.clearFilter();
      expect(shares.filtered, isNull);
      expect(shares.allocations, hasLength(20));
    });

    test('Menecer lists every manager with a share, the most collected '
        'first; the others list nothing', () async {
      final _Bridge bridge = _Bridge();
      final DebtAllocationsController shares = bridge.controller();
      await shares.ensureLoaded();
      final DebtAllocationsFilterValues values = shares.values;

      expect(shares.filterColumns, DebtAllocationsColumn.values);
      values.open(DebtAllocationsColumn.manager);
      expect(values.isSearching, isTrue);
      await pumpEventQueue();
      expect(values.isSearching, isFalse);
      expect(values.progress, isNull);
      expect(
        bridge.requests.last.path,
        endsWith('/onec-data/manager-debt-stats/'),
      );
      // `Menecer Borcları`' rows by what they collected — and 1C's doubled
      // space tidied for reading.
      expect(values.values, const <FilterValue>[
        FilterValue('Mühasib-istehsal', 'Mühasib-istehsal'),
        FilterValue('Nizami  S1', 'Nizami S1'),
        FilterValue('Mühasib', 'Mühasib'),
      ]);

      // What is typed narrows them on the phone.
      values.search('nizami');
      expect(values.values.map((FilterValue v) => v.value), <String>[
        'Nizami  S1',
      ]);

      // Read once: the next opening asks nothing.
      final int asked = bridge.requests.length;
      values.open(DebtAllocationsColumn.manager);
      await pumpEventQueue();
      expect(bridge.requests, hasLength(asked));
      expect(values.values, hasLength(3));

      values.open(DebtAllocationsColumn.share);
      expect(values.values, isEmpty);
      values.open(DebtAllocationsColumn.date);
      expect(values.values, isEmpty);
      expect(shares.rangeFieldOf(DebtAllocationsColumn.share)!.suffix, '₼');
      expect(
        shares.rangeFieldOf(DebtAllocationsColumn.share)!.minHint,
        'Min bölgü',
      );
      expect(shares.rangeFieldOf(DebtAllocationsColumn.manager), isNull);
      expect(shares.rangeFieldOf(DebtAllocationsColumn.date), isNull);
    });
  });
}

/// Sixty shares, the largest first as the bridge gives them: 1,000 ₼ down
/// by 10 a row, to 410 ₼. The managers take turns — `Mühasib-istehsal`,
/// `Mühasib`, `Nizami  S1` with 1C's doubled space — and the sales' months
/// run July to October, a row each.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 60;

  static const List<String> managers = <String>[
    'Mühasib-istehsal',
    'Mühasib',
    'Nizami  S1',
  ];

  DebtAllocationsController controller() {
    final DebtAllocationsController shares = DebtAllocationsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(shares.dispose);
    return shares;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': 1000 - i,
    'sale_id': 'sale-$i',
    'sale_date': '2026-${(7 + i % 4).toString().padLeft(2, '0')}-15',
    'manager': managers[i % 3],
    'allocated': 1000.0 - 10 * i,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final Map<String, String> query = request.url.queryParameters;
    final int page = int.parse(query['page']!);
    final int size = int.parse(query['page_size']!);

    if (request.url.path.endsWith('/onec-data/manager-debt-stats/')) {
      // In the bridge's order — the largest debt first — which is not the
      // most collected first.
      return _json(<String, Object?>{
        'total': 3,
        'data': <Object?>[
          <String, Object?>{'id': 13, 'manager': 'Mühasib', 'collected': 50.0},
          <String, Object?>{
            'id': 4,
            'manager': 'Nizami  S1',
            'collected': 900.0,
          },
          <String, Object?>{
            'id': 1,
            'manager': 'Mühasib-istehsal',
            'collected': 5000.0,
          },
        ],
      });
    }

    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['manager']}'.toLowerCase().contains(search.toLowerCase()))
          row,
    ];
    final int start = (page - 1) * size;
    return _json(<String, Object?>{
      'total': found.length,
      'page': page,
      'page_size': size,
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
      'table': 'manager_debt_allocations',
      'baza_id': 18,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
