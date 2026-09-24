import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/database_api.dart';
import '../domain/database_overview.dart';
import '../domain/database_section.dart';

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
    super.dispose();
  }
}
