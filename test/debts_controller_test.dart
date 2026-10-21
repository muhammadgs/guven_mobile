import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/debts_controller.dart';
import 'package:guven_mobile/src/features/database/application/debts_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/domain/debt.dart';
import 'package:guven_mobile/src/features/database/domain/debts_filter.dart';

/// `Kreditorlar` and `Debitorlar` are one list read from two places — and
/// their filter finds what it is asked for in the whole list: a
/// counterparty or a contract through the bridge, an organisation, an
/// amount or a status on the phone.
void main() {
  group('reading a debt', () {
    test('the live row\'s fields', () {
      // Creditor 1 as the bridge answered on 2026-10-20.
      final Debt debt = Debt.fromJson(<String, Object?>{
        'id': 1,
        'onec_guid': 'abef4caf-05cb-11f1-abf7-bc24113ee005',
        'contractor': 'ORXAN ƏT MMC   __',
        'contract_id': '8d5fc40e-05ce-11f1-abf7-bc24113ee005',
        'contract': '2026 Əsas müqavilə ',
        'total_debt': 482813.55,
        'settlement_total': 482813.55,
        'currency': 'AZN',
        'organization': 'NaTural-İD',
        'is_paid': false,
        'baza_id': 18,
        'synced_at': '2026-10-19T23:19:34',
      })!;

      expect(debt.id, 1);
      // As 1C spells it; the card tidies the spacing, the filter compares
      // past it.
      expect(debt.contractor, 'ORXAN ƏT MMC   __');
      expect(debt.contract, '2026 Əsas müqavilə');
      expect(debt.organization, 'NaTural-İD');
      expect(debt.debt, 482813.55);
      expect(debt.settlement, 482813.55);
      expect(debt.currency, 'AZN');
      expect(debt.paid, isFalse);
    });

    test('paid when 1C says so, or when nothing is owed — the website\'s '
        'test', () {
      Debt row(Map<String, Object?> fields) =>
          Debt.fromJson(<String, Object?>{'id': 1, ...fields})!;
      expect(row(<String, Object?>{'total_debt': 5.0}).paid, isFalse);
      expect(row(<String, Object?>{'total_debt': 0.0}).paid, isTrue);
      expect(
        row(<String, Object?>{'total_debt': 5.0, 'is_paid': true}).paid,
        isTrue,
      );
      // The website's own `=== 1`.
      expect(
        row(<String, Object?>{'total_debt': 5.0, 'is_paid': 1}).paid,
        isTrue,
      );
      // And with no id, no row.
      expect(Debt.fromJson(<String, Object?>{'contractor': 'X'}), isNull);
    });
  });

  group('the filter\'s rules', () {
    const Debt hotel = Debt(
      id: 1,
      contractor: 'ŞAMAXI PALACE   ___',
      contract: 'Əsas müqavilə',
      organization: 'NaTural-İD',
      debt: 101371.59,
      settlement: 101371.59,
      paidFlag: false,
    );
    const Debt settled = Debt(
      id: 2,
      contractor: 'WOLT',
      contract: '2026 Əsas müqavilə ',
      organization: 'NaTural-İD',
      debt: 0,
      settlement: 0,
    );
    const Debt unknown = Debt(id: 3, contractor: 'Boş');

    DebtsFilter only(DebtsColumn column, String value) =>
        DebtsFilter.none.toggle(column, value);

    test('a value in every column', () {
      // A name is matched with its spacing set aside.
      expect(
        only(DebtsColumn.contractor, 'ŞAMAXI PALACE ___').matches(hotel),
        isTrue,
      );
      expect(
        only(DebtsColumn.contract, 'Əsas müqavilə').matches(settled),
        isFalse,
      );
      expect(
        only(DebtsColumn.contract, '2026 Əsas müqavilə').matches(settled),
        isTrue,
      );
      expect(
        only(DebtsColumn.organization, 'natural-id').matches(hotel),
        isTrue,
      );
      expect(only(DebtsColumn.status, 'open').matches(hotel), isTrue);
      expect(only(DebtsColumn.status, 'paid').matches(settled), isTrue);
      expect(only(DebtsColumn.status, 'open').matches(settled), isFalse);
    });

    test('an amount span holds the amounts in it, and no row without one', () {
      DebtsFilter span(DebtsColumn column, double? min, double? max) =>
          DebtsFilter.none.withRange(column, FilterRange(min: min, max: max));
      for (final DebtsColumn amount in <DebtsColumn>[
        DebtsColumn.debt,
        DebtsColumn.ourDebt,
      ]) {
        expect(span(amount, 100000, 120000).matches(hotel), isTrue);
        expect(span(amount, 120000, null).matches(hotel), isFalse);
        expect(span(amount, null, 10).matches(unknown), isFalse);
      }
      expect(span(DebtsColumn.settlement, 100000, null).matches(hotel), isTrue);
      expect(span(DebtsColumn.settlement, 1, null).matches(settled), isFalse);
      expect(span(DebtsColumn.settlement, 0, 0).matches(settled), isTrue);
      expect(
        span(
          DebtsColumn.debt,
          1,
          2,
        ).withRange(DebtsColumn.debt, FilterRange.any),
        DebtsFilter.none,
      );
    });

    test('the counterparty goes to the bridge first, then the contract; the '
        'organisation never', () {
      final DebtsFilter filter = DebtsFilter.none
          .toggle(DebtsColumn.organization, 'NaTural-İD')
          .toggle(DebtsColumn.status, 'open');
      expect(filter.searchColumn, isNull);
      expect(
        filter.toggle(DebtsColumn.contract, 'Əsas müqavilə').searchColumn,
        DebtsColumn.contract,
      );
      expect(
        filter
            .toggle(DebtsColumn.contract, 'Əsas müqavilə')
            .toggle(DebtsColumn.contractor, 'WOLT')
            .searchColumn,
        DebtsColumn.contractor,
      );
      // Tapped again, a value is let go; `Hamısı` lets go of a column.
      expect(filter.toggle(DebtsColumn.status, 'open').columns, <DebtsColumn>[
        DebtsColumn.organization,
      ]);
      expect(filter.cleared(DebtsColumn.organization).columnCount, 1);
    });

    test('each list names the amount the way its card does', () {
      expect(DebtsColumn.of(DebtKind.creditors).map((c) => c.label), <String>[
        'Kontraqent',
        'Təşkilat',
        'Müqavilə',
        'Borcumuz',
        'Hesablaşma',
        'Status',
      ]);
      expect(DebtsColumn.of(DebtKind.debitors).map((c) => c.label), <String>[
        'Kontraqent',
        'Təşkilat',
        'Müqavilə',
        'Borc',
        'Hesablaşma',
        'Status',
      ]);
    });
  });

  group('the controller', () {
    test('each list asks its own address', () async {
      for (final DebtKind kind in DebtKind.values) {
        final _Bridge bridge = _Bridge();
        final DebtsController debts = bridge.controller(kind);
        await debts.ensureLoaded();
        expect(debts.kind, kind);
        expect(
          bridge.requests.single.path,
          endsWith('/onec-data/${kind.endpoint}/'),
        );
      }
    });

    test('twenty at a time, and an amount is looked for in the whole '
        'list', () async {
      final _Bridge bridge = _Bridge();
      final DebtsController debts = bridge.controller(DebtKind.creditors);
      await debts.ensureLoaded();
      expect(debts.debts, hasLength(20));
      bridge.requests.clear();

      // The largest first: only the last two owe under 2,000 ₼.
      await debts.setRange(DebtsColumn.ourDebt, const FilterRange(max: 2000));
      final DebtsFilterView view = debts.filtered!;
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(view.rows.map((Debt d) => d.id), <int>[59, 60]);
      expect(view.scans, isTrue);
      expect(view.readOf, 60);
      // Every row read was the list's own, and the page grew while nothing
      // matched.
      expect(debts.debts, hasLength(60));
      expect(bridge.searches, isEmpty);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '40'],
      );
    });

    test('a contract goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final DebtsController debts = bridge.controller(DebtKind.debitors);
      await debts.ensureLoaded();

      await debts.toggleFilter(DebtsColumn.contract, '2026 Əsas müqavilə');
      final DebtsFilterView view = debts.filtered!;
      expect(bridge.searches, <String>['2026 Əsas müqavilə']);
      expect(view.rows, hasLength(15));
      expect(view.rows.every((Debt d) => d.id % 4 == 1), isTrue);
      expect(view.scans, isFalse);

      // `Əsas müqavilə` is in `2026 Əsas müqavilə` too, but is not it.
      await debts.toggleFilter(DebtsColumn.contract, 'Əsas müqavilə');
      while (debts.filtered!.hasMore) {
        await debts.filtered!.loadMore();
      }
      expect(debts.filtered!.rows.any((Debt d) => d.id % 4 == 1), isFalse);

      // Let go, the list is the list again.
      await debts.clearFilter();
      expect(debts.filtered, isNull);
      expect(debts.debts, hasLength(20));
    });

    test('Müqavilə opens onto the whole list, read once', () async {
      final _Bridge bridge = _Bridge();
      final DebtsController debts = bridge.controller(DebtKind.creditors);
      await debts.ensureLoaded();
      final DebtsFilterValues values = debts.values;

      values.open(DebtsColumn.contract);
      expect(values.isSearching, isTrue);
      expect(values.values, isEmpty);
      expect(values.progress, '20 / 60 kreditor oxundu');
      while (debts.isReadingAll) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(debts.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      // The most common first, spelt tidily.
      expect(values.values, const <FilterValue>[
        FilterValue('Əsas müqavilə', 'Əsas müqavilə'),
        FilterValue('2026 Əsas müqavilə', '2026 Əsas müqavilə'),
        FilterValue(
          '08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M',
          '08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M',
        ),
      ]);
      expect(
        bridge.requests.map((Uri u) => u.queryParameters['page_size']),
        <String>['20', '20', '40'],
      );

      // The other columns list theirs at once now, asking nothing.
      final int asked = bridge.requests.length;
      values.open(DebtsColumn.contractor);
      expect(values.values, hasLength(60));
      values.open(DebtsColumn.organization);
      expect(values.values, const <FilterValue>[
        FilterValue('NaTural-İD', 'NaTural-İD'),
        FilterValue('Güvən  MMC', 'Güvən MMC'),
      ]);
      expect(bridge.requests, hasLength(asked));
    });

    test('Status offers both, and an amount lists nothing but its span', () {
      final DebtsController debts = _Bridge().controller(DebtKind.debitors);
      final DebtsFilterValues values = debts.values;
      expect(debts.filterColumns, DebtsColumn.of(DebtKind.debitors));
      values.open(DebtsColumn.status);
      expect(values.values, const <FilterValue>[
        FilterValue('open', 'Açıq borc'),
        FilterValue('paid', 'Ödənilib'),
      ]);
      values.open(DebtsColumn.debt);
      expect(values.values, isEmpty);
      expect(debts.rangeFieldOf(DebtsColumn.debt)!.suffix, '₼');
      expect(debts.rangeFieldOf(DebtsColumn.settlement)!.suffix, '₼');
      expect(debts.rangeFieldOf(DebtsColumn.contract), isNull);
    });
  });
}

/// A list of sixty debts, the largest first as the bridge gives them:
/// 59,500 ₼ down by a thousand a row, the last two under 2,000. Every
/// fourth from the first is under `2026 Əsas müqavilə ` (1C's trailing
/// space), the eighth under a long dated contract, the rest `Əsas
/// müqavilə`; the twelfth is signed by another organisation.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  static const int count = 60;

  DebtsController controller(DebtKind kind) {
    final DebtsController debts = DebtsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
      kind,
    );
    addTearDown(debts.dispose);
    return debts;
  }

  Map<String, Object?> _row(int i) => <String, Object?>{
    'id': i + 1,
    'contractor': 'Kontraqent $i MMC',
    'contract': switch (i) {
      7 => '08.09.2025 CI IL TARIXLI 080925 SAYLI ALQI SATQI M',
      _ when i % 4 == 0 => '2026 Əsas müqavilə ',
      _ => 'Əsas müqavilə',
    },
    'organization': i == 11 ? 'Güvən  MMC' : 'NaTural-İD',
    'total_debt': (count - i) * 1000.0 - 500,
    'settlement_total': (count - i) * 1000.0 - 500,
    'currency': 'AZN',
    'is_paid': false,
  };

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
            '${row['contractor']} ${row['contract']}'.toLowerCase().contains(
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
