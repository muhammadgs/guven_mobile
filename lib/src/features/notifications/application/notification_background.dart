import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/token_store.dart';
import '../data/notification_store.dart';
import 'notification_presenter.dart';
import 'notification_sync.dart';

/// The background check's name — Android's unique work name, and on iOS the
/// `BGTaskSchedulerPermittedIdentifiers` entry in `Info.plist` that
/// `AppDelegate.swift` registers. All three must match.
const String kNotificationTask = 'az.guvenfinans.mobile.notifications';

/// How often the operating system is asked to run the check.
///
/// Fifteen minutes is Android's floor for periodic work. iOS treats it as a
/// "not before" and decides itself, by how often the app is used — anything
/// from a quarter of an hour to a few times a day.
const Duration kNotificationInterval = Duration(minutes: 15);

/// While the open app has checked within this, the background check stands
/// down: the app is already on it, every minute.
const Duration kForegroundBeatGrace = Duration(minutes: 3);

/// Where the operating system enters the app to run the check, with no UI
/// and no session object — a fresh isolate, sometimes a fresh engine.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    try {
      await runBackgroundNotificationCheck();
    } catch (error) {
      debugPrint('GUVEN_NOTIFY background check failed: $error');
    }
    // Always "done": a failure is retried at the next interval anyway, and
    // asking WorkManager to back off and retry sooner only costs battery.
    return true;
  });
}

/// One background check: read who is signed in, ask, post what is new.
///
/// Never signs anyone out. A refresh token the server rejects here is left
/// for the app to discover the next time it is opened, where the user can be
/// told why they are back at the login screen.
@visibleForTesting
Future<void> runBackgroundNotificationCheck({
  NotificationStore? store,
  TokenStore? tokens,
  NotificationPresenter? presenter,
  DateTime Function()? clock,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final NotificationStore state = store ?? FileNotificationStore();
  final NotificationState? current = await state.load();
  if (current == null) return; // Signed out.

  final DateTime now = (clock ?? DateTime.now)();
  final DateTime? beat = current.foregroundBeat;
  if (beat != null && now.difference(beat) < kForegroundBeatGrace) {
    debugPrint('GUVEN_NOTIFY background check skipped: app is open');
    return;
  }

  final TokenStore keys = tokens ?? TokenStore();
  await keys.load();
  if (!keys.hasSession) return;

  final ApiClient client = ApiClient(tokens: keys);
  try {
    final NotificationSyncResult result = await NotificationSync(
      client: client,
      store: state,
      clock: clock,
    ).run();
    debugPrint(
      'GUVEN_NOTIFY background check: ${result.fresh.length} new, '
      '${result.unread} unread',
    );
    final NotificationPresenter shown =
        presenter ?? SystemNotificationPresenter();
    await shown.init();
    if (result.fresh.isNotEmpty) {
      await shown.show(result.fresh, badge: result.unread);
    } else {
      await shown.setBadge(result.unread);
    }
  } finally {
    client.close();
  }
}

/// Starts and stops the background check.
abstract interface class NotificationScheduler {
  /// Called once per launch, before anything is scheduled.
  Future<void> initialize();

  Future<void> start();

  Future<void> stop();
}

/// `workmanager`: Android's WorkManager, iOS's `BGTaskScheduler`.
class WorkmanagerNotificationScheduler implements NotificationScheduler {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(notificationCallbackDispatcher);
      _initialized = true;
    } catch (error) {
      debugPrint('GUVEN_NOTIFY workmanager unavailable: $error');
    }
  }

  @override
  Future<void> start() async {
    await initialize();
    if (!_initialized) return;
    try {
      await Workmanager().registerPeriodicTask(
        kNotificationTask,
        kNotificationTask,
        frequency: kNotificationInterval,
        constraints: Constraints(networkType: NetworkType.connected),
        // Keep the running schedule: re-registering on every launch would
        // restart the fifteen-minute clock each time the app is opened.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (error) {
      debugPrint('GUVEN_NOTIFY could not schedule the check: $error');
    }
  }

  @override
  Future<void> stop() async {
    await initialize();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(kNotificationTask);
    } catch (_) {}
  }
}
