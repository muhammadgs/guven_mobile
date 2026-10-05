import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/database/application/sales_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_page.dart';
import 'package:guven_mobile/src/features/database/domain/sale.dart';
import 'package:guven_mobile/src/features/database/presentation/database_format.dart';

/// `Satışlar` asks the bridge for as little as it can: a page at a time,
/// never past the end, never the same thing twice, and never mixes an answer
/// into a list that has since started over.
void main() {
  group('paging', () {
    test('asks for twenty at a time and stops at the total', () async {
      final _Bridge bridge = _Bridge(total: 40);
      final SalesController sales = bridge.controller();

      await sales.ensureLoaded();
      expect(bridge.pages, <int>[1]);
      expect(bridge.lastQuery['page_size'], '20');
      expect(sales.sales.map((Sale s) => s.id), _ids(1, 20));
      expect(sales.hasMore, isTrue);

      await sales.loadMore();
      expect(bridge.pages, <int>[1, 2]);
      expect(sales.sales, hasLength(40));
      // The total says page two was the end: no third request to find out.
      expect(sales.hasMore, isFalse);

      await sales.loadMore();
      expect(bridge.pages, <int>[1, 2]);
    });

    test('a short page is the last, with or without a total', () async {
      final _Bridge bridge = _Bridge(total: null, available: 27);
      final SalesController sales = bridge.controller();

      await sales.ensureLoaded();
      await sales.loadMore();
      expect(sales.sales, hasLength(27));
      expect(sales.hasMore, isFalse);

      await sales.loadMore();
      expect(bridge.pages, <int>[1, 2]);
    });

    test('coming back asks for nothing; only a pull does', () async {
      final _Bridge bridge = _Bridge(total: 40);
      final SalesController sales = bridge.controller();

      await sales.ensureLoaded();
      await sales.ensureLoaded();
      expect(bridge.pages, <int>[1]);

      await sales.refresh();
      expect(bridge.pages, <int>[1, 1]);
    });

    test(
      'documents pushed down a page by new ones are not shown twice',
      () async {
        // Two documents synced between the two requests: page two starts with
        // the last two of page one.
        final _Bridge bridge = _Bridge(total: 42, shiftAfterFirst: 2);
        final SalesController sales = bridge.controller();

        await sales.ensureLoaded();
        await sales.loadMore();

        final List<int> ids = sales.sales.map((Sale s) => s.id).toList();
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids, _ids(1, 38));
      },
    );

    test('asks once however often the list asks', () async {
      final _Bridge bridge = _Bridge(total: 100);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.hold();
      final Future<void> first = sales.loadMore();
      final Future<void> second = sales.loadMore();
      await pumpEventQueue();
      expect(bridge.pages, <int>[1, 2]);

      bridge.release();
      await Future.wait(<Future<void>>[first, second]);
      expect(bridge.pages, <int>[1, 2]);
      expect(sales.sales, hasLength(40));
    });

    test(
      'a page that lands after a pull started over is thrown away',
      () async {
        final _Bridge bridge = _Bridge(total: 100);
        final SalesController sales = bridge.controller();
        await sales.ensureLoaded();

        bridge.hold();
        final Future<void> late = sales.loadMore();
        await pumpEventQueue();

        // The pull's own page one is answered straight away…
        bridge.holdOnly = 2;
        await sales.refresh();
        expect(sales.sales, hasLength(20));

        // …and the page two asked for before it arrives afterwards.
        bridge.release();
        await late;
        expect(sales.sales, hasLength(20));
        expect(sales.isLoadingMore, isFalse);

        // The list goes on from page two of the new list.
        await sales.loadMore();
        expect(bridge.pages.last, 2);
        expect(sales.sales, hasLength(40));
      },
    );

    test('a failed page is not asked for again until asked to', () async {
      final _Bridge bridge = _Bridge(total: 100);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.failPage = 2;
      await sales.loadMore();
      expect(sales.moreError, isNotNull);
      expect(sales.sales, hasLength(20));

      // Scrolling on would call this on every frame; it must not hammer a
      // bridge that is not answering.
      await sales.loadMore();
      await sales.loadMore();
      expect(bridge.pages, <int>[1, 2]);

      bridge.failPage = null;
      await sales.retryMore();
      expect(sales.moreError, isNull);
      expect(sales.sales, hasLength(40));
    });

    test('a failed pull keeps the cards it would have replaced', () async {
      final _Bridge bridge = _Bridge(total: 100);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      bridge.failPage = 1;
      await sales.refresh();
      expect(sales.error, isNotNull);
      expect(sales.sales, hasLength(20));
    });
  });

  group('open cards', () {
    test('a document is fetched once, when its card first opens', () async {
      final _Bridge bridge = _Bridge(total: 40);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      final Sale row = sales.sales[4];

      expect(bridge.documents, isEmpty);
      sales.toggle(row);
      expect(sales.isExpanded(row.id), isTrue);
      expect(sales.isDocumentLoading(row.id), isTrue);
      await pumpEventQueue();

      expect(bridge.documents, <int>[row.id]);
      final Sale shown = sales.view(row);
      expect(shown.organization, 'NaTural-İD');
      expect(shown.lines, hasLength(2));
      expect(shown.lines!.first.product, 'Beef Tenderloin / Dana Can Əti');
      // The row's own fields survive where the document is silent.
      expect(shown.customer, row.customer);

      sales.toggle(row);
      sales.toggle(row);
      await pumpEventQueue();
      expect(bridge.documents, <int>[row.id]);
    });

    test('a row that already says everything needs no document', () async {
      final _Bridge bridge = _Bridge(total: 40, rowsCarryLines: true);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();

      sales.toggle(sales.sales.first);
      await pumpEventQueue();
      expect(bridge.documents, isEmpty);
      expect(sales.view(sales.sales.first).lines, hasLength(2));
    });

    test('a document that failed can be asked for again', () async {
      final _Bridge bridge = _Bridge(total: 40)..failDocuments = true;
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      final Sale row = sales.sales.first;

      sales.toggle(row);
      await pumpEventQueue();
      expect(sales.documentError(row.id), isNotNull);

      bridge.failDocuments = false;
      await sales.loadDocument(row.id);
      expect(sales.documentError(row.id), isNull);
      expect(sales.view(row).lines, hasLength(2));
      expect(bridge.documents, <int>[row.id, row.id]);
    });

    test('a pull shuts every card and forgets its document', () async {
      final _Bridge bridge = _Bridge(total: 40);
      final SalesController sales = bridge.controller();
      await sales.ensureLoaded();
      final Sale row = sales.sales.first;

      sales.toggle(row);
      await pumpEventQueue();
      await sales.refresh();

      expect(sales.isExpanded(row.id), isFalse);
      expect(sales.view(sales.sales.first).lines, isNull);

      sales.toggle(sales.sales.first);
      await pumpEventQueue();
      expect(bridge.documents, <int>[row.id, row.id]);
    });
  });

  group('reading a row', () {
    test('the website\'s fields, however the bridge spells them', () {
      final Sale sale = Sale.fromJson(<String, Object?>{
        'id': '7303',
        'order_number': 'NT000007303',
        'order_date': '2026-09-18T00:00:00',
        'customer': 'FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)',
        'manager': 'S_Vurğun_S1',
        'warehouse': '',
        'doc_type': 'invoice',
        'total_amount': '58.20',
        'is_posted': 1,
        'is_sold': 'false',
      })!;

      expect(sale.id, 7303);
      expect(sale.date, '2026-09-18');
      expect(sale.warehouse, isNull);
      expect(sale.docTypeLabel, 'Qaimə');
      expect(sale.amount, 58.20);
      expect(sale.currency, isNull);
      expect(sale.isPosted, isTrue);
      expect(sale.isSold, isFalse);
      expect(sale.lines, isNull);
      expect(sale.needsDocument, isTrue);
    });

    test('a row with no id is left out, and still counts towards a page', () {
      final DatabasePage<Sale> page = DatabasePage<Sale>.fromJson(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 1},
            <String, Object?>{'order_number': 'NT1'},
          ],
          'total': 2,
        },
        Sale.fromJson,
      );
      expect(page.rows, hasLength(1));
      expect(page.received, 2);
      expect(page.total, 2);
    });

    test('kinds the website names, and one it forgot to', () {
      String? label(String type) => Sale(id: 1, docType: type).docTypeLabel;
      expect(label('invoice'), 'Qaimə');
      expect(label('INVOICE'), 'Qaimə');
      expect(label('return'), 'Qaytarılma');
      expect(label('order'), 'Sifariş');
      expect(label('transfer'), 'transfer');
    });

    test('the day on the document, not the day in UTC', () {
      String? day(String value) =>
          readDocumentDate(<String, Object?>{'d': value}, <String>['d']);
      expect(day('2026-09-18'), '2026-09-18');
      expect(day('2026-09-18T00:00:00'), '2026-09-18');
      expect(day('18.09.2026 00:00:00'), '2026-09-18');
      final DateTime local = DateTime.utc(2026, 9, 17, 20).toLocal();
      expect(
        day('2026-09-17T20:00:00Z'),
        '${local.year}-${'${local.month}'.padLeft(2, '0')}-'
        '${'${local.day}'.padLeft(2, '0')}',
      );
    });
  });

  group('writing figures', () {
    test('amounts to the qəpik, grouped by thousands', () {
      expect(formatDecimal(58.2), '58.20');
      expect(formatDecimal(1234567.891), '1,234,567.89');
      expect(formatDecimal(-30.3), '-30.30');
      expect(formatDecimal(-0.001), '0.00');
    });

    test('quantities bare when whole, to the gram when not', () {
      expect(formatQuantity(1), '1');
      expect(formatQuantity(1.094), '1.094');
      expect(formatQuantity(1.6), '1.6');
      expect(formatQuantity(1250), '1,250');
      expect(formatQuantity(1250.5), '1,250.5');
    });
  });
}

Iterable<int> _ids(int from, int to) => <int>[
  for (int id = from; id <= to; id++) id,
];

/// A stand-in for the 1C bridge: [available] documents, newest first, served
/// twenty at a time, with every request written down.
class _Bridge {
  _Bridge({
    required this.total,
    int? available,
    this.shiftAfterFirst = 0,
    this.rowsCarryLines = false,
  }) : available = available ?? total ?? 0;

  /// What the answers say `total` is. Null leaves it out.
  final int? total;
  final int available;

  /// Documents that arrive after page one has been read, pushing everything
  /// down by this many places.
  final int shiftAfterFirst;

  /// Whether list rows carry their lines and organisation themselves.
  final bool rowsCarryLines;

  final List<int> pages = <int>[];
  final List<int> documents = <int>[];
  Map<String, String> lastQuery = const <String, String>{};

  int? failPage;
  bool failDocuments = false;

  Completer<void>? _gate;

  /// Only the page with this number waits at the gate; null holds them all.
  int? holdOnly;

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
    final RegExpMatch? document = RegExp(
      r'/onec-data/sales/(\d+)$',
    ).firstMatch(path);
    if (document != null) {
      final int id = int.parse(document.group(1)!);
      documents.add(id);
      if (failDocuments) return _json(<String, Object?>{'detail': 'x'}, 500);
      // The document does not repeat its id; it was asked for by it.
      return _json(<String, Object?>{
        'organization': 'NaTural-İD',
        'lines': _lines,
      });
    }

    lastQuery = request.url.queryParameters;
    final int page = int.parse(lastQuery['page']!);
    final int size = int.parse(lastQuery['page_size']!);
    pages.add(page);

    final Completer<void>? gate = _gate;
    if (gate != null && (holdOnly == null || holdOnly == page)) {
      await gate.future;
    }
    if (failPage == page) {
      return _json(<String, Object?>{'detail': 'Server xətası'}, 500);
    }

    // Newest first: the document at position p has id p + 1. Documents
    // synced after page one take the top places and push the rest down.
    final int shift = pages.length > 1 ? shiftAfterFirst : 0;
    final int count = available + shift;
    final int start = (page - 1) * size;
    final List<Object?> rows = <Object?>[
      for (int p = start; p < start + size && p < count; p++)
        _row(p < shift ? 1000 + p : p - shift + 1),
    ];
    return _json(<String, Object?>{
      'data': rows,
      if (total != null) 'total': total! + shift,
    });
  }

  Map<String, Object?> _row(int id) => <String, Object?>{
    'id': id,
    'order_number': 'NT${id.toString().padLeft(9, '0')}',
    'order_date': '2026-09-18T00:00:00',
    'customer': 'FAVORİT PREMİUM MARKETLƏR ŞƏBƏKƏSİ (URP)',
    'manager': 'S_Vurğun_S1',
    'warehouse': 'Nizami (6-cı Paralel) Anbarı',
    'doc_type': 'invoice',
    'total_amount': 58.2,
    'currency': 'AZN',
    'is_posted': true,
    'is_sold': id.isEven,
    if (rowsCarryLines) ...<String, Object?>{
      'organization': 'NaTural-İD',
      'lines': _lines,
    },
  };

  static const List<Object?> _lines = <Object?>[
    <String, Object?>{
      'product_name': 'Beef Tenderloin / Dana Can Əti',
      'quantity': 1.094,
      'price': '30.00',
      'amount': '32.82',
    },
    <String, Object?>{
      'product_name': 'Tushonka',
      'quantity': 1,
      'price': 27.9,
      'amount': 27.9,
    },
  ];
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
