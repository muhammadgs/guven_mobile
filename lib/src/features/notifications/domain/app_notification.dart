/// What a notification is about.
///
/// Picks the Android channel it is posted on (so the user can silence one
/// kind in the phone's settings and keep the others), the iOS thread it is
/// stacked in, and — once the in-app list exists — its icon there.
enum NotificationKind {
  /// A row of `GET /notifications/recent`: whatever the backend itself filed
  /// for this user (letters, system messages, …).
  general,

  /// A task newly assigned to the signed-in user. The backend files no
  /// notification for this; the website's bell finds it by diffing
  /// `/tasks/detailed` against the ids it has already seen, and so does the
  /// app.
  task,

  /// An employee's check-in or check-out, shown to the company's owner only.
  attendance;

  static NotificationKind? fromName(String? name) {
    for (final NotificationKind kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One notification, as the phone shows it and as the app keeps it.
///
/// Kept after it is shown, in a small inbox on disk, so the badge can count
/// what has not been looked at and the notifications page the app will get
/// later has something to list.
class AppNotification {
  const AppNotification({
    required this.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.target,
  });

  /// Stable across polls — `api:812`, `task:4054`,
  /// `att:205:in:2026-11-15 09:14` — so the same event is never shown twice.
  final String key;

  final NotificationKind kind;
  final String title;
  final String body;

  /// When the event happened, as local time.
  final DateTime createdAt;

  /// Whether the user has seen it. Opening the app counts, until the app has
  /// a notifications page of its own.
  final bool read;

  /// What tapping it should open: a task id, an employee id. Unused until the
  /// app routes taps.
  final String? target;

  /// The id the platform files it under. Derived from [key] so a repeat
  /// replaces rather than stacks, and kept within 31 bits because Android's
  /// id is a signed `int`.
  int get platformId => stableNotificationId(key);

  AppNotification markedRead() => AppNotification(
    key: key,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: true,
    target: target,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'kind': kind.name,
    'title': title,
    'body': body,
    'at': createdAt.toUtc().toIso8601String(),
    'read': read,
    if (target != null) 'target': target,
  };

  /// Null for a row this version cannot read, so one bad line never costs the
  /// whole inbox.
  static AppNotification? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? key = json['key'];
    final NotificationKind? kind = NotificationKind.fromName(
      json['kind'] as String?,
    );
    final DateTime? at = DateTime.tryParse('${json['at']}');
    if (key is! String || kind == null || at == null) return null;
    final Object? target = json['target'];
    return AppNotification(
      key: key,
      kind: kind,
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      createdAt: at.toLocal(),
      read: json['read'] == true,
      target: target is String ? target : null,
    );
  }
}

/// FNV-1a over [key], folded to a positive 31-bit integer.
///
/// `String.hashCode` is not guaranteed to be the same between runs, and the
/// background check runs in a different isolate from the app — both have to
/// agree on which id a notification already has.
int stableNotificationId(String key) {
  int hash = 0x811c9dc5;
  for (final int unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
