import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/token_store.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../data/notification_store.dart';
import 'notification_background.dart';
import 'notification_presenter.dart';
import 'notification_sync.dart';

/// Runs notifications for the open app, and hands over to the background
/// check when it closes.
///
/// * **Signed in:** remembers who for (so the background check knows), asks
///   the operating system to run the check every fifteen minutes, and while
///   the app is on screen checks every [interval] itself.
/// * **On screen and unlocked:** everything filed is counted as seen and the
///   number comes off the icon — until the app has a notifications page of
///   its own, opening the app is how the user reads them.
/// * **Signed out:** stops the background check, takes this account's
///   notifications off the shade and forgets them.
///
/// Created once in `GuvenApp`, next to the session it follows.
class NotificationController with WidgetsBindingObserver {
  NotificationController({
    required SessionController session,
    NotificationStore? store,
    NotificationPresenter? presenter,
    NotificationScheduler? scheduler,
    this.interval = const Duration(minutes: 1),
  }) : _session = session,
       _store = store ?? FileNotificationStore(),
       _presenter = presenter ?? SystemNotificationPresenter(),
       _scheduler = scheduler ?? WorkmanagerNotificationScheduler() {
    _sync = NotificationSync(client: session.client, store: _store);
  }

  final SessionController _session;
  final NotificationStore _store;
  final NotificationPresenter _presenter;
  final NotificationScheduler _scheduler;
  late final NotificationSync _sync;

  /// How often the open app asks. A minute keeps an owner's check-in banner
  /// close to the moment it happened, for three small requests.
  final Duration interval;

  /// The key of the notification the user last tapped — for the
  /// notifications page and task routing to pick up later.
  final ValueNotifier<String?> lastTapped = ValueNotifier<String?>(null);

  Timer? _timer;
  bool _started = false;
  bool _configured = false;
  bool _resumed = true;
  bool _shellActive = false;
  SessionStatus? _status;
  int? _userId;

  /// Serialises sign-in and sign-out work, which both touch the store.
  Future<void> _queue = Future<void>.value();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _session.addListener(_onSession);
    try {
      await _presenter.init(onTap: _onTap);
    } catch (error) {
      debugPrint('GUVEN_NOTIFY presenter unavailable: $error');
    }
    await _scheduler.initialize();
    _onSession();
  }

  /// Whether the signed-in shell is on screen with nothing locked over it.
  void setShellActive(bool active) {
    if (_shellActive == active) return;
    _shellActive = active;
    if (active) {
      unawaited(_askPermissionOnce());
      unawaited(_markSeen());
    }
  }

  void _onSession() {
    final SessionStatus status = _session.status;
    final AuthUser? user = _session.user;
    final bool changed = status != _status || user?.id != _userId;
    _status = status;
    _userId = user?.id;
    if (!changed) return;
    switch (status) {
      case SessionStatus.restoring:
        break;
      case SessionStatus.signedIn:
        _enqueue(() => _signedIn(user));
      case SessionStatus.signedOut:
        _enqueue(_signedOut);
    }
  }

  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object error) {
      debugPrint('GUVEN_NOTIFY $error');
    });
  }

  Future<void> _signedIn(AuthUser? user) async {
    final int? id = user?.id;
    final NotificationState? saved = await _store.load();
    if (user == null || id == null) {
      // Restored offline: `/auth/me` never answered, but the account that
      // was signed in last time is on file, and still is.
      if (saved == null) return;
    } else {
      final Map<String, Object?> claims =
          decodeJwtPayload(_session.tokens.accessToken) ??
          const <String, Object?>{};
      final NotificationProfile profile = NotificationProfile(
        userId: id,
        companyCode: user.companyCode,
        isOwner: user.role == UserRole.owner,
        isCompanyAccount: claims['is_company_user'] == true,
      );
      if (saved == null || !saved.profile.sameAs(profile)) {
        final bool sameUser = saved?.profile.userId == id;
        if (saved != null && !sameUser) await _presenter.clearAll();
        await _store.save(
          NotificationState(
            profile: profile,
            seen: sameUser ? saved?.seen : null,
            inbox: sameUser ? saved?.inbox : null,
            permissionAsked: saved?.permissionAsked ?? false,
          ),
        );
      }
    }
    _configured = true;
    await _scheduler.start();
    if (_resumed) {
      _startTimer();
      unawaited(check());
    }
    if (_shellActive) unawaited(_askPermissionOnce());
  }

  Future<void> _signedOut() async {
    final bool wasConfigured = _configured;
    _configured = false;
    _stopTimer();
    final NotificationState? saved = await _store.load();
    if (!wasConfigured && saved == null) return;
    await _scheduler.stop();
    await _store.clear();
    await _presenter.clearAll();
  }

  /// One check from the open app. Public so a pull-to-refresh can call it.
  Future<void> check() async {
    if (!_configured) return;
    try {
      final NotificationSyncResult result = await _sync.run(foreground: true);
      if (!_configured) return; // Signed out while it ran.
      int badge = result.unread;
      if (_shellActive && _resumed) badge = await _sync.markAllRead();
      if (result.fresh.isNotEmpty) {
        await _presenter.show(result.fresh, badge: badge);
      } else {
        await _presenter.setBadge(badge);
      }
    } catch (error) {
      debugPrint('GUVEN_NOTIFY check failed: $error');
    }
  }

  Future<void> _markSeen() async {
    if (!_configured || !_resumed) return;
    try {
      await _presenter.setBadge(await _sync.markAllRead());
    } catch (_) {}
  }

  Future<void> _askPermissionOnce() async {
    if (!_configured) return;
    final NotificationState? state = await _store.load();
    if (state == null || state.permissionAsked) return;
    state.permissionAsked = true;
    await _store.save(state);
    try {
      await _presenter.requestPermission();
    } catch (error) {
      debugPrint('GUVEN_NOTIFY permission request failed: $error');
    }
  }

  void _onTap(String key) {
    lastTapped.value = key;
    unawaited(_markSeen());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumed = true;
        if (!_configured) return;
        _startTimer();
        unawaited(check());
        if (_shellActive) unawaited(_markSeen());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _resumed = false;
        _stopTimer();
      case AppLifecycleState.inactive:
        // A system sheet over the app, the app switcher: still visible.
        break;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(check()));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _stopTimer();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _session.removeListener(_onSession);
    }
    lastTapped.dispose();
  }
}
