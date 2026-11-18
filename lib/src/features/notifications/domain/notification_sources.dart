import '../../../core/json.dart';
import '../../attendance/domain/attendance.dart';
import 'app_notification.dart';

/// Turns each endpoint's answer into notifications.
///
/// Pure functions over decoded JSON, so every rule here is tested without a
/// network or a phone. Whether one of them is *new* is not decided here — that
/// is the seen-keys bookkeeping in `NotificationSync`.
abstract final class NotificationSources {
  /// `GET /notifications/recent` — a bare list, or `{notifications: […]}` the
  /// way the website reads it.
  ///
  /// The field names are the website's (`assets/js/notifications/
  /// notifications.service.js`): `title`, `message`, `notification_type`,
  /// `created_at`, `is_read`. A row the user has already read — on the site,
  /// say — comes back with [AppNotification.read] set, and is never shown.
  static List<AppNotification> backend(Object? response) {
    final List<AppNotification> out = <AppNotification>[];
    for (final Map<String, Object?> row in asRows(
      response,
      keys: const <String>['notifications'],
    )) {
      final String? id = readString(row, const <String>['id', 'uuid']);
      if (id == null) continue;
      final String type =
          (readString(row, const <String>['notification_type', 'type']) ?? '')
              .toLowerCase();
      final bool read =
          readBool(row, const <String>['is_read', 'isRead', 'read']) == true ||
          readString(row, const <String>['read_at']) != null ||
          readString(row, const <String>['status']) == 'read';
      out.add(
        AppNotification(
          key: 'api:$id',
          kind: type.contains('task') || type.contains('assign')
              ? NotificationKind.task
              : NotificationKind.general,
          title: readString(row, const <String>['title']) ?? 'Bildiriş',
          body:
              readString(row, const <String>['message', 'body', 'content']) ??
              '',
          createdAt:
              readDate(row, const <String>['created_at', 'date']) ??
              DateTime.now(),
          read: read,
          target: readString(row, const <String>['target_id']),
        ),
      );
    }
    return out;
  }

  /// `GET /tasks/detailed` — the tasks assigned to [userId] by somebody else.
  ///
  /// The website's bell rule, word for word: the executor is me and the
  /// creator is not. A task someone creates for themselves, or one I create
  /// for a colleague, is nobody's news.
  static List<AppNotification> assignedTasks(
    Object? response, {
    required int userId,
  }) {
    final List<AppNotification> out = <AppNotification>[];
    for (final Map<String, Object?> row in asRows(response)) {
      final String? id = readString(row, const <String>['id', 'task_id']);
      if (id == null) continue;
      final int? executor = readInt(row, const <String>[
        'assigned_to',
        'executor_user_id',
      ]);
      final int? creator = readInt(row, const <String>[
        'created_by',
        'creator_id',
        'assigned_by',
        'user_id',
      ]);
      if (executor != userId || creator == userId) continue;

      final String? from = readString(row, const <String>[
        'creator_name',
        'created_by_name',
        'assigned_by_name',
      ]);
      final String? company = readString(row, const <String>[
        'task_title',
        'company_name',
        'target_company_name',
      ]);
      final String? work = readString(row, const <String>['work_type_name']);
      final String what = <String?>[
        company,
        work,
      ].whereType<String>().join(' — ');
      out.add(
        AppNotification(
          key: 'task:$id',
          kind: NotificationKind.task,
          title: 'Sizə yeni tapşırıq yaradıldı',
          body: switch ((from, what.isEmpty)) {
            (final String name, false) => '$name: $what',
            (final String name, true) => '$name tərəfindən',
            (null, false) => what,
            (null, true) => 'Tapşırıqlar bölməsində baxın',
          },
          createdAt:
              readDate(row, const <String>['created_at']) ?? DateTime.now(),
          target: id,
        ),
      );
    }
    return out;
  }

  /// `GET /attendance/company/{code}/history?days=1` — today's check-ins and
  /// check-outs of everyone in the company but [ownId].
  ///
  /// Each row carries `entries` / `exits` as `{timestamp, note}` with the
  /// timestamp in Baku time (`"2026-11-15 09:14"`), and the answer names the
  /// server's own `today`. Only stamps on that day count: `days=1` has been
  /// seen to include yesterday's too.
  ///
  /// [ownId] is null for an owner who signs in as the company rather than as
  /// a person, whose id is not a row of this list and must not hide one.
  static List<AppNotification> companyAttendance(
    Object? response, {
    required int? ownId,
    DateTime? now,
  }) {
    final Map<String, Object?> body = _unwrap(asMap(response));
    final String today =
        readString(body, const <String>['today']) ??
        attendanceDateKey(bakuTime(now ?? DateTime.now()));

    final List<AppNotification> out = <AppNotification>[];
    for (final Map<String, Object?> row in asRows(
      body,
      keys: const <String>['employees'],
    )) {
      final int? id = readInt(row, const <String>['id', 'user_id']);
      if (id == null || id == ownId) continue;
      final String name = readPersonName(row) ?? 'Əməkdaş';
      for (final AttendanceKind kind in AttendanceKind.values) {
        for (final _Stamp stamp in _stamps(row, kind)) {
          if (!stamp.at.startsWith(today)) continue;
          out.add(_attendance(id, name, kind, stamp));
        }
      }
    }
    return out;
  }

  static Map<String, Object?> _unwrap(Map<String, Object?> body) {
    final Object? data = body['data'];
    if (body['employees'] == null && data is Map) return asMap(data);
    return body;
  }

  /// A row's stamps of one [kind]: the `{timestamp, note}` objects when the
  /// row has them, else the bare `today_entries` strings.
  static List<_Stamp> _stamps(Map<String, Object?> row, AttendanceKind kind) {
    final bool entry = kind == AttendanceKind.entry;
    final Object? rich = row[entry ? 'entries' : 'exits'];
    if (rich is List && rich.isNotEmpty) {
      return <_Stamp>[
        for (final Object? item in rich)
          if (item is Map && readString(asMap(item), _timestamp) != null)
            _Stamp(
              _minutePrecision(readString(asMap(item), _timestamp)!),
              readString(asMap(item), const <String>['note']),
            ),
      ];
    }
    final Object? bare = row[entry ? 'today_entries' : 'today_exits'];
    if (bare is! List) return const <_Stamp>[];
    return <_Stamp>[
      for (final Object? item in bare)
        if (item is String && item.trim().isNotEmpty)
          _Stamp(_minutePrecision(item.trim()), null),
    ];
  }

  static const List<String> _timestamp = <String>['timestamp', 'time', 'at'];

  /// `2026-11-15 09:14` — some rows carry seconds, and the same press must
  /// make the same key whichever form it came in.
  static String _minutePrecision(String stamp) =>
      stamp.length > 16 ? stamp.substring(0, 16) : stamp;

  static AppNotification _attendance(
    int employeeId,
    String name,
    AttendanceKind kind,
    _Stamp stamp,
  ) {
    final bool entry = kind == AttendanceKind.entry;
    final String clock = stamp.at.length >= 16
        ? stamp.at.substring(11, 16)
        : stamp.at;
    final int? minute = _minuteOfDay(clock);
    final String? note = stamp.note;
    final bool permitted = note == AttendanceRules.permittedNote;

    String? verdict;
    if (permitted) {
      verdict = 'İcazəli';
    } else if (minute != null &&
        entry &&
        minute > AttendanceRules.entryMinute) {
      verdict = '${_span(minute - AttendanceRules.entryMinute)} gecikmə';
    } else if (minute != null &&
        !entry &&
        minute < AttendanceRules.exitMinute) {
      verdict = '${_span(AttendanceRules.exitMinute - minute)} tez çıxış';
    }

    final StringBuffer body = StringBuffer('Saat $clock');
    if (verdict != null) body.write(' · $verdict');
    if (note != null && !permitted) body.write('\nSəbəb: $note');

    return AppNotification(
      key: 'att:$employeeId:${entry ? 'in' : 'out'}:${stamp.at}',
      kind: NotificationKind.attendance,
      title: entry ? '$name işə gəldi' : '$name işdən çıxdı',
      body: body.toString(),
      createdAt: _bakuStampToLocal(stamp.at) ?? DateTime.now(),
      target: '$employeeId',
    );
  }

  static int? _minuteOfDay(String clock) {
    final List<String> parts = clock.split(':');
    if (parts.length < 2) return null;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// `14 dəq`, `1 saat`, `1 saat 5 dəq`.
  static String _span(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h == 0) return '$m dəq';
    if (m == 0) return '$h saat';
    return '$h saat $m dəq';
  }

  /// A Baku wall-clock stamp as the instant it names, in local time.
  static DateTime? _bakuStampToLocal(String stamp) {
    final DateTime? wall = DateTime.tryParse(stamp.replaceFirst(' ', 'T'));
    if (wall == null) return null;
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    ).subtract(const Duration(hours: 4)).toLocal();
  }
}

class _Stamp {
  const _Stamp(this.at, this.note);

  /// `YYYY-MM-DD HH:MM`, Baku time.
  final String at;
  final String? note;
}
