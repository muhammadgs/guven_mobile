import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/home_api.dart';
import '../domain/home_snapshot.dart';

/// Drives the home screen: one snapshot, a loading flag and an error string.
///
/// Deliberately thin — the screen has no interactions beyond pull-to-refresh,
/// so there is nothing here that a `Future` plus a listener does not cover.
class HomeController extends ChangeNotifier {
  HomeController(this._session) : _api = HomeApi(_session.client);

  final SessionController _session;
  final HomeApi _api;

  HomeSnapshot _snapshot = const HomeSnapshot.empty();
  HomeSnapshot get snapshot => _snapshot;

  bool _loading = false;
  bool get isLoading => _loading;

  /// True until the first load settles, so the screen can show skeletons
  /// rather than a wall of zeroes it is about to replace.
  bool _everLoaded = false;
  bool get hasLoaded => _everLoaded;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();

    try {
      _snapshot = await _api.load(companyCode: _session.user?.companyCode);
      _error = null;
    } on ApiException catch (error) {
      // A 401 has already been handled by the client — it signed the session
      // out — so there is no point putting a message on a screen that is
      // being torn down.
      if (!error.isUnauthorized) _error = error.message;
    } finally {
      _loading = false;
      _everLoaded = true;
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
