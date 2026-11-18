import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/notification_store.dart';
import '../domain/app_notification.dart';
import '../domain/notification_sources.dart';

/// What one check found.
class NotificationSyncResult {
  const NotificationSyncResult({required this.fresh, required this.unread});

  static const NotificationSyncResult none = NotificationSyncResult(
    fresh: <AppNotification>[],
    unread: 0,
  );

  /// New since the last check, oldest first — the order to post them in, so
  /// the newest ends up on top of the shade.
  final List<AppNotification> fresh;

  /// What the badge should say.
  final int unread;
}

/// Asks the backend what is new and files it.
///
/// There is no push channel to this app: the backend keeps no device tokens
/// and sends nothing (probed 2026-11-15 — no `/devices`, `/push/*` or
/// `fcm-token` route exists, and the website has no Firebase either). So the
/// app does what the website's bell does — asks — and the same class answers
/// for the open app's minute-by-minute check and for the background check the
/// operating system wakes every quarter of an hour.
///
/// Three sources, the website's own:
/// * `GET /notifications/recent` — what the backend filed for this user;
/// * `GET /tasks/detailed` — a task assigned to me that I have not seen;
/// * `GET /attendance/company/{code}/history` — for the owner only, today's
///   check-ins and check-outs of everyone else.
class NotificationSync {
  NotificationSync({
    required this._client,
    required this._store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient _client;
  final NotificationStore _store;
  final DateTime Function() _clock;

  /// The statuses the website's bell asks for. A task in any other state is
  /// not one anybody needs to be told about.
  static const String activeTaskStatuses =
      'pending,in_progress,waiting,overdue,pending_approval,paused,'
      'approval_overdue';

  /// How many keys a list-shaped source remembers. Comfortably more than the
  /// 50 rows each one is read in, so a row that stays in the list for months
  /// is never forgotten and announced again.
  static const int _seenLimit = 400;

  Future<NotificationSyncResult>? _running;

  /// Runs one check. Overlapping calls share the one in flight.
  ///
  /// [foreground] marks the open app's own checks: it stamps the beat that
  /// keeps the background check out of the way.
  Future<NotificationSyncResult> run({bool foreground = false}) {
    return _running ??= _run(foreground: foreground).whenComplete(() {
      _running = null;
    });
  }

  Future<NotificationSyncResult> _run({required bool foreground}) async {
    final NotificationState? before = await _store.load();
    if (before == null) return NotificationSyncResult.none;
    final NotificationProfile profile = before.profile;
    final String? company = profile.companyCode;

    final List<Object?> answers = await Future.wait(<Future<Object?>>[
      _ask('/notifications/recent', <String, String>{'limit': '50'}),
      _ask('/tasks/detailed', <String, String>{
        'page': '1',
        'limit': '50',
        'status': activeTaskStatuses,
      }),
      if (profile.isOwner && company != null)
        _ask(
          '/attendance/company/${Uri.encodeComponent(company)}/history',
          <String, String>{'days': '1', 'include_inactive': 'false'},
        )
      else
        Future<Object?>.value(_skipped),
    ]);

    // Read again: the requests took a while, and the other side — the app or
    // the background check — may have filed something meanwhile, or the user
    // may have signed out.
    final NotificationState? state = await _store.load();
    if (state == null || !state.profile.sameAs(profile)) {
      return NotificationSyncResult.none;
    }

    final DateTime now = _clock();
    final List<AppNotification> fresh =
        <AppNotification>[
          if (answers[0] != _failed)
            ..._file(state, 'backend', NotificationSources.backend(answers[0])),
          if (answers[1] != _failed)
            ..._file(
              state,
              'tasks',
              NotificationSources.assignedTasks(
                answers[1],
                userId: profile.userId,
              ),
            ),
          if (answers[2] != _failed && answers[2] != _skipped)
            ..._file(
              state,
              'attendance',
              NotificationSources.companyAttendance(
                answers[2],
                ownId: profile.isCompanyAccount ? null : profile.userId,
                now: now,
              ),
              keep: (String key) => _isRecentAttendance(key, now),
            ),
        ]..sort(
          (AppNotification a, AppNotification b) =>
              a.createdAt.compareTo(b.createdAt),
        );

    final Set<String> filed = <String>{
      for (final AppNotification n in state.inbox) n.key,
    };
    final List<AppNotification> inbox = <AppNotification>[
      for (final AppNotification n in fresh.reversed)
        if (!filed.contains(n.key)) n,
      ...state.inbox,
    ];
    state.inbox
      ..clear()
      ..addAll(inbox.take(NotificationState.inboxLimit));
    if (foreground) state.foregroundBeat = now;
    await _store.save(state);

    return NotificationSyncResult(fresh: fresh, unread: state.unread);
  }

  /// Marks everything read — the user has the app open in front of them.
  /// Returns the new badge count, which is 0.
  Future<int> markAllRead() async {
    final NotificationState? state = await _store.load();
    if (state == null) return 0;
    if (state.unread == 0) return 0;
    final List<AppNotification> read = <AppNotification>[
      for (final AppNotification n in state.inbox) n.read ? n : n.markedRead(),
    ];
    state.inbox
      ..clear()
      ..addAll(read);
    await _store.save(state);
    return 0;
  }

  /// What [source] has that [state] has not accounted for yet — and accounts
  /// for it.
  ///
  /// A source's very first answer is accounted for and nothing is returned. A
  /// row already marked read (on the website, say) is accounted for without
  /// being shown. [keep] decides which old keys are still worth remembering;
  /// by default the newest [_seenLimit].
  List<AppNotification> _file(
    NotificationState state,
    String source,
    List<AppNotification> candidates, {
    bool Function(String key)? keep,
  }) {
    final List<String>? known = state.seen[source];
    final Set<String> knownSet = <String>{...?known};
    final List<AppNotification> fresh = <AppNotification>[
      if (known != null)
        for (final AppNotification n in candidates)
          if (!knownSet.contains(n.key) && !n.read) n,
    ];

    final List<String> next = <String>[
      ...?known,
      for (final AppNotification n in candidates)
        if (knownSet.add(n.key)) n.key,
    ];
    final Iterable<String> kept = keep == null
        ? next.skip(next.length > _seenLimit ? next.length - _seenLimit : 0)
        : next.where(keep);
    state.seen[source] = kept.toList();
    return fresh;
  }

  /// An attendance key is only worth remembering while the server can still
  /// return it — `days=1` reaches back a day — plus a day of slack for a
  /// phone whose clock disagrees with Baku's.
  static bool _isRecentAttendance(String key, DateTime now) {
    // att:{id}:{in|out}:{YYYY-MM-DD HH:MM}
    final List<String> parts = key.split(':');
    if (parts.length < 4) return false;
    final DateTime? day = DateTime.tryParse(parts[3].split(' ').first);
    if (day == null) return false;
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !day.isBefore(today.subtract(const Duration(days: 2)));
  }

  Future<Object?> _ask(String endpoint, Map<String, String> query) async {
    try {
      return await _client.get(endpoint, query: query);
    } on ApiException {
      return _failed;
    }
  }

  /// A source that did not answer. Nothing is filed for it, so its rows are
  /// still new when it answers next time.
  static const Object _failed = _Marker('failed');

  /// A source this account does not have — attendance, for anyone but an
  /// owner.
  static const Object _skipped = _Marker('skipped');
}

class _Marker {
  const _Marker(this.name);

  final String name;

  @override
  String toString() => name;
}
