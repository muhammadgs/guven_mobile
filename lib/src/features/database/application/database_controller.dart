import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/database_api.dart';
import '../domain/database_overview.dart';
import '../domain/database_section.dart';
import 'bank_accounts_controller.dart';
import 'cash_desks_controller.dart';
import 'customers_controller.dart';
import 'manager_stats_controller.dart';
import 'orders_controller.dart';
import 'products_controller.dart';
import 'sales_controller.dart';
import 'stock_controller.dart';
import 'team_controller.dart';
import 'warehouses_controller.dart';

/// Drives the `Baza` tab: which page of it is on screen, and `Əsas panel`'s
/// figures.
///
/// The figures are kept when the page changes, so going back to `Əsas panel`
/// is instant and only a pull goes back to the network — the same rule the
/// task list keeps for its cells.
class DatabaseController extends ChangeNotifier {
  /// [api] is the seam the tests reach through.
  DatabaseController(SessionController session, {DatabaseApi? api})
    : _api = api ?? DatabaseApi(session.client);

  final DatabaseApi _api;

  DatabaseSection _section = DatabaseSection.overview;
  DatabaseSection get section => _section;

  DatabaseOverview _overview = DatabaseOverview.empty;
  DatabaseOverview get overview => _overview;

  bool _loading = false;
  bool get isLoading => _loading;

  /// True once a load has settled, however it settled. Until then every row
  /// says `—` together rather than one at a time.
  bool _loaded = false;
  bool get hasLoaded => _loaded;

  /// Why the last load brought nothing back at all, or null.
  String? _error;
  String? get error => _error;

  bool _disposed = false;

  SalesController? _sales;

  /// `Satışlar`. Made the first time the page is opened, and kept with
  /// everything it has loaded while the tab lives, like the figures above.
  SalesController get sales => _sales ??= SalesController(_api);

  StockController? _stock;

  /// `Stok`, made and kept the same way.
  StockController get stock => _stock ??= StockController(_api);

  OrdersController? _orders;

  /// `Sifarişlər`, made and kept the same way.
  OrdersController get orders => _orders ??= OrdersController(_api);

  ProductsController? _products;

  /// `Məhsullar`, made and kept the same way.
  ProductsController get products => _products ??= ProductsController(_api);

  CustomersController? _customers;

  /// `Müştərilər`, made and kept the same way.
  CustomersController get customers => _customers ??= CustomersController(_api);

  TeamController? _team;

  /// `Komanda`, made and kept the same way.
  TeamController get team => _team ??= TeamController(_api);

  ManagerStatsController? _managerStats;

  /// `Menecer statistikası`, made and kept the same way.
  ManagerStatsController get managerStats =>
      _managerStats ??= ManagerStatsController(_api);

  BankAccountsController? _bankAccounts;

  /// `Bank Hesabları`, made and kept the same way.
  BankAccountsController get bankAccounts =>
      _bankAccounts ??= BankAccountsController(_api);

  CashDesksController? _cashDesks;

  /// `Kassalar`, made and kept the same way.
  CashDesksController get cashDesks =>
      _cashDesks ??= CashDesksController(_api);

  WarehousesController? _warehouses;

  /// `Anbarlar`, made and kept the same way.
  WarehousesController get warehouses =>
      _warehouses ??= WarehousesController(_api);

  void select(DatabaseSection next) {
    if (next == _section) return;
    _section = next;
    _notify();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();

    try {
      _overview = await _api.overview();
    } on ApiException catch (error) {
      // Kept even for a 401, unlike the home screen. A 401 from the bridge is
      // not necessarily the session ending: the client has already refreshed
      // and retried by the time it gets here, and only a failed *refresh*
      // signs anybody out. One that survives that is the bridge refusing this
      // account, and the page should say so rather than stay blank.
      _error = error.message;
    } finally {
      _loading = false;
      _loaded = true;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sales?.dispose();
    _stock?.dispose();
    _orders?.dispose();
    _products?.dispose();
    _customers?.dispose();
    _team?.dispose();
    _managerStats?.dispose();
    _bankAccounts?.dispose();
    _cashDesks?.dispose();
    _warehouses?.dispose();
    super.dispose();
  }
}
