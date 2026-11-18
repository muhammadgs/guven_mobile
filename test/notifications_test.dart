import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/notifications/application/notification_background.dart';
import 'package:guven_mobile/src/features/notifications/application/notification_presenter.dart';
import 'package:guven_mobile/src/features/notifications/application/notification_sync.dart';
import 'package:guven_mobile/src/features/notifications/data/notification_store.dart';
import 'package:guven_mobile/src/features/notifications/domain/app_notification.dart';
import 'package:guven_mobile/src/features/notifications/domain/notification_sources.dart';

/// A row of `/attendance/company/{code}/history`, in the shape seen live on
/// 2026-11-15.
Map<String, Object?> _employee(
  int id,
  String first,
  String last, {
  List<Map<String, Object?>> entries = const <Map<String, Object?>>[],
  List<Map<String, Object?>> exits = const <Map<String, Object?>>[],
}) => <String, Object?>{
  'id': id,
  'first_name': first,
  'last_name': last,
  'position': 'Mühasib',
  'is_active': true,
  'entries': entries,
  'exits': exits,
  'today_entries': <String>[
    for (final Map<String, Object?> e in entries) '${e['timestamp']}',
  ],
  'today_exits': <String>[
    for (final Map<String, Object?> e in exits) '${e['timestamp']}',
  ],
};

Map<String, Object?> _stamp(String at, [String note = '']) => <String, Object?>{
  'timestamp': at,
  'note': note,
};

Map<String, Object?> _company(List<Map<String, Object?>> employees) =>
    <String, Object?>{
      'success': true,
      'company_code': 'GUV26001',
      'today': '2026-11-15',
      'days': 1,
      'employees': employees,
    };

Map<String, Object?> _task(
  int id, {
  int assignedTo = 150,
  int createdBy = 129,
}) => <String, Object?>{
  'id': id,
  'task_title': 'Natural Meat MMC',
  'work_type_name': 'Proqram təm. - DÜZƏLİŞLƏR',
  'assigned_to': assignedTo,
  'created_by': createdBy,
  'creator_name': 'İlkin Qurbanov',
  'created_at': '2026-11-15T07:00:00',
};

const NotificationProfile _employeeProfile = NotificationProfile(
  userId: 150,
  companyCode: 'GUV26001',
  isOwner: false,
  isCompanyAccount: false,
);

const NotificationProfile _ownerProfile = NotificationProfile(
  userId: 72,
  companyCode: 'GUV26001',
  isOwner: true,
  isCompanyAccount: false,
);

/// A backend whose answers the test changes between checks.
class _Backend {
  Object? notifications = <Object?>[];
  Object? tasks = <Object?>[];
  Object? attendance = _company(<Map<String, Object?>>[]);
  final Set<String> failing = <String>{};
  final List<String> asked = <String>[];

  late final MockClient client = MockClient((http.Request request) async {
    final String path = request.url.path;
    asked.add(path);
    Object? body;
    if (path.endsWith('/notifications/recent')) {
      body = notifications;
    } else if (path.endsWith('/tasks/detailed')) {
      body = tasks;
    } else if (path.contains('/attendance/company/')) {
      body = attendance;
    }
    if (failing.any(path.contains)) {
      return http.Response('{"detail":"down"}', 500);
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });

  NotificationSync sync(NotificationStore store, {DateTime? now}) =>
      NotificationSync(
        client: ApiClient(tokens: TokenStore(), httpClient: client),
        store: store,
        clock: now == null ? null : () => now,
      );
}

class _RecordingPresenter implements NotificationPresenter {
  final List<List<AppNotification>> shown = <List<AppNotification>>[];
  final List<int> badges = <int>[];
  int cleared = 0;

  @override
  Future<void> init({NotificationTapCallback? onTap}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show(List<AppNotification> items, {required int badge}) async {
    shown.add(items);
    badges.add(badge);
  }

  @override
  Future<void> setBadge(int count) async => badges.add(count);

  @override
  Future<void> clearAll() async => cleared++;
}

void main() {
  final DateTime now = DateTime(2026, 11, 15, 12);

  group('NotificationSources.backend', () {
    test('reads a bare list and the website envelope alike', () {
      final Map<String, Object?> row = <String, Object?>{
        'id': 812,
        'title': 'Yeni məktub',
        'message': 'Vergi idarəsindən',
        'notification_type': 'system_alert',
        'created_at': '2026-11-15T08:00:00',
        'is_read': false,
      };
      final List<AppNotification> bare = NotificationSources.backend(<Object?>[
        row,
      ]);
      final List<AppNotification> wrapped = NotificationSources.backend(
        <String, Object?>{
          'notifications': <Object?>[row],
        },
      );
      for (final List<AppNotification> list in <List<AppNotification>>[
        bare,
        wrapped,
      ]) {
        expect(list, hasLength(1));
        expect(list.single.key, 'api:812');
        expect(list.single.title, 'Yeni məktub');
        expect(list.single.body, 'Vergi idarəsindən');
        expect(list.single.kind, NotificationKind.general);
        expect(list.single.read, isFalse);
      }
    });

    test('a row read on the website arrives read', () {
      final List<AppNotification> list = NotificationSources.backend(<Object?>[
        <String, Object?>{'id': 1, 'title': 'a', 'is_read': true},
        <String, Object?>{'id': 2, 'title': 'b', 'read_at': '2026-11-15'},
        <String, Object?>{'id': 3, 'title': 'c', 'status': 'read'},
      ]);
      expect(list.every((AppNotification n) => n.read), isTrue);
    });

    test('a task-type row goes on the tasks channel', () {
      final List<AppNotification> list = NotificationSources.backend(<Object?>[
        <String, Object?>{
          'id': 9,
          'title': 'x',
          'notification_type': 'task_assigned',
        },
      ]);
      expect(list.single.kind, NotificationKind.task);
    });
  });

  group('NotificationSources.assignedTasks', () {
    test('only tasks someone else gave me', () {
      final List<AppNotification> list = NotificationSources.assignedTasks(
        <Object?>[_task(1), _task(2, assignedTo: 72), _task(3, createdBy: 150)],
        userId: 150,
      );
      expect(list.map((AppNotification n) => n.key), <String>['task:1']);
      expect(list.single.title, 'Sizə yeni tapşırıq yaradıldı');
      expect(
        list.single.body,
        'İlkin Qurbanov: Natural Meat MMC — Proqram təm. - DÜZƏLİŞLƏR',
      );
      expect(list.single.target, '1');
    });
  });

  group('NotificationSources.companyAttendance', () {
    test('today only, never my own, worded with the site rules', () {
      final List<AppNotification> list = NotificationSources.companyAttendance(
        _company(<Map<String, Object?>>[
          _employee(
            72,
            'Vüsal',
            'Əsədov',
            entries: <Map<String, Object?>>[_stamp('2026-11-15 08:55')],
          ),
          _employee(
            205,
            'Cavid',
            'Əhmədov',
            entries: <Map<String, Object?>>[
              _stamp('2026-11-14 09:12'),
              _stamp('2026-11-15 09:14', 'Tıxac'),
            ],
            exits: <Map<String, Object?>>[_stamp('2026-11-15 16:50')],
          ),
          _employee(
            129,
            'İlkin',
            'Qurbanov',
            entries: <Map<String, Object?>>[
              _stamp('2026-11-15 10:30', 'İcazəli'),
            ],
            exits: <Map<String, Object?>>[_stamp('2026-11-15 18:05')],
          ),
        ]),
        ownId: 72,
      );

      final Map<String, AppNotification> byKey = <String, AppNotification>{
        for (final AppNotification n in list) n.key: n,
      };
      expect(byKey.keys, <String>{
        'att:205:in:2026-11-15 09:14',
        'att:205:out:2026-11-15 16:50',
        'att:129:in:2026-11-15 10:30',
        'att:129:out:2026-11-15 18:05',
      });

      final AppNotification late = byKey['att:205:in:2026-11-15 09:14']!;
      expect(late.title, 'Cavid Əhmədov işə gəldi');
      expect(late.body, 'Saat 09:14 · 14 dəq gecikmə\nSəbəb: Tıxac');
      expect(late.kind, NotificationKind.attendance);

      final AppNotification early = byKey['att:205:out:2026-11-15 16:50']!;
      expect(early.title, 'Cavid Əhmədov işdən çıxdı');
      expect(early.body, 'Saat 16:50 · 1 saat 10 dəq tez çıxış');

      expect(
        byKey['att:129:in:2026-11-15 10:30']!.body,
        'Saat 10:30 · İcazəli',
      );
      expect(byKey['att:129:out:2026-11-15 18:05']!.body, 'Saat 18:05');

      // 09:14 in Baku is 05:14 UTC.
      expect(late.createdAt.toUtc(), DateTime.utc(2026, 11, 15, 5, 14));
    });

    test('a company account hides nobody', () {
      final List<AppNotification> list = NotificationSources.companyAttendance(
        _company(<Map<String, Object?>>[
          _employee(
            72,
            'Vüsal',
            'Əsədov',
            entries: <Map<String, Object?>>[_stamp('2026-11-15 08:55')],
          ),
        ]),
        ownId: null,
      );
      expect(list, hasLength(1));
    });

    test('falls back to the bare strings, seconds dropped', () {
      final List<AppNotification> list = NotificationSources.companyAttendance(
        <String, Object?>{
          'data': <String, Object?>{
            'today': '2026-11-15',
            'employees': <Object?>[
              <String, Object?>{
                'id': 5,
                'first_name': 'Könül',
                'last_name': 'Əsədova',
                'today_entries': <String>['2026-11-15 08:40:12'],
              },
            ],
          },
        },
        ownId: 72,
      );
      expect(list.single.key, 'att:5:in:2026-11-15 08:40');
      expect(list.single.body, 'Saat 08:40');
    });
  });

  group('NotificationSync', () {
    test('the first answer of every source is filed silently', () async {
      final _Backend backend = _Backend()
        ..tasks = <Object?>[_task(1)]
        ..notifications = <Object?>[
          <String, Object?>{'id': 5, 'title': 'Köhnə'},
        ];
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );

      final NotificationSyncResult first = await backend.sync(store).run();
      expect(first.fresh, isEmpty);
      expect(first.unread, 0);
      expect(store.state!.seen['tasks'], <String>['task:1']);
      expect(store.state!.seen['backend'], <String>['api:5']);
    });

    test('then a new task is news, once', () async {
      final _Backend backend = _Backend()..tasks = <Object?>[_task(1)];
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );
      final NotificationSync sync = backend.sync(store);
      await sync.run();

      backend.tasks = <Object?>[_task(2), _task(1)];
      final NotificationSyncResult second = await sync.run();
      expect(second.fresh.map((AppNotification n) => n.key), <String>[
        'task:2',
      ]);
      expect(second.unread, 1);
      expect(store.state!.inbox.single.key, 'task:2');

      final NotificationSyncResult third = await sync.run();
      expect(third.fresh, isEmpty);
      expect(third.unread, 1);

      expect(await sync.markAllRead(), 0);
      expect(store.state!.unread, 0);
      expect(store.state!.inbox.single.read, isTrue);
    });

    test('a source that failed at first is still baselined later', () async {
      final _Backend backend = _Backend()
        ..tasks = <Object?>[_task(1)]
        ..failing.add('/tasks/');
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );
      final NotificationSync sync = backend.sync(store);
      await sync.run();
      expect(store.state!.seen.containsKey('tasks'), isFalse);

      backend.failing.clear();
      expect((await sync.run()).fresh, isEmpty);
      expect(store.state!.seen['tasks'], <String>['task:1']);
    });

    test('an already-read notification is never shown', () async {
      final _Backend backend = _Backend();
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );
      final NotificationSync sync = backend.sync(store);
      await sync.run();
      backend.notifications = <Object?>[
        <String, Object?>{'id': 7, 'title': 'Oxunub', 'is_read': true},
        <String, Object?>{'id': 8, 'title': 'Yeni', 'is_read': false},
      ];
      final NotificationSyncResult result = await sync.run();
      expect(result.fresh.map((AppNotification n) => n.key), <String>['api:8']);
    });

    test('attendance is asked for only by an owner', () async {
      final _Backend backend = _Backend();
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );
      await backend.sync(store).run();
      expect(
        backend.asked.any((String p) => p.contains('/attendance/')),
        isFalse,
      );
    });

    test('an owner hears of each check-in and check-out once', () async {
      final _Backend backend = _Backend()
        ..attendance = _company(<Map<String, Object?>>[
          _employee(
            205,
            'Cavid',
            'Əhmədov',
            entries: <Map<String, Object?>>[_stamp('2026-11-15 08:50')],
          ),
        ]);
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _ownerProfile),
      );
      final NotificationSync sync = backend.sync(store, now: now);
      expect((await sync.run()).fresh, isEmpty);
      expect(
        backend.asked.where((String p) => p.contains('/attendance/')),
        <String>['/api/v1/attendance/company/GUV26001/history'],
      );

      backend.attendance = _company(<Map<String, Object?>>[
        _employee(
          205,
          'Cavid',
          'Əhmədov',
          entries: <Map<String, Object?>>[_stamp('2026-11-15 08:50')],
          exits: <Map<String, Object?>>[_stamp('2026-11-15 18:02')],
        ),
        _employee(
          129,
          'İlkin',
          'Qurbanov',
          entries: <Map<String, Object?>>[_stamp('2026-11-15 09:20')],
        ),
      ]);
      final NotificationSyncResult result = await sync.run();
      // Oldest first, so the newest lands on top of the shade.
      expect(result.fresh.map((AppNotification n) => n.key), <String>[
        'att:129:in:2026-11-15 09:20',
        'att:205:out:2026-11-15 18:02',
      ]);
      expect(result.unread, 2);
      expect(store.state!.inbox.first.key, 'att:205:out:2026-11-15 18:02');
      expect((await sync.run()).fresh, isEmpty);
    });

    test('old attendance keys are forgotten, recent ones kept', () async {
      final _Backend backend = _Backend();
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(
          profile: _ownerProfile,
          seen: <String, List<String>>{
            'attendance': <String>[
              'att:1:in:2026-11-01 09:00',
              'att:1:in:2026-11-14 09:00',
            ],
          },
        ),
      );
      await backend.sync(store, now: now).run();
      expect(store.state!.seen['attendance'], <String>[
        'att:1:in:2026-11-14 09:00',
      ]);
    });

    test('nothing is filed for an account that signed out mid-check', () async {
      final _Backend backend = _Backend()..tasks = <Object?>[_task(1)];
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(
          profile: _employeeProfile,
          seen: <String, List<String>>{'tasks': <String>[]},
        ),
      );
      final MockClient slow = MockClient((http.Request request) async {
        await store.clear();
        return backend.client.send(request).then(http.Response.fromStream);
      });
      final NotificationSyncResult result = await NotificationSync(
        client: ApiClient(tokens: TokenStore(), httpClient: slow),
        store: store,
      ).run();
      expect(result.fresh, isEmpty);
      expect(store.state, isNull);
    });

    test('a foreground check stamps the beat', () async {
      final _Backend backend = _Backend();
      final MemoryNotificationStore store = MemoryNotificationStore(
        NotificationState(profile: _employeeProfile),
      );
      await backend.sync(store, now: now).run(foreground: true);
      expect(store.state!.foregroundBeat, now);
    });
  });

  group('background check', () {
    test('stands down while the app is checking for itself', () async {
      final _RecordingPresenter presenter = _RecordingPresenter();
      await runBackgroundNotificationCheck(
        store: MemoryNotificationStore(
          NotificationState(
            profile: _employeeProfile,
            foregroundBeat: now.subtract(const Duration(minutes: 1)),
          ),
        ),
        presenter: presenter,
        clock: () => now,
      );
      expect(presenter.badges, isEmpty);
      expect(presenter.shown, isEmpty);
    });

    test('does nothing for a signed-out phone', () async {
      final _RecordingPresenter presenter = _RecordingPresenter();
      await runBackgroundNotificationCheck(
        store: MemoryNotificationStore(),
        presenter: presenter,
        clock: () => now,
      );
      expect(presenter.badges, isEmpty);
    });
  });

  group('storage', () {
    test('the state survives a round trip through the file', () async {
      final Directory dir = await Directory.systemTemp.createTemp('notify');
      addTearDown(() => dir.delete(recursive: true));
      final FileNotificationStore store = FileNotificationStore(
        directory: () async => dir,
      );
      expect(await store.load(), isNull);

      await store.save(
        NotificationState(
          profile: _ownerProfile,
          seen: <String, List<String>>{
            'tasks': <String>['task:1'],
          },
          inbox: <AppNotification>[
            AppNotification(
              key: 'task:1',
              kind: NotificationKind.task,
              title: 'Sizə yeni tapşırıq yaradıldı',
              body: 'İlkin Qurbanov: Natural Meat MMC',
              createdAt: now,
              target: '1',
            ),
          ],
          foregroundBeat: now,
          permissionAsked: true,
        ),
      );
      final NotificationState? back = await store.load();
      expect(back, isNotNull);
      expect(back!.profile.sameAs(_ownerProfile), isTrue);
      expect(back.seen['tasks'], <String>['task:1']);
      expect(back.inbox.single.title, 'Sizə yeni tapşırıq yaradıldı');
      expect(back.inbox.single.createdAt, now);
      expect(back.foregroundBeat, now.toUtc());
      expect(back.permissionAsked, isTrue);
      expect(back.unread, 1);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('the status-bar glyph fits aapt2 string limit', () {
      // aapt2 swaps any string past 32,767 characters for the literal
      // "STRING_TOO_LARGE"; the glyph then fails to load and SystemUI drops
      // every notification without a word. Seen on 2026-11-15.
      final String xml = File(
        'android/app/src/main/res/drawable/ic_stat_guven.xml',
      ).readAsStringSync();
      final Iterable<RegExpMatch> paths = RegExp(
        r'android:pathData="([^"]*)"',
      ).allMatches(xml);
      expect(paths, isNotEmpty);
      for (final RegExpMatch path in paths) {
        expect(path.group(1)!.length, lessThan(32767));
      }
    });

    test('notification ids are stable, positive and distinct', () {
      expect(stableNotificationId('task:1'), stableNotificationId('task:1'));
      expect(
        stableNotificationId('task:1'),
        isNot(stableNotificationId('task:2')),
      );
      for (final String key in <String>['', 'api:1', 'att:205:in:x']) {
        final int id = stableNotificationId(key);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });
}
