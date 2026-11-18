import 'dart:io';
import 'dart:ui' show Color;

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/app_notification.dart';

/// Called with a tapped notification's payload — its key.
typedef NotificationTapCallback = void Function(String key);

/// Puts notifications on the phone: the banner, the shade, the lock screen
/// and the number on the app's icon.
abstract interface class NotificationPresenter {
  /// Safe to call from the background check, where nothing may prompt.
  Future<void> init({NotificationTapCallback? onTap});

  /// Asks the system for permission to notify. True when it was granted.
  Future<bool> requestPermission();

  /// Posts [items], oldest first, and sets the icon's number to [badge].
  Future<void> show(List<AppNotification> items, {required int badge});

  Future<void> setBadge(int count);

  /// Takes everything this app posted off the shade, and the number off the
  /// icon — on sign-out.
  Future<void> clearAll();
}

/// The real thing: `flutter_local_notifications` for the notifications,
/// `app_badge_plus` for the number on the icon.
///
/// The number is set separately because Android has no one way to put it
/// there: a Pixel shows a dot for whatever is in the shade, while Samsung,
/// HONOR, Huawei and Xiaomi launchers each take a count through their own
/// API, which `app_badge_plus` speaks. On iOS the count rides on each
/// notification too, so it is right even if the app never runs again.
class SystemNotificationPresenter implements NotificationPresenter {
  SystemNotificationPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// The monochrome glyph Android draws in the status bar — the Güvən mark,
  /// white on transparent, in `res/drawable/ic_stat_guven.xml`.
  static const String _smallIcon = 'ic_stat_guven';

  /// Tints the glyph and the app's name in the notification's header.
  static const Color _accent = Color(0xFF0C1017);

  @override
  Future<void> init({NotificationTapCallback? onTap}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          // Asked for at a moment the app chooses, not whenever the plugin
          // happens to start — which may be in the background.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap == null
          ? null
          : (NotificationResponse response) {
              final String? key = response.payload;
              if (key != null && key.isNotEmpty) onTap(key);
            },
    );
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      for (final NotificationKind kind in NotificationKind.values) {
        await android.createNotificationChannel(_channel(kind));
      }
    }
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> show(List<AppNotification> items, {required int badge}) async {
    if (items.isEmpty) return;
    final Set<NotificationKind> groups = <NotificationKind>{};
    for (final AppNotification item in items) {
      try {
        await _plugin.show(
          id: item.platformId,
          title: item.title,
          body: item.body,
          payload: item.key,
          notificationDetails: _details(item, badge),
        );
        groups.add(item.kind);
      } catch (_) {
        // Permission withdrawn, a channel turned off: the rest still go.
      }
    }
    // Android stacks a group under a summary only when there is one. On 7.0
    // and later the summary is never drawn on its own — it is the header the
    // stack folds into.
    if (Platform.isAndroid) {
      for (final NotificationKind kind in groups) {
        try {
          await _plugin.show(
            id: stableNotificationId('summary:${kind.name}'),
            title: _channelName(kind),
            body: null,
            notificationDetails: NotificationDetails(
              android: _android(kind, badge, summary: true),
            ),
          );
        } catch (_) {}
      }
    }
    await setBadge(badge);
  }

  @override
  Future<void> setBadge(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
    } catch (_) {
      // A launcher without a badge API: the shade's dot is all there is.
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    await setBadge(0);
  }

  NotificationDetails _details(AppNotification item, int badge) {
    return NotificationDetails(
      android: _android(
        item.kind,
        badge,
        body: item.body,
        when: item.createdAt,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        presentBadge: true,
        badgeNumber: badge,
        threadIdentifier: item.kind.name,
      ),
    );
  }

  AndroidNotificationDetails _android(
    NotificationKind kind,
    int badge, {
    String? body,
    DateTime? when,
    bool summary = false,
  }) {
    final AndroidNotificationChannel channel = _channel(kind);
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
      color: _accent,
      number: badge,
      groupKey: 'az.guvenfinans.mobile.${kind.name}',
      setAsGroupSummary: summary,
      // A long reason under an attendance line, or a task's company and work
      // type, would otherwise be cut to one line.
      styleInformation: body == null ? null : BigTextStyleInformation(body),
      when: when?.millisecondsSinceEpoch,
      showWhen: when != null,
      autoCancel: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
    );
  }

  static AndroidNotificationChannel _channel(NotificationKind kind) {
    return AndroidNotificationChannel(
      'guven_${kind.name}',
      _channelName(kind),
      description: switch (kind) {
        NotificationKind.general => 'Saytın bildiriş mərkəzindən gələnlər',
        NotificationKind.task => 'Sizə yeni tapşırıq veriləndə',
        NotificationKind.attendance =>
          'Əməkdaşlar işə gələndə və işdən çıxanda (yalnız şirkət sahibinə)',
      },
      importance: Importance.high,
    );
  }

  static String _channelName(NotificationKind kind) => switch (kind) {
    NotificationKind.general => 'Bildirişlər',
    NotificationKind.task => 'Tapşırıqlar',
    NotificationKind.attendance => 'Davamiyyət',
  };
}
