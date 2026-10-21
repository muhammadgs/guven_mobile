import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/manager_debts_controller.dart';
import 'package:guven_mobile/src/features/database/application/manager_debts_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/manager_debt.dart';
import 'package:guven_mobile/src/features/database/domain/manager_debts_filter.dart';

/// `Menecer Borcları`: what a row says, the share of the sales collected —
/// the real one, never rounded up to 100% — and the filter, which finds a
/// manager through the bridge and every figure on the phone.
void main() {
  group('reading a row', () {
    test('the live row\'s fields', () {
      // Mühasib-istehsal as the bridge answered on 2026-10-21.
      final ManagerDebt row = ManagerDebt.fromJson(<String, Object?>{
        'id': 1,
        'manager_id': '64317202-0ca2-11f1-abf8-bc24113ee005',
        'phys_id': 'd1077aff-b195-11f1-ac09-bc24113ee005',
        'manager': 'Mühasib-istehsal',
        'orders_count': 668,
        'total_sales': 529495.28,
        'total_debet': 17349.99,
        'collected': 512145.29,
        'baza_id': 18,
        'synced_at': '2026-10-19T23:19:34',
      })!;

      expect(row.id, 1);
      expect(row.manager, 'Mühasib-istehsal');
      expect(row.orders, 668);
      expect(row.sales, 529495.28);
      expect(row.debt, 17349.99);
      expect(row.collected, 512145.29);
      // 96.7233…% — cut, not rounded.
      expect(row.collectedHundredths, 9672);
      expect(row.collectedPercent, 96.72);
      // And with no id, no row.
      expect(ManagerDebt.fromJson(<String, Object?>{'manager': 'X'}), isNull);
    });

    test('a manager still owed money never reads 100%', () {
      // Mühasib Köməkçisi on 2026-10-21: 98.9985% — the website's
      // `Math.round` says 99, and from 99.5% up it would say 100.
      const ManagerDebt assistant = ManagerDebt(
        id: 12,
        sales: 6230.85,
        debt: 62.4,
        collected: 6168.45,
      );
      expect(assistant.collectedHundredths, 9899);

      const ManagerDebt almost = ManagerDebt(
        id: 1,
        sales: 100000,
        debt: 0.01,
        collected: 99999.99,
      );
      expect(almost.collectedHundredths, 9999);

      const ManagerDebt settled = ManagerDebt(
        id: 8,
        sales: 40339.2,
        debt: 0,
        collected: 40339.2,
      );
      expect(settled.collectedHundredths, 10000);
    });

    test('no sales, no share; no `collected`, the sales less the debt', () {
      expect(
        const ManagerDebt(id: 1, sales: 0, collected: 0).collectedHundredths,
        isNull,
      );
      expect(
        const ManagerDebt(id: 1, collected: 5).collectedHundredths,
        isNull,
      );
      const ManagerDebt bare = ManagerDebt(id: 1, sales: 200, debt: 50);
      expect(bare.collected, 150);
      expect(bare.collectedHundredths, 7500);
      expect(const ManagerDebt(id: 1, sales: 200).collected, isNull);
    });
  });

  group('the filter\'s rules', () {
    const ManagerDebt top = ManagerDebt(
      id: 1,
      manager: 'Mühasib-istehsal',
      orders: 668,
      sales: 529495.28,
      debt: 17349.99,
      collected: 512145.29,
    );
    const ManagerDebt assistant = ManagerDebt(
      id: 12,
      manager: 'Mühasib  Köməkçisi',
      orders: 27,
      sales: 6230.85,
      debt: 62.4,
      collected: 6168.45,
    );
    const ManagerDebt unknown = ManagerDebt(id: 3, manager: 'Boş');

    ManagerDebtsFilter span(
      ManagerDebtsColumn column,
      double? min,
      double? max,
    ) => ManagerDebtsFilter.none.withRange(
      column,
      FilterRange(min: min, max: max),
    );

    test('a manager is matched whole, its spacing and case set aside', () {
      ManagerDebtsFilter only(String name) =>
          ManagerDebtsFilter.none.toggle(ManagerDebtsColumn.manager, name);
      expect(only('mühasib köməkçisi').matches(assistant), isTrue);
      // `Mühasib` is in `Mühasib-istehsal`, but is not it.
      expect(only('Mühasib').matches(top), isFalse);
      expect(only('Mühasib-istehsal').matches(top), isTrue);
    });

    test('every figure is a span, and a row without the figure is in none', () {
      expect(span(ManagerDebtsColumn.orders, 600, 700).matches(top), isTrue);
      expect(
        span(ManagerDebtsColumn.orders, 600, null).matches(assistant),
        isFalse,
      );
      expect(span(ManagerDebtsColumn.sales, 500000, null).matches(top), isTrue);
      expect(
        span(ManagerDebtsColumn.debt, null, 100).matches(assistant),
        isTrue,
      );
      expect(span(ManagerDebtsColumn.debt, null, 100).matches(top), isFalse);
      expect(
        span(ManagerDebtsColumn.collected, 6000, 7000).matches(assistant),
        isTrue,
      );
      for (final ManagerDebtsColumn column in ManagerDebtsColumn.values) {
        if (!column.takesRange) continue;
        expect(span(column, null, 1e12).matches(unknown), isFalse);
      }
    });

    test('the share span holds the figure the card prints', () {
      // The card says 98.99%, so a span ending at 98.99 holds it, though the
      // share itself is 98.9985%.
      expect(
        span(ManagerDebtsColumn.share, null, 98.99).matches(assistant),
        isTrue,
      );
      expect(
        span(ManagerDebtsColumn.share, 99, null).matches(assistant),
        isFalse,
      );
      expect(span(ManagerDebtsColumn.share, 96.72, 96.72).matches(top), isTrue);
    });

    test('only the manager goes to the bridge', () {
      final ManagerDebtsFilter figures = span(
        ManagerDebtsColumn.share,
        null,
        95,
      );
      expect(figures.searchColumn, isNull);
      final ManagerDebtsFilter named = figures.toggle(
        ManagerDebtsColumn.manager,
        'GF20',
      );
      expect(named.searchColumn, ManagerDebtsColumn.manager);
      expect(named.columns, <ManagerDebtsColumn>[
        ManagerDebtsColumn.manager,
        ManagerDebtsColumn.share,
      ]);
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(named.toggle(ManagerDebtsColumn.manager, 'GF20'), figures);
      expect(named.cleared(ManagerDebtsColumn.share).columnCount, 1);
      expect(
        figures.withRange(ManagerDebtsColumn.share, FilterRange.any),
        ManagerDebtsFilter.none,
      );
    });

    test('the columns are the card\'s fields, in its order', () {
      expect(ManagerDebtsColumn.values.map((c) => c.label), <String>[
        'Menecer',
        'Sifariş',
        'Satış',
        'Debet',
        'Yığılmış',
        'Statistika',
      ]);
    });
  });

  group('the controller', () {
    test('asks the bridge\'s address, twenty at a time', () async {
      final _Bridge bridge = _Bridge();
      final ManagerDebtsController debts = bridge.controller();
      await debts.ensureLoaded();
      expect(
        bridge.requests.single.path,
        endsWith('/onec-data/manager-debt-stats/'),
      );
      expect(bridge.requests.single.queryParameters['page_size'], '20');
      expect(debts.managerDebts, hasLength(20));
      expect(debts.hasEveryone, isFalse);
    });

    test('a share is looked for in the whole list', () async {
      final _Bridge bridge = _Bridge();
      final ManagerDebtsController debts = bridge.controller();
      await debts.ensureLoaded();
      bridge.requests.clear();

      // The largest debt first, so the lowest shares come first too: only
      // the first three collected 91% or less (90, 90.5, 91).
      await debts.setRange(
        ManagerDebtsColumn.share,
        const FilterRange(max: 91),
      );
      final ManagerDebtsFilterView view = debts.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((ManagerDebt d) => d.id), <int>[1, 2, 3]);
      expect(view.scans, isTrue);
      expect(view.readOf, _Bridge.count);
      expect(debts.managerDebts, hasLength(_Bridge.count));
      expect(bridge.searches, isEmpty);
    });

    test('a manager goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final ManagerDebtsController debts = bridge.controller();
      await debts.ensureLoaded();

      await debts.toggleFilter(ManagerDebtsColumn.manager, 'Menecer_1');
      expect(bridge.searches, <String>['Menecer_1']);
      // `Menecer_10` … `Menecer_19` hold `Menecer_1` too, but are not it.
      expect(debts.filtered!.rows.map((ManagerDebt d) => d.id), <int>[2]);
      expect(debts.filtered!.scans, isFalse);

      // Let go, the list is the list again.
      await debts.clearFilter();
      expect(debts.filtered, isNull);
      expect(debts.managerDebts, hasLength(20));
    });

    test('Menecer lists the managers on the phone; a figure lists nothing '
        'but its span', () async {
      final _Bridge bridge = _Bridge();
      final ManagerDebtsController debts = bridge.controller();
      await debts.ensureLoaded();
      final ManagerDebtsFilterValues values = debts.values;

      expect(debts.filterColumns, ManagerDebtsColumn.values);
      values.open(ManagerDebtsColumn.manager);
      expect(values.isSearching, isFalse);
      expect(values.progress, isNull);
      expect(values.values, hasLength(20));
      // In the list's order, 1C's doubled space tidied for reading.
      expect(values.values.first, const FilterValue('Menecer  0', 'Menecer 0'));

      values.open(ManagerDebtsColumn.share);
      expect(values.values, isEmpty);
      expect(debts.rangeFieldOf(ManagerDebtsColumn.share)!.suffix, '%');
      expect(debts.rangeFieldOf(ManagerDebtsColumn.debt)!.suffix, '₼');
      expect(debts.rangeFieldOf(ManagerDebtsColumn.orders)!.suffix, isNull);
      expect(debts.rangeFieldOf(ManagerDebtsColumn.manager), isNull);
    });
  });
}

/// Thirty managers, the largest debt first as the bridge gives them: each
/// sold 10,000 ₼, and the first owes 1,000 ₼ (90%), the next 50 ₼ less
/// each, down to nothing from the twenty-first on. The first is `Menecer
/// 0` with 1C's doubled space; the rest `Menecer_1` … `Menecer_29`.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 30;

  ManagerDebtsController controller() {
    final ManagerDebtsController debts = ManagerDebtsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(debts.dispose);
    return debts;
  }

  Map<String, Object?> _row(int i) {
    final double debt = i < 20 ? 1000.0 - 50 * i : 0;
    return <String, Object?>{
      'id': i + 1,
      'manager': i == 0 ? 'Menecer  0' : 'Menecer_$i',
      'orders_count': 100 + i,
      'total_sales': 10000.0,
      'total_debet': debt,
      'collected': 10000.0 - debt,
    };
  }

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int i = 0; i < count; i++) _row(i),
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
      'total': found.length,
      'page': page,
      'page_size': size,
      'data': <Object?>[
        for (int k = start; k < start + size && k < found.length; k++) found[k],
      ],
      'table': 'manager_debt_stats',
      'baza_id': 18,
    });
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
