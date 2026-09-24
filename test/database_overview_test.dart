import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/api_config.dart';
import 'package:guven_mobile/src/core/network/api_exception.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_metric.dart';
import 'package:guven_mobile/src/features/database/domain/database_overview.dart';

/// `Əsas panel` is ten numbers read out of four answers, and every one of them
/// has to land on the right row: the website shows the same ten, and the two
/// disagreeing about a debt is the worst thing this screen could do.
///
/// The shapes below are the ones `one_c_dashboard.js` reads — the contract the
/// site already depends on — including the quoted decimals a Python `Decimal`
/// turns into.
void main() {
  group('reading the answers', () {
    test('every figure comes from where the website takes it', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        summary: _summary,
        products: _page(475),
        customers: _page(312),
        orders: _page(7224),
      );

      expect(overview.products, 475);
      expect(overview.customers, 312);
      expect(overview.orders, 7224);
      expect(overview.salesDocuments, 7204);
      expect(overview.stockRecords, 730);
      expect(overview.team, 61);
      expect(overview.creditors, 58);
      expect(overview.debitors, 64);
      expect(overview.salesAmount, closeTo(1455475.61, 1e-6));
      // What the customers owe plus what the managers owe.
      expect(overview.debtLoad, closeTo(905035.18 + 200000, 1e-6));
    });

    test('valueOf reaches every row', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        summary: _summary,
        products: _page(475),
        customers: _page(312),
        orders: _page(7224),
      );

      for (final DatabaseMetric metric in DatabaseMetric.values) {
        expect(overview.valueOf(metric), isNotNull, reason: metric.label);
      }
    });

    test('a summary in a data envelope reads the same', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        summary: <String, Object?>{'success': true, 'data': _summary},
      );

      expect(overview.team, 61);
      expect(overview.salesAmount, closeTo(1455475.61, 1e-6));
    });

    test('what nobody could read stays unknown rather than zero', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        summary: <String, Object?>{
          'counts': <String, Object?>{'sales': 12},
          'totals': <String, Object?>{},
        },
      );

      expect(overview.salesDocuments, 12);
      expect(overview.stockRecords, isNull);
      expect(overview.products, isNull);
      expect(overview.salesAmount, isNull);
      expect(overview.debtLoad, isNull);
    });

    test('one half of the debt is still a debt', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        summary: <String, Object?>{
          'totals': <String, Object?>{'debitor_debt': 1500},
        },
      );

      expect(overview.debtLoad, 1500);
    });

    test('a page length is not a total', () {
      // Asked for one row at a time, a list that forgot its `total` would
      // otherwise report a catalogue of exactly one.
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        products: <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 1},
          ],
        },
      );

      expect(overview.products, isNull);
    });

    test('a list that does not page is counted whole', () {
      final DatabaseOverview overview = DatabaseOverview.fromResponses(
        customers: <Object?>[
          <String, Object?>{'id': 1},
          <String, Object?>{'id': 2},
        ],
      );

      expect(overview.customers, 2);
    });
  });

  group('asking the bridge', () {
    test('goes to the 1C bridge, not the main API, for all four', () async {
      final List<Uri> asked = <Uri>[];
      final DatabaseApi api = _api((http.Request request) async {
        asked.add(request.url);
        return _answer(request);
      });

      await api.overview();

      expect(asked, hasLength(4));
      for (final Uri uri in asked) {
        expect('${uri.scheme}://${uri.authority}', kOnecApiOrigin);
      }
      expect(
        asked.map((Uri uri) => uri.path),
        containsAll(<String>[
          '/api/v1/onec-data/summary/',
          '/api/v1/products/',
          '/api/v1/customers/',
          '/api/v1/orders/',
        ]),
      );
      // The lists are asked only for their totals.
      for (final Uri uri in asked.where(
        (Uri uri) => !uri.path.contains('summary'),
      )) {
        expect(uri.queryParameters['page_size'], '1');
      }
    });

    test('reads every figure off the four answers', () async {
      final DatabaseOverview overview = await _api(_answer).overview();

      expect(overview.products, 475);
      expect(overview.orders, 7224);
      expect(overview.stockRecords, 730);
      expect(overview.salesAmount, closeTo(1455475.61, 1e-6));
    });

    test('one answer failing leaves the others standing', () async {
      final DatabaseOverview overview = await _api((
        http.Request request,
      ) async {
        if (request.url.path.contains('summary')) {
          return http.Response('{"detail": "Sync gedir"}', 503);
        }
        return _answer(request);
      }).overview();

      expect(overview.products, 475);
      expect(overview.customers, 312);
      expect(overview.salesDocuments, isNull);
      expect(overview.debtLoad, isNull);
    });

    test('all four failing is a failure, in the bridge\'s own words', () async {
      final DatabaseApi api = _api(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object?>{'detail': 'Baza tapılmadı'}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );

      await expectLater(
        api.overview(),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.status, 'status', 404)
              .having(
                (ApiException e) => e.message,
                'message',
                'Baza tapılmadı',
              ),
        ),
      );
    });
  });
}

DatabaseApi _api(Future<http.Response> Function(http.Request) handler) {
  return DatabaseApi(
    ApiClient(tokens: TokenStore(), httpClient: MockClient(handler)),
  );
}

Future<http.Response> _answer(http.Request request) async {
  final String path = request.url.path;
  final Object body = path.endsWith('/onec-data/summary/')
      ? _summary
      : path.endsWith('/products/')
      ? _page(475)
      : path.endsWith('/customers/')
      ? _page(312)
      : _page(7224);
  return http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

/// The summary, spelled the way the website reads it — counts as numbers,
/// amounts as a mix of numbers and quoted decimals.
const Map<String, Object?> _summary = <String, Object?>{
  'counts': <String, Object?>{
    'sales': 7204,
    'stock': 730,
    'team': 61,
    'creditors': 58,
    'debitors': 64,
    'manager_stats': 12,
  },
  'totals': <String, Object?>{
    'sales_amount': '1455475.61',
    'creditor_debt': 51000.5,
    'debitor_debt': '905035.18',
    'manager_debet': 200000,
  },
};

/// One page of a list, one row long, carrying the list's real length.
Map<String, Object?> _page(int total) => <String, Object?>{
  'data': <Object?>[
    <String, Object?>{'id': 1},
  ],
  'total': total,
  'page': 1,
  'page_size': 1,
};
