import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/app_notification.dart';

/// Who the notifications are for — written by the app when someone signs in,
/// read by the background check, which has no session of its own to ask.
class NotificationProfile {
  const NotificationProfile({
    required this.userId,
    required this.companyCode,
    required this.isOwner,
    required this.isCompanyAccount,
  });

  final int userId;
  final String? companyCode;

  /// Only the owner is told about attendance (the user's call, 2026-11-06).
  final bool isOwner;

  /// An owner signed in as the company rather than as a person. Their id is
  /// not a row of the company's attendance list, so it must not hide one.
  final bool isCompanyAccount;

  Map<String, Object?> toJson() => <String, Object?>{
    'user_id': userId,
    'company_code': companyCode,
    'owner': isOwner,
    'company_account': isCompanyAccount,
  };

  static NotificationProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['user_id'];
    if (id is! int) return null;
    final Object? code = json['company_code'];
    return NotificationProfile(
      userId: id,
      companyCode: code is String && code.isNotEmpty ? code : null,
      isOwner: json['owner'] == true,
      isCompanyAccount: json['company_account'] == true,
    );
  }

  bool sameAs(NotificationProfile other) =>
      other.userId == userId &&
      other.companyCode == companyCode &&
      other.isOwner == isOwner &&
      other.isCompanyAccount == isCompanyAccount;
}

/// Everything the notification checks remember between runs.
///
/// One small JSON document shared by the app and the background check (a
/// separate isolate, sometimes a separate engine), so every run reads it
/// fresh and writes it whole rather than trusting a copy in memory.
class NotificationState {
  NotificationState({
    required this.profile,
    Map<String, List<String>>? seen,
    List<AppNotification>? inbox,
    this.foregroundBeat,
    this.permissionAsked = false,
  }) : seen = seen ?? <String, List<String>>{},
       inbox = inbox ?? <AppNotification>[];

  final NotificationProfile profile;

  /// Per source (`backend`, `tasks`, `attendance`), the keys already
  /// accounted for — shown, or present when the source was first read. A
  /// source with no entry here has never answered, and its first answer is
  /// filed silently: installing the app must not replay a month of tasks as
  /// "new". Kept per source rather than per kind, so a source that fails on
  /// the first run still gets its own silent first answer later.
  final Map<String, List<String>> seen;

  /// Newest first, at most [inboxLimit].
  final List<AppNotification> inbox;

  /// When the app last polled while open. The background check stands down
  /// while this is recent, so the two never race over the same news.
  DateTime? foregroundBeat;

  /// The permission prompt is the system's, and asking twice only teaches the
  /// user to say no.
  bool permissionAsked;

  static const int inboxLimit = 100;

  int get unread => inbox.where((AppNotification n) => !n.read).length;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'profile': profile.toJson(),
    'seen': <String, Object?>{
      for (final MapEntry<String, List<String>> e in seen.entries)
        e.key: e.value,
    },
    'inbox': <Object?>[for (final AppNotification n in inbox) n.toJson()],
    if (foregroundBeat != null)
      'foreground_beat': foregroundBeat!.toUtc().toIso8601String(),
    'permission_asked': permissionAsked,
  };

  static NotificationState? fromJson(Object? json) {
    if (json is! Map) return null;
    final NotificationProfile? profile = NotificationProfile.fromJson(
      json['profile'],
    );
    if (profile == null) return null;
    final Map<String, List<String>> seen = <String, List<String>>{};
    final Object? rawSeen = json['seen'];
    if (rawSeen is Map) {
      for (final MapEntry<Object?, Object?> e in rawSeen.entries) {
        final Object? keys = e.value;
        if (keys is List) seen['${e.key}'] = keys.whereType<String>().toList();
      }
    }
    final Object? rawInbox = json['inbox'];
    return NotificationState(
      profile: profile,
      seen: seen,
      inbox: rawInbox is List
          ? rawInbox
                .map(AppNotification.fromJson)
                .whereType<AppNotification>()
                .toList()
          : null,
      foregroundBeat: DateTime.tryParse('${json['foreground_beat']}'),
      permissionAsked: json['permission_asked'] == true,
    );
  }
}

/// Where [NotificationState] lives.
abstract interface class NotificationStore {
  /// Null when nobody has signed in since the last sign-out, or the file
  /// cannot be read.
  Future<NotificationState?> load();

  Future<void> save(NotificationState state);

  Future<void> clear();
}

/// A JSON file in the app's support directory.
///
/// Not the keystore: nothing here is a credential, and the background check
/// must be able to read it on a phone that has been unlocked once since boot.
/// Written to a temporary file and renamed over the old one, so a check cut
/// off mid-write leaves the previous state rather than half of a new one.
class FileNotificationStore implements NotificationStore {
  FileNotificationStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const String _fileName = 'notifications_state.json';

  Future<File> _file() async {
    final Directory dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<NotificationState?> load() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return null;
      return NotificationState.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(NotificationState state) async {
    try {
      final File file = await _file();
      await file.parent.create(recursive: true);
      final File temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
      await temp.rename(file.path);
    } catch (_) {
      // The next run tries again; at worst it shows one notification twice.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final File file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// Keeps the state in memory — for tests.
class MemoryNotificationStore implements NotificationStore {
  MemoryNotificationStore([this.state]);

  NotificationState? state;

  @override
  Future<NotificationState?> load() async => state == null
      ? null
      : NotificationState.fromJson(jsonDecode(jsonEncode(state!.toJson())));

  @override
  Future<void> save(NotificationState next) async => state = next;

  @override
  Future<void> clear() async => state = null;
}
