/// Davamiyyət — the office check-in / check-out, not the account's sign-in.
///
/// Every rule here is the website's (`assets/js/attendance/attendance.js` on
/// the live site, read 2026-11-08), because the backend enforces none of them:
/// it stores whatever note it is sent and answers `today-status` with counts.
library;

import '../../../core/json.dart';

/// Which of the two buttons a log line came from.
enum AttendanceKind {
  entry,
  exit;

  /// `Giriş` / `Çıxış` — the label on its button, in the history and in
  /// every prompt that names it.
  String get label => switch (this) {
    AttendanceKind.entry => 'Giriş',
    AttendanceKind.exit => 'Çıxış',
  };
}

/// Where today stands. One entry and one exit a day — the site's rule.
enum AttendanceDay {
  /// Nothing recorded today: the card offers `Giriş`.
  notEntered,

  /// Checked in, not yet out: the card offers `Çıxış`.
  atWork,

  /// Both done. Nothing left to press until tomorrow.
  finished,
}

/// The office's hours, and what the site does on either side of them.
///
/// The site compares `"HH:MM"` strings in Baku time, so a check-in at 09:00
/// sharp is on time and one at 09:01 is late; an exit at 17:59 is early and
/// one at 18:00 is not. Arriving early and leaving late are never asked
/// about — the site has no prompt for either, so neither has this app.
abstract final class AttendanceRules {
  /// `09:00` — a check-in after it needs a reason.
  static const int entryMinute = 9 * 60;

  /// `18:00` — a check-out before it needs a reason.
  static const int exitMinute = 18 * 60;

  static int _minuteOf(DateTime baku) => baku.hour * 60 + baku.minute;

  static bool isLateEntry(DateTime baku) => _minuteOf(baku) > entryMinute;

  static bool isEarlyExit(DateTime baku) => _minuteOf(baku) < exitMinute;

  /// Whether pressing [kind] at [baku] has to be explained first.
  static bool needsReason(AttendanceKind kind, DateTime baku) => switch (kind) {
    AttendanceKind.entry => isLateEntry(baku),
    AttendanceKind.exit => isEarlyExit(baku),
  };

  /// From 09:00 on, someone who has not checked in is reminded.
  static bool entryReminderDue(DateTime baku) => _minuteOf(baku) >= entryMinute;

  /// From 18:00 on, someone still at work is reminded to check out.
  static bool exitReminderDue(DateTime baku) => _minuteOf(baku) >= exitMinute;

  /// The note the site files for `İcazəli`.
  static const String permittedNote = 'İcazəli';
}

/// Baku wall-clock time, whatever zone the phone is in.
///
/// Azerbaijan has kept UTC+4 all year since 2016. The result is a plain
/// (non-UTC) `DateTime` carrying Baku's fields, so `hour` and `day` read the
/// way the site's `toLocaleString('…', {timeZone: 'Asia/Baku'})` does.
DateTime bakuTime(DateTime instant) {
  final DateTime shifted = instant.toUtc().add(const Duration(hours: 4));
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
  );
}

/// `YYYY-MM-DD` — how the backend writes a day, and the prefix of every log.
String attendanceDateKey(DateTime baku) =>
    '${baku.year.toString().padLeft(4, '0')}-'
    '${baku.month.toString().padLeft(2, '0')}-'
    '${baku.day.toString().padLeft(2, '0')}';

/// One line of the history: a press of either button.
class AttendanceEvent {
  const AttendanceEvent({required this.kind, required this.stamp, this.note});

  final AttendanceKind kind;

  /// As the backend stores it: `"2026-11-08 14:29"`, Baku time. Kept as text
  /// because it is shown as text, and because it sorts as text.
  final String stamp;

  /// The reason given for a late entry or an early exit, if one was.
  final String? note;

  /// `2026-11-08 14:29` — the seconds some rows carry are dropped.
  String get shown => stamp.length > 16 ? stamp.substring(0, 16) : stamp;

  bool isOn(String dateKey) => stamp.startsWith(dateKey);
}

/// What `GET /attendance/history` holds, newest first.
class AttendanceHistory {
  const AttendanceHistory(this.events);

  static const AttendanceHistory empty = AttendanceHistory(<AttendanceEvent>[]);

  final List<AttendanceEvent> events;

  /// Reads `{entry_logs, exit_logs, entry_notes, exit_notes}`, bare or
  /// wrapped in `data`.
  ///
  /// Notes are matched to logs from the **end**, not from the start as the
  /// site does. The note column arrived after people had already been
  /// checking in, so an account can have more logs than notes — seen live on
  /// 2026-11-08: two entries, one note, and the note was the one written for
  /// the newest entry. Pairing from the start would have pinned it on a
  /// check-in from August.
  factory AttendanceHistory.fromResponse(Object? payload) {
    Map<String, Object?> body = asMap(payload);
    if (body['entry_logs'] == null && body['data'] is Map) {
      body = asMap(body['data']);
    }

    final List<AttendanceEvent> events =
        <AttendanceEvent>[
          ..._events(
            AttendanceKind.entry,
            body['entry_logs'],
            body['entry_notes'],
          ),
          ..._events(
            AttendanceKind.exit,
            body['exit_logs'],
            body['exit_notes'],
          ),
        ]..sort(
          (AttendanceEvent a, AttendanceEvent b) => b.stamp.compareTo(a.stamp),
        );
    return AttendanceHistory(List<AttendanceEvent>.unmodifiable(events));
  }

  static List<AttendanceEvent> _events(
    AttendanceKind kind,
    Object? logs,
    Object? notes,
  ) {
    final List<String> stamps = _strings(logs);
    final List<String?> texts = notes is List
        ? <String?>[
            for (final Object? note in notes)
              note is String && note.trim().isNotEmpty ? note.trim() : null,
          ]
        : const <String?>[];
    final int offset = stamps.length - texts.length;
    return <AttendanceEvent>[
      for (int i = 0; i < stamps.length; i++)
        AttendanceEvent(
          kind: kind,
          stamp: stamps[i],
          note: i - offset >= 0 && i - offset < texts.length
              ? texts[i - offset]
              : null,
        ),
    ];
  }

  int countOn(AttendanceKind kind, String dateKey) => events
      .where((AttendanceEvent e) => e.kind == kind && e.isOn(dateKey))
      .length;
}

List<String> _strings(Object? value) => value is List
    ? <String>[
        for (final Object? item in value)
          if (item != null && '$item'.trim().isNotEmpty) '$item'.trim(),
      ]
    : const <String>[];

/// How many times each button was pressed today, by `GET /today-status`.
class AttendanceToday {
  const AttendanceToday({required this.entries, required this.exits});

  final int entries;
  final int exits;

  factory AttendanceToday.fromResponse(Object? payload) {
    Map<String, Object?> body = asMap(payload);
    if (body['entries_today'] == null && body['data'] is Map) {
      body = asMap(body['data']);
    }
    int entries = _strings(body['entries_today']).length;
    int exits = _strings(body['exits_today']).length;
    // The flags arrive alone on some deployments.
    if (entries == 0 && readBool(body, <String>['has_entered_today']) == true) {
      entries = 1;
    }
    if (exits == 0 && readBool(body, <String>['has_exited_today']) == true) {
      exits = 1;
    }
    return AttendanceToday(entries: entries, exits: exits);
  }

  /// `today-status` has been seen answering zero for a day the history
  /// already holds (the server's date and Baku's disagree around midnight),
  /// so the site takes the larger of the two counts. So does this.
  AttendanceToday reconciledWith(AttendanceHistory history, String dateKey) {
    final int e = history.countOn(AttendanceKind.entry, dateKey);
    final int x = history.countOn(AttendanceKind.exit, dateKey);
    return AttendanceToday(
      entries: e > entries ? e : entries,
      exits: x > exits ? x : exits,
    );
  }

  AttendanceDay get day {
    if (entries == 0) return AttendanceDay.notEntered;
    if (exits >= entries) return AttendanceDay.finished;
    return AttendanceDay.atWork;
  }
}
