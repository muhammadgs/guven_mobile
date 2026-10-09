import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/bank_accounts_controller.dart';
import 'package:guven_mobile/src/features/database/application/bank_accounts_filter_values.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/bank_account.dart';
import 'package:guven_mobile/src/features/database/domain/bank_accounts_filter.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';

/// `Bank Hesabları` reads an account the way the website does — a missing
/// currency as `AZN`, `is_default` as `Əsas` or `Əlavə`, the figures from
/// the account's own answer — and its filter finds what it is asked for in
/// the whole catalogue: a code, a name or a number through the bridge, a
/// bank, a currency, a kind or a status on the phone.
void main() {
  group('reading an account', () {
    test('the live row\'s fields', () {
      // Account 46 as the bridge answered on 2026-10-08.
      final BankAccount account = BankAccount.fromJson(<String, Object?>{
        'id': 46,
        'onec_guid': 'ad4c0279-0648-11f1-abf7-bc24113ee005',
        'code': 'NT0000001',
        'name': 'CARI-Pasha bank AZ60 (əsas)',
        'bank_name': 'Pasha bank',
        'account_number': 'AZ60PAHA40060AZNHC0100191890',
        'currency': 'AZN',
        'is_default': false,
        'is_active': true,
        'created_at': '2026-09-18T13:58:33.690206',
        'updated_at': '2026-09-18T13:58:33.690206',
        'baza_id': 18,
      })!;

      expect(account.id, 46);
      expect(account.code, 'NT0000001');
      expect(account.name, 'CARI-Pasha bank AZ60 (əsas)');
      expect(account.bankName, 'Pasha bank');
      expect(account.number, 'AZ60PAHA40060AZNHC0100191890');
      expect(account.currency, 'AZN');
      expect(account.kindLabel, 'Əlavə');
      expect(account.active, isTrue);
      // A row has none of the figures: they are the account's own answer's.
      expect(account.hasDetail, isFalse);
      expect(account.balance, isNull);
    });

    test('the account\'s own answer brings the figures, laid over the row', () {
      const BankAccount row = BankAccount(
        id: 46,
        code: 'NT0000001',
        name: 'CARI-Pasha bank AZ60 (əsas)',
        bankName: 'Pasha bank',
        isDefault: false,
        active: true,
      );
      final BankAccount detail = BankAccount.fromJson(<String, Object?>{
        'code': 'NT0000001',
        'name': 'CARI-Pasha bank AZ60 (əsas)',
        'bank_name': 'Pasha bank',
        'currency': 'AZN',
        'is_default': true,
        'is_active': true,
        'payments_count': 12,
        'total_in': 1500.5,
        'total_out': 200,
        'balance': 1300.5,
        'payments': <Object?>[],
      }, knownId: 46)!;

      final BankAccount open = row.mergedWith(detail);
      expect(open.id, 46);
      expect(open.hasDetail, isTrue);
      expect(open.paymentsCount, 12);
      expect(open.totalIn, 1500.5);
      expect(open.totalOut, 200);
      expect(open.balance, 1300.5);
      // The fresher answer wins.
      expect(open.kindLabel, 'Əsas');
    });

    test(
      'an account 1C names no currency for is in manat, as on the website',
      () {
        final BankAccount account = BankAccount.fromJson(<String, Object?>{
          'id': 3,
          'code': 'NT0000011',
          'name': 'Yeni hesab',
          'currency': '',
        })!;
        expect(account.currency, 'AZN');
        expect(account.kindLabel, isNull);
        expect(account.active, isNull);

        // And with no id, no account.
        expect(BankAccount.fromJson(<String, Object?>{'code': '1'}), isNull);
      },
    );
  });

  group('the filter\'s rules', () {
    const BankAccount pasha = BankAccount(
      id: 46,
      code: 'NT0000001',
      name: 'CARI-Pasha bank AZ60 (əsas)',
      bankName: 'Pasha bank',
      number: 'AZ60PAHA40060AZNHC0100191890',
      isDefault: false,
      active: true,
    );
    const BankAccount dollars = BankAccount(
      id: 48,
      code: 'NT0000008',
      name: 'USD',
      bankName: 'Pasha  bank',
      number: '1234567891234567891234567896',
      currency: 'USD',
      isDefault: true,
      active: false,
    );

    test('a value in every column', () {
      BankAccountsFilter only(BankAccountsColumn column, String value) =>
          BankAccountsFilter.none.toggle(column, value);

      expect(only(BankAccountsColumn.code, 'NT0000001').matches(pasha), isTrue);
      expect(
        only(BankAccountsColumn.code, 'NT0000001').matches(dollars),
        isFalse,
      );
      expect(
        only(
          BankAccountsColumn.name,
          'cari-pasha bank az60 (əsas)',
        ).matches(pasha),
        isTrue,
      );
      // 1C's doubled space is one space to the filter.
      expect(
        only(BankAccountsColumn.bank, 'Pasha bank').matches(dollars),
        isTrue,
      );
      expect(
        only(
          BankAccountsColumn.number,
          'AZ60PAHA40060AZNHC0100191890',
        ).matches(pasha),
        isTrue,
      );
      expect(only(BankAccountsColumn.currency, 'USD').matches(dollars), isTrue);
      expect(only(BankAccountsColumn.currency, 'USD').matches(pasha), isFalse);
      expect(
        only(
          BankAccountsColumn.kind,
          BankAccountKind.main.name,
        ).matches(dollars),
        isTrue,
      );
      expect(
        only(
          BankAccountsColumn.kind,
          BankAccountKind.extra.name,
        ).matches(pasha),
        isTrue,
      );
      expect(
        only(
          BankAccountsColumn.status,
          BankAccountStatus.inactive.name,
        ).matches(dollars),
        isTrue,
      );
      expect(
        only(
          BankAccountsColumn.status,
          BankAccountStatus.active.name,
        ).matches(dollars),
        isFalse,
      );
      // An account whose kind 1C does not say is neither.
      expect(
        only(
          BankAccountsColumn.kind,
          BankAccountKind.extra.name,
        ).matches(const BankAccount(id: 1)),
        isFalse,
      );
    });

    test('the code goes to the bridge first, then the name, then the '
        'number; nothing else can', () {
      BankAccountsFilter filter = BankAccountsFilter.none
          .toggle(BankAccountsColumn.bank, 'Pasha bank')
          .toggle(BankAccountsColumn.currency, 'AZN');
      expect(filter.searchColumn, isNull);

      filter = filter.toggle(BankAccountsColumn.number, 'AZ60');
      expect(filter.searchColumn, BankAccountsColumn.number);
      filter = filter.toggle(BankAccountsColumn.name, 'Pasha');
      expect(filter.searchColumn, BankAccountsColumn.name);
      filter = filter.toggle(BankAccountsColumn.code, 'NT0000001');
      expect(filter.searchColumn, BankAccountsColumn.code);

      // Five columns on the funnel; `Hamısı` lets one go.
      expect(filter.columnCount, 5);
      expect(filter.cleared(BankAccountsColumn.bank).columnCount, 4);
      // Chosen twice is let go.
      expect(filter.toggle(BankAccountsColumn.currency, 'AZN').columnCount, 4);
    });
  });

  group('the controller', () {
    test('twenty at a time, and a status is looked for in the whole '
        'catalogue', () async {
      final _Bridge bridge = _Bridge();
      final BankAccountsController accounts = bridge.controller();
      await accounts.ensureLoaded();
      expect(accounts.accounts, hasLength(20));
      expect(accounts.total, _Bridge.count);

      await accounts.setFilter(
        BankAccountsFilter.none.toggle(
          BankAccountsColumn.status,
          BankAccountStatus.inactive.name,
        ),
      );
      final BankAccountsFilterView view = accounts.filtered!;
      // Every seventh is switched off: 7, 14, 21, 28 — the first two among
      // the twenty already read, the rest further on.
      while (view.hasMore) {
        await view.loadMore();
      }
      expect(
        <int>[for (final BankAccount account in view.rows) account.id],
        <int>[28, 21, 14, 7],
      );
      expect(view.scans, isTrue);
      expect(bridge.searches, isEmpty);
    });

    test('a name goes to the bridge, and is checked exactly', () async {
      final _Bridge bridge = _Bridge();
      final BankAccountsController accounts = bridge.controller();
      await accounts.ensureLoaded();

      await accounts.setFilter(
        BankAccountsFilter.none.toggle(BankAccountsColumn.name, 'Pasha bank'),
      );
      final BankAccountsFilterView view = accounts.filtered!;
      expect(bridge.searches, <String>['Pasha bank']);
      // `Pasha bank 2` holds it too, but is another name.
      expect(
        <int>[for (final BankAccount account in view.rows) account.id],
        <int>[10],
      );
      expect(view.scans, isFalse);
    });

    test('Bank opens onto the whole catalogue, read once, the most common '
        'first', () async {
      final _Bridge bridge = _Bridge();
      final BankAccountsController accounts = bridge.controller();
      await accounts.ensureLoaded();
      final BankAccountsFilterValues values = accounts.values;

      values.open(BankAccountsColumn.bank);
      expect(values.isSearching, isTrue);
      expect(values.progress, isNotNull);
      await _settle();
      expect(accounts.hasEveryone, isTrue);
      expect(values.isSearching, isFalse);
      expect(
        <String>[for (final FilterValue value in values.values) value.label],
        <String>['Pasha bank', 'Kapital Bank', 'ABB'],
      );
      final int asked = bridge.requests.length;

      // And `Valyuta` has nothing left to read.
      values.open(BankAccountsColumn.currency);
      expect(values.isSearching, isFalse);
      expect(
        <String>[for (final FilterValue value in values.values) value.label],
        <String>['AZN', 'USD'],
      );
      expect(bridge.requests.length, asked);
    });

    test('Növ and Status offer both of their words', () {
      final BankAccountsController accounts = _Bridge().controller();
      final BankAccountsFilterValues values = accounts.values;

      values.open(BankAccountsColumn.kind);
      expect(values.values, const <FilterValue>[
        FilterValue('main', 'Əsas'),
        FilterValue('extra', 'Əlavə'),
      ]);
      values.open(BankAccountsColumn.status);
      expect(values.values, const <FilterValue>[
        FilterValue('active', 'Aktiv'),
        FilterValue('inactive', 'Deaktiv'),
      ]);
    });

    test('an open card asks for its account every time it opens, and shows '
        'what it knew meanwhile; a pull forgets it', () async {
      final _Bridge bridge = _Bridge();
      final BankAccountsController accounts = bridge.controller();
      await accounts.ensureLoaded();
      final BankAccount first = accounts.accounts.first;

      accounts.toggle(first);
      expect(accounts.isExpanded(first.id), isTrue);
      expect(accounts.isDetailLoading(first.id), isTrue);
      await _settle();
      expect(accounts.view(first).balance, 0);

      // Money moves. Opened again, the card is asked again — and while that
      // is on its way it is not loading: it shows what it knew.
      bridge.balances[first.id] = 250.75;
      accounts.toggle(first);
      accounts.toggle(first);
      expect(accounts.isDetailLoading(first.id), isFalse);
      expect(accounts.view(first).balance, 0);
      await _settle();
      expect(accounts.view(first).balance, 250.75);
      expect(bridge.details, <int>[first.id, first.id]);

      // Asked again and failing, it keeps the last answer and says nothing.
      bridge.failDetails = true;
      accounts.toggle(first);
      accounts.toggle(first);
      await _settle();
      expect(accounts.view(first).balance, 250.75);
      expect(accounts.detailError(first.id), isNull);

      // Never read, a failure is said.
      final BankAccount second = accounts.accounts[1];
      accounts.toggle(second);
      await _settle();
      expect(accounts.detailError(second.id), isNotNull);
      expect(accounts.view(second).hasDetail, isFalse);

      await accounts.refresh();
      expect(accounts.isExpanded(first.id), isFalse);
      expect(accounts.view(first).hasDetail, isFalse);
    });
  });
}

Future<void> _settle() async {
  for (int i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The catalogue: thirty accounts, by name as the bridge gives them. Every
/// fifth from the fifth keeps dollars, the rest manat; every seventh is
/// switched off; account 10 is `Pasha bank` and account 11 `Pasha bank 2`.
/// Half the accounts are held at Pasha bank, a third at Kapital Bank, the
/// rest at ABB.
class _Bridge {
  final List<Uri> requests = <Uri>[];

  /// The `search` of every list request that had one.
  final List<String> searches = <String>[];

  /// The id of every account asked for on its own.
  final List<int> details = <int>[];

  /// What each account's own answer says is left on it.
  final Map<int, double> balances = <int, double>{};

  bool failDetails = false;

  static const int count = 30;

  BankAccountsController controller() {
    final BankAccountsController accounts = BankAccountsController(
      DatabaseApi(
        ApiClient(tokens: TokenStore(), httpClient: MockClient(_answer)),
      ),
    );
    addTearDown(accounts.dispose);
    return accounts;
  }

  Map<String, Object?> _row(int id) => <String, Object?>{
    'id': id,
    'onec_guid': '00000000-0000-0000-0000-${id.toString().padLeft(12, '0')}',
    'code': 'NT00000${id.toString().padLeft(2, '0')}',
    'name': switch (id) {
      10 => 'Pasha bank',
      11 => 'Pasha bank 2',
      _ => 'Hesab $id',
    },
    'bank_name': switch (id % 6) {
      0 || 1 || 2 => 'Pasha bank',
      3 || 4 => 'Kapital Bank',
      _ => 'ABB',
    },
    'account_number': 'AZ${id.toString().padLeft(2, '0')}PAHA0000',
    'currency': id % 5 == 0 ? 'USD' : 'AZN',
    'is_default': id == 1,
    'is_active': id % 7 != 0,
  };

  late final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
    for (int id = count; id >= 1; id--) _row(id),
  ];

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request.url);
    final RegExpMatch? one = RegExp(
      r'/bank-accounts/(\d+)$',
    ).firstMatch(request.url.path);
    if (one != null) {
      final int id = int.parse(one.group(1)!);
      details.add(id);
      if (failDetails) {
        return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
      }
      return _json(<String, Object?>{
        ..._row(id),
        'payments_count': 0,
        'total_in': 0.0,
        'total_out': 0.0,
        'balance': balances[id] ?? 0.0,
        'payments': <Object?>[],
      });
    }

    final Map<String, String> query = request.url.queryParameters;
    final String? search = query['search'];
    if (search != null) searches.add(search);
    final List<Map<String, Object?>> found = <Map<String, Object?>>[
      for (final Map<String, Object?> row in _rows)
        if (search == null ||
            '${row['code']} ${row['name']} ${row['account_number']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
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
