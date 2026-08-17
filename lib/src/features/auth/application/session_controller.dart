import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_store.dart';
import '../data/auth_api.dart';
import '../domain/auth_user.dart';

/// Where the app is, as far as authentication is concerned.
enum SessionStatus {
  /// Reading the keystore to see whether a session survived the last run.
  restoring,

  /// Nobody is signed in — the onboarding/login flow is on screen.
  signedOut,

  /// Signed in; the main shell is on screen.
  signedIn,
}

/// The one piece of state the whole app agrees on.
///
/// Owns the token store and the [ApiClient] built on it, so every feature that
/// needs the network gets a client that already knows how to authenticate and
/// how to renew itself. Created once in `GuvenApp` and reached through
/// [SessionScope].
class SessionController extends ChangeNotifier {
  SessionController({TokenStore? tokens}) : tokens = tokens ?? TokenStore() {
    client = ApiClient(
      tokens: this.tokens,
      onSessionExpired: _onSessionExpired,
    );
    _auth = AuthApi(client, this.tokens);
  }

  final TokenStore tokens;
  late final ApiClient client;
  late final AuthApi _auth;

  SessionStatus _status = SessionStatus.restoring;
  SessionStatus get status => _status;

  AuthUser? _user;
  AuthUser? get user => _user;

  /// True while a sign-in is in flight — the login button shows a spinner and
  /// stops accepting taps.
  bool _busy = false;
  bool get isBusy => _busy;

  /// The last sign-in failure, in Azerbaijani, or null.
  String? _error;
  String? get error => _error;

  /// Set when a previously good session was rejected mid-use, so the login
  /// screen can say why the user is suddenly back at it.
  bool _expired = false;
  bool get didExpire => _expired;

  /// Looks for a session left over from a previous run.
  ///
  /// A stored token is trusted only as far as `/auth/me` confirms it: it may
  /// have been revoked, or the account disabled, since the app last ran. A
  /// *network* failure is treated differently from a rejection — being offline
  /// at launch should not sign anyone out, so the session is kept and the home
  /// screen shows its own error instead.
  Future<void> restore() async {
    await tokens.load();
    if (!tokens.hasSession) {
      _set(SessionStatus.signedOut);
      return;
    }

    try {
      _user = await _auth.currentUser();
      _set(SessionStatus.signedIn);
    } on ApiException catch (error) {
      if (error.isOffline) {
        // Keep the session; the home screen will retry and report.
        _set(SessionStatus.signedIn);
        return;
      }
      await tokens.clear();
      _set(SessionStatus.signedOut);
    }
  }

  /// Signs in. Returns true on success; on failure [error] holds the reason.
  Future<bool> signIn({required String login, required String password}) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _expired = false;
    notifyListeners();

    try {
      final AuthUser fromLogin =
          await _auth.signIn(login: login, password: password);
      // The login body is thin on some accounts — no role, no company code —
      // so `/auth/me` fills the gaps before the dashboard starts querying.
      // Its failure is not fatal: the token is already good.
      AuthUser user = fromLogin;
      try {
        user = fromLogin.mergeWith(await _auth.currentUser());
      } on ApiException {
        // Keep what login gave us.
      }
      _user = user;
      _busy = false;
      _set(SessionStatus.signedIn);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _error = null;
    _expired = false;
    _set(SessionStatus.signedOut);
  }

  /// Clears the "your session ended" notice once the login screen has shown it.
  void acknowledgeExpiry() {
    if (!_expired) return;
    _expired = false;
    notifyListeners();
  }

  /// A 401 that a refresh could not rescue, raised from inside [ApiClient].
  void _onSessionExpired() {
    if (_status != SessionStatus.signedIn) return;
    _expired = true;
    _user = null;
    // Fire-and-forget: the client is mid-request and cannot be awaited here.
    unawaited(tokens.clear());
    _set(SessionStatus.signedOut);
  }

  void _set(SessionStatus next) {
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}

/// Puts the [SessionController] in the tree.
///
/// An [InheritedNotifier] rather than a package: the app has one piece of
/// global state and this is what the framework provides for exactly that.
/// `SessionScope.of` rebuilds its dependents when the session changes;
/// `SessionScope.read` reaches the controller to call a method without
/// subscribing.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final SessionScope? scope =
        context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget.');
    return scope!.notifier!;
  }

  static SessionController read(BuildContext context) {
    final SessionScope? scope =
        context.getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget.');
    return scope!.notifier!;
  }
}
