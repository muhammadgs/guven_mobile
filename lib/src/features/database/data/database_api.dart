import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../domain/bank_account.dart';
import '../domain/cash_desk.dart';
import '../domain/customer.dart';
import '../domain/database_overview.dart';
import '../domain/database_page.dart';
import '../domain/manager_stat.dart';
import '../domain/order.dart';
import '../domain/product.dart';
import '../domain/sale.dart';
import '../domain/stock_item.dart';
import '../domain/team_member.dart';
import '../domain/warehouse.dart';

/// The calls behind the `Baza` tab, all of them to the 1C bridge.
///
/// None of them names a company: the bridge reads the company's 1C database
/// out of the bearer token, the same one the main API issued, and answers for
/// that company alone.
class DatabaseApi {
  const DatabaseApi(this._client);

  final ApiClient _client;

  /// A list asked for only for its `total`. One row is the least a page can
  /// hold; the rows themselves are thrown away.
  static const Map<String, String> _totalOnly = <String, String>{
    'page': '1',
    'page_size': '1',
  };

  /// Everything `Əsas panel` shows.
  ///
  /// The four requests run concurrently and each one falls back to nothing on
  /// its own, the way the home screen's do: a bridge whose `orders` table is
  /// mid-sync should not blank the other nine figures. Only when all four fail
  /// is the failure passed on — the summary's, which is the one that says the
  /// most.
  Future<DatabaseOverview> overview() async {
    final List<_Part> parts = await Future.wait<_Part>(<Future<_Part>>[
      _part(() => _get('/onec-data/summary/')),
      _part(() => _get('/products/', query: _totalOnly)),
      _part(() => _get('/customers/', query: _totalOnly)),
      _part(() => _get('/orders/', query: _totalOnly)),
    ]);

    if (parts.every((_Part part) => part.failure != null)) {
      throw parts.first.failure!;
    }

    return DatabaseOverview.fromResponses(
      summary: parts[0].payload,
      products: parts[1].payload,
      customers: parts[2].payload,
      orders: parts[3].payload,
    );
  }

  /// One page of `Satışlar`, newest first — the bridge's order, which is
  /// `order_date DESC, id DESC` without exception.
  ///
  /// [search] is one substring over the document number, the customer and
  /// the manager — nothing else, probed on 2026-09-24. [status] is the
  /// website's own filter and is passed through untouched, but the bridge
  /// answers every value the website sends with an empty list, so nothing in
  /// the app sends it.
  Future<DatabasePage<Sale>> salesPage({
    required int page,
    required int pageSize,
    String? search,
    String? status,
  }) async {
    final Object? payload = await _get(
      '/onec-data/sales/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return DatabasePage<Sale>.fromJson(payload, Sale.fromJson);
  }

  /// One page of `Stok`, the most of anything first — the bridge's order,
  /// which is `quantity DESC, id DESC` without exception: not one inversion
  /// in all 799 rows, walked on 2026-09-25.
  ///
  /// [search] is one case-insensitive substring over the product's code, its
  /// name and the warehouse; the endpoint takes nothing else — a warehouse,
  /// a date, a sort — and silently ignores whatever else it is sent.
  Future<DatabasePage<StockItem>> stockPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/onec-data/stock/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<StockItem>.fromJson(payload, StockItem.fromJson);
  }

  /// One page of `Sifarişlər`, in the bridge's order — `id DESC`, which is
  /// *not* the date's: the table is three runs synced at different times,
  /// each oldest first (walked on 2026-09-27: 2026-09-16…09-23, two rows of
  /// 09-18, then 2026-04-25…09-18). The website lists them the same way.
  ///
  /// [search] is one substring of the order's number, and nothing else — not
  /// an amount, a day or a status. [status] is the order's own `status`
  /// word, matched exactly (`delivered`, not `Çatdırıldı`), and narrows a
  /// [search] too. Nothing else is honoured; `payment_status` is silently
  /// ignored. `page_size` goes to 200.
  Future<DatabasePage<Order>> ordersPage({
    required int page,
    required int pageSize,
    String? search,
    String? status,
  }) async {
    final Object? payload = await _get(
      '/orders/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return DatabasePage<Order>.fromJson(payload, Order.fromJson);
  }

  /// One order in full: its row, plus what only this answer carries — the
  /// discount, the tax and what has been paid.
  Future<Order> order(int id) async {
    final Object? payload = await _get('/orders/$id');
    final Map<String, Object?> body = asMap(payload);
    // Bare, the way the website reads it; a `data` envelope is accepted too.
    final Object? data = body['data'];
    return Order.fromJson(data is Map ? asMap(data) : body, knownId: id)!;
  }

  /// One page of `Məhsullar`, in the bridge's order — `id ASC` without
  /// exception, walked on 2026-09-29: 593 products, 354 KB in all.
  ///
  /// [search] is one case-insensitive substring over the product's code and
  /// its name; nothing else is honoured — not a category, a price or a sort
  /// — and whatever else is sent is silently ignored. `page_size` goes to
  /// 500.
  Future<DatabasePage<Product>> productsPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/products/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<Product>.fromJson(payload, Product.fromJson);
  }

  /// One product in full: its row, plus what only this answer carries — its
  /// balance in every warehouse that holds any.
  Future<Product> product(int id) async {
    final Object? payload = await _get('/products/$id');
    final Map<String, Object?> body = asMap(payload);
    // Bare, the way the website reads it; a `data` envelope is accepted too.
    final Object? data = body['data'];
    return Product.fromJson(data is Map ? asMap(data) : body, knownId: id)!;
  }

  /// One page of `Müştərilər`, in the bridge's order — `id ASC` without
  /// exception, walked on 2026-10-04: 310 customers, ~150 KB in all.
  ///
  /// [search] is one case-insensitive substring over the customer's name,
  /// its code and its VÖEN; nothing else is honoured — not the kind, not a
  /// sort — and whatever else is sent is silently ignored. `page_size` goes
  /// to 500.
  Future<DatabasePage<Customer>> customersPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/customers/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<Customer>.fromJson(payload, Customer.fromJson);
  }

  /// One customer in full: its row, plus what only this answer carries —
  /// the role and the legal status.
  Future<Customer> customer(int id) async {
    final Object? payload = await _get('/customers/$id');
    final Map<String, Object?> body = asMap(payload);
    // Bare, the way the website reads it; a `data` envelope is accepted too.
    final Object? data = body['data'];
    return Customer.fromJson(data is Map ? asMap(data) : body, knownId: id)!;
  }

  /// One page of `Komanda`, the staff register, in the bridge's order — by
  /// name, walked on 2026-10-05: 61 people, ~15 KB in all.
  ///
  /// [search] is one case-insensitive substring over the person's code,
  /// name, position and department; nothing else is honoured — not the
  /// status, not a sort — and whatever else is sent is silently ignored.
  /// `page_size` goes to 500. There is no answer for one person on their
  /// own.
  Future<DatabasePage<TeamMember>> teamPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/onec-data/team/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<TeamMember>.fromJson(payload, TeamMember.fromJson);
  }

  /// One page of `Menecer statistikası` — a row a manager a month — in the
  /// bridge's order, the largest month first: `total_amount DESC`, walked on
  /// 2026-10-05, 34 rows and ~12 KB in all.
  ///
  /// [search] is one case-insensitive substring of the manager's name, and
  /// nothing else — not a month, a year or a figure; `year`, `month` and
  /// every other parameter are silently ignored. `page_size` goes to 500.
  Future<DatabasePage<ManagerStat>> managerStatsPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/onec-data/manager-stats/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<ManagerStat>.fromJson(payload, ManagerStat.fromJson);
  }

  /// One page of `Kassalar`, the cash desks in 1C's catalogue, in the
  /// bridge's order — the newest first, `id DESC` — read on 2026-10-05:
  /// three desks, 746 bytes in all.
  ///
  /// [search] is one case-insensitive substring over the desk's code and
  /// name; nothing else is honoured — not the currency, not the status —
  /// and whatever else is sent is silently ignored. `page_size` goes to
  /// 500. There is no answer for one desk on its own.
  Future<DatabasePage<CashDesk>> cashDesksPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/cash-desks/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<CashDesk>.fromJson(payload, CashDesk.fromJson);
  }

  /// One page of `Bank Hesabları`, the bank accounts in 1C's catalogue, in
  /// the bridge's order — by name, read on 2026-10-08: ten accounts, ~3 KB
  /// in all.
  ///
  /// [search] is one case-insensitive substring over the account's code,
  /// name and number; nothing else is honoured — not the bank, not the
  /// currency, not the kind or the status — and whatever else is sent is
  /// silently ignored. `page_size` goes to 500.
  Future<DatabasePage<BankAccount>> bankAccountsPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/bank-accounts/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<BankAccount>.fromJson(payload, BankAccount.fromJson);
  }

  /// One account in full: its row, plus what only this answer carries — how
  /// many payments, what came in and went out, and the balance (~0.16 s).
  Future<BankAccount> bankAccount(int id) async {
    final Object? payload = await _get('/bank-accounts/$id');
    final Map<String, Object?> body = asMap(payload);
    // Bare, the way the website reads it; a `data` envelope is accepted too.
    final Object? data = body['data'];
    return BankAccount.fromJson(data is Map ? asMap(data) : body, knownId: id)!;
  }

  /// One page of `Anbarlar`, the warehouses in 1C's catalogue, in the
  /// bridge's order — by name, byte by byte, so `istehsalat` comes last —
  /// read on 2026-10-09: seven warehouses, 1.7 KB in all.
  ///
  /// [search] is one case-insensitive substring of the name; nothing else
  /// is honoured — not the kind, not the status — and whatever else is sent
  /// is silently ignored. `page_size` goes to 500. There is no answer for
  /// one warehouse on its own.
  Future<DatabasePage<Warehouse>> warehousesPage({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      '/warehouses/',
      query: <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return DatabasePage<Warehouse>.fromJson(payload, Warehouse.fromJson);
  }

  /// The warehouses' names, out of the catalogue: seven of them on
  /// 2026-09-25, spelt exactly as a stock row spells its own.
  Future<List<String>> warehouseNames() =>
      _names('/warehouses/', pageSize: 100);

  /// One sale document in full. The list's rows already carry the
  /// organisation and the product lines; this is for a row that came without
  /// them.
  Future<Sale> sale(int id) async {
    final Object? payload = await _get('/onec-data/sales/$id');
    final Map<String, Object?> body = asMap(payload);
    // Bare, the way the website reads it; a `data` envelope is accepted too.
    final Object? data = body['data'];
    return Sale.fromJson(data is Map ? asMap(data) : body, knownId: id)!;
  }

  /// Names out of the customer catalogue, [search] narrowing them the way
  /// the bridge narrows everything: one substring.
  ///
  /// The catalogue writes a name exactly as a sale document does — spacing
  /// and all — because both come out of the same 1C directory.
  Future<List<String>> customerNames({String? search, int pageSize = 30}) =>
      _names('/customers/', search: search, pageSize: pageSize);

  /// Names out of the product catalogue.
  Future<List<String>> productNames({String? search, int pageSize = 30}) =>
      _names('/products/', search: search, pageSize: pageSize);

  /// Every manager who has sold anything, out of the monthly manager
  /// figures: one row a manager a month, a few dozen rows in all, and the
  /// only list the bridge keeps of the names a sale document carries —
  /// `/onec-data/team/` is the staff register, whose names are people's, not
  /// the 1C users' a document is signed with.
  Future<List<String>> managerNames() async {
    final Object? payload = await _get(
      '/onec-data/manager-stats/',
      query: const <String, String>{'page': '1', 'page_size': '200'},
    );
    return _distinct(<String?>[
      for (final Map<String, Object?> row in asRows(payload))
        readString(row, <String>['manager', 'manager_name']),
    ]);
  }

  Future<List<String>> _names(
    String endpoint, {
    required int pageSize,
    String? search,
  }) async {
    final Object? payload = await _get(
      endpoint,
      query: <String, String>{
        'page': '1',
        'page_size': '$pageSize',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return _distinct(<String?>[
      for (final Map<String, Object?> row in asRows(payload))
        readString(row, <String>['name', 'full_name']),
    ]);
  }

  static List<String> _distinct(List<String?> names) {
    final Set<String> seen = <String>{};
    return <String>[
      for (final String? name in names)
        if (name != null && seen.add(name)) name,
    ];
  }

  /// The trailing slashes are the bridge's own: FastAPI answers the bare path
  /// with a redirect, which costs a round trip for nothing.
  Future<Object?> _get(String endpoint, {Map<String, String>? query}) =>
      _client.get(endpoint, query: query, origin: kOnecApiOrigin);

  Future<_Part> _part(Future<Object?> Function() request) async {
    try {
      return _Part(payload: await request());
    } on ApiException catch (error) {
      return _Part(failure: error);
    }
  }
}

/// One of the concurrent loads: what came back, or why nothing did.
class _Part {
  const _Part({this.payload, this.failure});

  final Object? payload;
  final ApiException? failure;
}
