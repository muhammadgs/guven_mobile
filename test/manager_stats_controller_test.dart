import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/manager_stats_controller.dart';
import 'package:guven_mobile/src/features/database/application/manager_stats_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/manager_stat.dart';
import 'package:guven_mobile/src/features/database/domain/manager_stats_filter.dart';

/// `Menecer statistikası` reads one manager's month off a bridge row, and its
/// filter finds what it is asked for in the whole table: a manager through
/// the bridge, a period — a start and an end month — and the figures on the
/// phone.
void main() {
  group('reading a row', () {
    test('the live row\'s fields', () {
      // Row 24 as the bridge answered on 2026-10-05: the design's card.
      final ManagerStat stat = ManagerStat.fromJson(<String, Object?>{
        'id': 24,
        'manager_id': '64317202-0ca2-11f1-abf8-bc24113ee005',
        'phys_id': '77c6aae1-6909-11f1-ac03-bc24113ee005',
        'manager': 'Mühasib-istehsal',
        'year': 2026,
        'month': 7,
        'month_label': '07.2026',
        'orders_count': 236,
        'total_amount': 218675.61,
        'baza_id': 18,
        'synced_at': '2026-09-23T17:05:23',
        'created_at': '2026-09-18T13:46:20.667559',
        'updated_at': '2026-09-18T13:46:20.667559',
      })!;

      expect(stat.id, 24);
      expect(stat.manager, 'Mühasib-istehsal');
      expect(stat.period, const FilterMonth(2026, 7));
      // 1C's label once — not the website's `07.2026 2026`.
      expect(stat.periodLabel, '07.2026');
      expect(stat.orders, 236);
      expect(stat.amount, 218675.61);
    });

    test('a month out of its label when the numbers are missing, and none '
        'out of nonsense', () {
      final ManagerStat labelled = ManagerStat.fromJson(<String, Object?>{
        'id': 1,
        'month_label': ' 8.2026 ',
      })!;
      expect(labelled.period, const FilterMonth(2026, 8));
      expect(labelled.periodLabel, '8.2026');

      final ManagerStat numbered = ManagerStat.fromJson(<String, Object?>{
        'id': 2,
        'year': '2025',
        'month': '12',
      })!;
      expect(numbered.periodLabel, '12.2025');

      final ManagerStat broken = ManagerStat.fromJson(<String, Object?>{
        'id': 3,
        'year': 2026,
        'month': 13,
        'month_label': '13.2026',
      })!;
      expect(broken.period, isNull);
      expect(broken.month, isNull);

      expect(
        ManagerStat.fromJson(<String, Object?>{'manager': 'GF20'}),
        isNull,
      );
    });
  });

  group('months and periods', () {
    test('a month counts on into the next year, and writes itself as 1C '
        'does', () {
      const FilterMonth november = FilterMonth(2025, 11);
      expect(november.plus(2), const FilterMonth(2026, 1));
      expect(november.plus(-11), const FilterMonth(2024, 12));
      expect(november < const FilterMonth(2026, 1), isTrue);
      expect(november.toString(), '11.2025');
      expect(const FilterMonth(2026, 7).toString(), '07.2026');
    });

    test('a period holds its ends, either of which may be open', () {
      const FilterMonth july = FilterMonth(2026, 7);
      const FilterMonth september = FilterMonth(2026, 9);
      const FilterPeriod summer = FilterPeriod(from: july, to: september);
      expect(summer.contains(july), isTrue);
      expect(summer.contains(const FilterMonth(2026, 8)), isTrue);
      expect(summer.contains(september), isTrue);
      expect(summer.contains(const FilterMonth(2026, 6)), isFalse);
      expect(summer.contains(const FilterMonth(2025, 8)), isFalse);

      // Written backwards, it is the same period.
      const FilterPeriod backwards = FilterPeriod(from: september, to: july);
      expect(backwards.ordered, summer);
      expect(backwards.contains(const FilterMonth(2026, 8)), isTrue);

      expect(
        const FilterPeriod(from: july).contains(const FilterMonth(2030, 1)),
        isTrue,
      );
      expect(
        const FilterPeriod(to: july).contains(const FilterMonth(2026, 8)),
        isFalse,
      );
      expect(FilterPeriod.any.isEmpty, isTrue);
    });
  });

  group('the filter\'s rules', () {
    const ManagerStat july = ManagerStat(
      id: 1,
      manager: 'Mühasib-istehsal',
      year: 2026,
      month: 7,
      orders: 236,
      amount: 218675.61,
    );
    const ManagerStat bare = ManagerStat(id: 2, manager: 'GF20');

    test('a manager is matched exactly, case and both i\'s set aside', () {
      final ManagerStatsFilter filter = ManagerStatsFilter.none.toggle(
        ManagerStatsColumn.manager,
        'MÜHASİB-İSTEHSAL',
      );
      expect(filter.matches(july), isTrue);
      expect(
        ManagerStatsFilter.none
            .toggle(ManagerStatsColumn.manager, 'Mühasib')
            .matches(july),
        isFalse,
      );
      expect(filter.searchColumn, ManagerStatsColumn.manager);
      expect(filter.columnCount, 1);
      // Tapped again, it is let go.
      expect(
        filter.toggle(ManagerStatsColumn.manager, 'MÜHASİB-İSTEHSAL'),
        ManagerStatsFilter.none,
      );
    });

    test('a period holds the months in it, and no row without one', () {
      ManagerStatsFilter period(FilterMonth? from, FilterMonth? to) =>
          ManagerStatsFilter.none.withPeriod(FilterPeriod(from: from, to: to));

      expect(
        period(
          const FilterMonth(2026, 7),
          const FilterMonth(2026, 9),
        ).matches(july),
        isTrue,
      );
      expect(period(const FilterMonth(2026, 8), null).matches(july), isFalse);
      expect(period(null, const FilterMonth(2026, 7)).matches(july), isTrue);
      expect(period(null, const FilterMonth(2026, 7)).matches(bare), isFalse);

      final ManagerStatsFilter one = period(const FilterMonth(2026, 7), null);
      expect(one.has(ManagerStatsColumn.period), isTrue);
      expect(one.columns, <ManagerStatsColumn>[ManagerStatsColumn.period]);
      // A period goes nowhere near the bridge's `search`.
      expect(one.searchColumn, isNull);
      expect(one.cleared(ManagerStatsColumn.period), ManagerStatsFilter.none);
      expect(one.withPeriod(FilterPeriod.any), ManagerStatsFilter.none);
    });

    test('a span holds the figures in it, and no row without one', () {
      ManagerStatsFilter span(ManagerStatsColumn column, double? min) =>
          ManagerStatsFilter.none.withRange(column, FilterRange(min: min));

      expect(span(ManagerStatsColumn.orders, 200).matches(july), isTrue);
      expect(span(ManagerStatsColumn.orders, 237).matches(july), isFalse);
      expect(span(ManagerStatsColumn.amount, 218675.61).matches(july), isTrue);
      expect(span(ManagerStatsColumn.amount, 0).matches(bare), isFalse);
      expect(span(ManagerStatsColumn.orders, 0).matches(bare), isFalse);

      // Every column at once, each counted once on the funnel.
      final ManagerStatsFilter all = span(ManagerStatsColumn.orders, 200)
          .withRange(ManagerStatsColumn.amount, const FilterRange(max: 300000))
          .withPeriod(const FilterPeriod(from: FilterMonth(2026, 7)))
          .toggle(ManagerStatsColumn.manager, 'Mühasib-istehsal');
      expect(all.columnCount, 4);
      expect(all.matches(july), isTrue);
    });
  });

  group('the controller', () {
    test('twenty at a time, and a period is looked for in the whole '
        'table', () async {
      final _Bridge bridge = _Bridge();
      final ManagerStatsController stats = bridge.controller();
      await stats.ensureLoaded();
      expect(stats.stats, hasLength(20));
      bridge.requests.clear();

      // December 2025 to January 2026: the second half of the table.
      await stats.setPeriod(
        ManagerStatsColumn.period,
        const FilterPeriod(
          from: FilterMonth(2025, 12),
          to: FilterMonth(2026, 1),
        ),
      );
      final ManagerStatsFilterView view = stats.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((ManagerStat s) => s.id), <int>[
        for (int i = 21; i <= 40; i++) i,
      ]);
      expect(view.scans, isTrue);
      expect(view.readOf, 40);
      // Every row read was the list's own.
      expect(stats.stats, hasLength(40));
      expect(bridge.searches, isEmpty);
      expect(stats.filterCount, 1);
      expect(
        stats.periodOf(ManagerStatsColumn.period).from,
        const FilterMonth(2025, 12),
      );

      // Let go, the list is the list again.
      await stats.setPeriod(ManagerStatsColumn.period, FilterPeriod.any);
      expect(stats.filtered, isNull);
      expect(stats.isFiltered, isFalse);
    });

    test('a manager goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final ManagerStatsController stats = bridge.controller();
      await stats.ensureLoaded();

      await stats.toggleFilter(ManagerStatsColumn.manager, 'Mühasib');
      final ManagerStatsFilterView view = stats.filtered!;
      expect(bridge.searches, <String>['Mühasib']);
      // `Mühasib-istehsal` and `Mühasib Köməkçisi` hold the word too, but
      // are other managers.
      expect(view.rows.map((ManagerStat s) => s.id), <int>[2, 12, 22, 32]);
      expect(view.scans, isFalse);
    });

    test('Menecer opens onto every manager, read once; Dövr reads the '
        'table for its calendar without waiting for it', () async {
      final _Bridge bridge = _Bridge();
      final ManagerStatsController stats = bridge.controller();
      await stats.ensureLoaded();
      final ManagerStatsFilterValues values = stats.values;
      expect(stats.periodMonthsOf(ManagerStatsColumn.period), <FilterMonth>{
        const FilterMonth(2026, 9),
        const FilterMonth(2026, 8),
      });

      values.open(ManagerStatsColumn.manager);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 40 qeyd oxundu');
      while (stats.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(stats.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      // Every manager once, in the order the bridge met them.
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Mühasib-istehsal',
        'Mühasib',
        'Mühasib Köməkçisi',
        for (int i = 3; i < 10; i++) 'Menecer $i',
      ]);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20'],
      );

      // Typed into, the list narrows on the phone — `kom` finds the
      // `Köməkçisi` — and the bridge is not asked.
      final int asked = bridge.requests.length;
      values.search('kom');
      expect(values.values.map((FilterValue v) => v.label), <String>[
        'Mühasib Köməkçisi',
      ]);

      // Dövr lists nothing — it is a calendar — and knows every month now.
      values.open(ManagerStatsColumn.period);
      expect(values.values, isEmpty);
      expect(values.isSearching, isFalse);
      expect(stats.periodMonthsOf(ManagerStatsColumn.period), <FilterMonth>{
        const FilterMonth(2026, 9),
        const FilterMonth(2026, 8),
        const FilterMonth(2026, 1),
        const FilterMonth(2025, 12),
      });
      expect(bridge.requests, hasLength(asked));
    });

    test(
      'Dövr opened first starts reading the table, and works meanwhile',
      () async {
        final _Bridge bridge = _Bridge();
        final ManagerStatsController stats = bridge.controller();
        await stats.ensureLoaded();
        final ManagerStatsFilterValues values = stats.values;

        values.open(ManagerStatsColumn.period);
        expect(stats.isReadingAll, isTrue);
        expect(values.isSearching, isFalse);
        while (stats.isReadingAll) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(stats.periodMonthsOf(ManagerStatsColumn.period), hasLength(4));
      },
    );

    test('Sifariş and Cəmi məbləğ are spans; Dövr is a period', () {
      final ManagerStatsController stats = _Bridge().controller();
      expect(stats.filterColumns, ManagerStatsColumn.values);
      expect(stats.rangeFieldOf(ManagerStatsColumn.amount)!.suffix, '₼');
      expect(stats.rangeFieldOf(ManagerStatsColumn.orders)!.suffix, isNull);
      expect(stats.rangeFieldOf(ManagerStatsColumn.period), isNull);
      expect(stats.rangeFieldOf(ManagerStatsColumn.manager), isNull);
      expect(stats.takesPeriod(ManagerStatsColumn.period), isTrue);
      expect(stats.takesPeriod(ManagerStatsColumn.amount), isFalse);
    });
  });
}

/// The table: forty rows in the bridge's order — the largest month first.
/// Ten managers, the first three all `Mühasib…`; each has a row for
/// September and August 2026, January 2026 and December 2025, in that
/// order down the table.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 40;

  ManagerStatsController controller() {
    final ManagerStatsController stats = ManagerStatsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(stats.dispose);
    return stats;
  }

  static String manager(int i) => switch (i % 10) {
    0 => 'Mühasib-istehsal',
    1 => 'Mühasib',
    2 => 'Mühasib Köməkçisi',
    final int k => 'Menecer $k',
  };

  static Map<String, Object?> row(int i) {
    final (int year, int month) = switch (i ~/ 10) {
      0 => (2026, 9),
      1 => (2026, 8),
      2 => (2026, 1),
      _ => (2025, 12),
    };
    return <String, Object?>{
      'id': i + 1,
      'manager': manager(i),
      'year': year,
      'month': month,
      'month_label': '${month.toString().padLeft(2, '0')}.$year',
      'orders_count': 300 - i * 5,
      'total_amount': 100000.0 - i * 1000,
    };
  }

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) row(i),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['manager']}'.toLowerCase().contains(search.toLowerCase()))
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
