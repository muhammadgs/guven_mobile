import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/tasks/data/task_edit_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_edit.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

/// What finishing a task actually costs in requests.
///
/// Two calls, not one, and the second is the point of this file. The backend
/// does not archive a task it marks completed — its own `complete` verb tried
/// to and is broken — so `Arxiv`, which is read from `/task-archive/…` and
/// never from the tasks table, only ever shows what the client put there. A
/// completion that skips the copy is a task that finishes and then disappears.
void main() {
  group('finishing a task', () {
    late List<String> calls;
    late List<Map<String, Object?>> bodies;
    late TaskEditApi api;

    setUp(() {
      calls = <String>[];
      bodies = <Map<String, Object?>>[];
      api = _api(calls, bodies);
    });

    test('the status is written into the row, not sent to a verb', () async {
      await api.setStatus(
        task: _task(TaskSource.internal),
        status: TaskEditStatus.complete,
        myUserId: 4,
      );

      // `PUT /tasks/12/complete` is the call this used to make. It answers with
      // `TaskArchiveService has no attribute 'update_task'`, and the website
      // has never called it either.
      expect(calls, <String>['PATCH /api/v1/tasks/12']);
      expect(bodies.single['status'], 'completed');
      expect(bodies.single['progress_percentage'], 100);
      expect(bodies.single['completed_date'], isNotNull);
    });

    test('and the finished task is copied into the archive', () async {
      expect(
        await api.archive(task: _task(TaskSource.internal), myUserId: 4),
        isTrue,
      );

      // Read back first: the archive keeps a dozen columns no list row
      // carries, and the copy has to be of the task as it now stands.
      expect(calls, <String>[
        'GET /api/v1/tasks/12',
        'POST /api/v1/task-archive/archive',
      ]);

      final Map<String, Object?> archived = bodies.single;
      expect(archived['original_task_id'], 12);
      expect(archived['task_code'], 'TASK-2026-118');
      expect(archived['task_title'], 'Saytın ödəniş səhifəsi');
      expect(archived['company_id'], 51);
      expect(archived['status'], 'completed');
      expect(archived['progress_percentage'], 100);
      expect(archived['archive_reason'], 'Tamamlandığı üçün arxivləndi');
      expect(archived['archived_by'], 4);

      // The row never answered these, so they are absent rather than null: an
      // insert with a null in it writes over the default the backend would
      // otherwise have filled in.
      expect(archived.containsKey('department_id'), isFalse);
      expect(archived.containsKey('target_company_id'), isFalse);

      // Two `text[]` columns, and this backend reads them as PostgreSQL array
      // literals rather than as JSON arrays.
      expect(archived['file_uuids'], '{"$_uuid"}');
      expect(archived['tags'], '{"ödəniş"}');

      // The hours are copied across exactly as the row spells them — the
      // archive is where the cost of the work is read back from afterwards.
      expect(archived['actual_hours'], '6.50');
    });

    test('each kind of task is filed in its own list', () async {
      await api.archive(task: _task(TaskSource.external), myUserId: 4);
      expect(calls.last, 'POST /api/v1/task-archive/archive-external');
      expect(bodies.last['task_source'], 'sifarishci');

      calls.clear();
      bodies.clear();
      await api.archive(task: _task(TaskSource.partner), myUserId: 4);
      expect(calls, <String>[
        'GET /api/v1/partner-tasks/12',
        'POST /api/v1/task-archive/archive-partner',
        // A finished partner task does not leave the site's table on its own
        // the way a task does — that table draws every row it is given — so
        // it is taken out once the copy is filed.
        'PUT /api/v1/partner-tasks/12',
      ]);
      expect(bodies.first['task_source'], 'partnyor');
      expect(bodies.first['is_partner_task'], isTrue);
      // `Qeyd` lives in its own column on a partner task, and in the ordinary
      // one in the archive.
      expect(bodies.first['notes'], 'Ödəniş sonra həll olunacaq');
      expect(bodies.last['is_active'], isFalse);
    });

    test('a task with no company is not filed at all', () async {
      final TaskEditApi thin = _api(
        calls,
        bodies,
        row: <String, Object?>{'id': 12, 'task_title': 'Ödəniş səhifəsi'},
      );

      expect(
        await thin.archive(task: _task(TaskSource.internal), myUserId: 4),
        isFalse,
      );
      // The archive is keyed by company; a copy filed under none is one no
      // screen would ever find again, so it is not written.
      expect(calls, <String>['GET /api/v1/tasks/12']);
    });

    test('an archive that refuses does not lose the completion', () async {
      final TaskEditApi refusing = _api(calls, bodies, archiveStatus: 500);

      expect(
        await refusing.archive(task: _task(TaskSource.internal), myUserId: 4),
        isFalse,
      );
      // By this point the task is already completed. Throwing here would have
      // the sheet call the whole save failed, which is wrong about the half
      // that worked — the caller says it in words instead.
      expect(calls.last, 'POST /api/v1/task-archive/archive');
    });
  });

  group('which resource a kind is written to', () {
    late List<String> calls;
    late List<Map<String, Object?>> bodies;
    late TaskEditApi api;

    setUp(() {
      calls = <String>[];
      bodies = <Map<String, Object?>>[];
      api = _api(calls, bodies);
    });

    // The three are separate tables with separate id sequences —
    // `POST /tasks-external/sync/{main_task_id}` exists to copy a row from one
    // into the other. So sending a cross-company task to `/tasks/{id}` does
    // not fail: it reads and rewrites whichever *internal* task happens to
    // hold that number. Nothing about the response would say so.
    for (final (TaskSource source, String prefix) in <(TaskSource, String)>[
      (TaskSource.internal, '/api/v1/tasks/12'),
      (TaskSource.external, '/api/v1/tasks-external/12'),
      (TaskSource.partner, '/api/v1/partner-tasks/12'),
    ]) {
      test('${source.name} is read and written at $prefix', () async {
        await api.load(_task(source));
        expect(calls, <String>['GET $prefix']);

        calls.clear();
        await api.save(
          task: _task(source),
          myUserId: 4,
          description: 'Yenilənmiş açıqlama',
        );
        // A partner task is the one typed schema, so it is a PUT that also
        // carries `updated_by`; the other two take a free-form PATCH.
        final bool partner = source == TaskSource.partner;
        expect(calls, <String>['${partner ? 'PUT' : 'PATCH'} $prefix']);
        expect(bodies.last['task_description'], 'Yenilənmiş açıqlama');
        expect(bodies.last.containsKey('updated_by'), partner);

        calls.clear();
        await api.setStatus(
          task: _task(source),
          status: TaskEditStatus.cancel,
          myUserId: 4,
        );
        expect(calls, <String>['${partner ? 'PUT' : 'PATCH'} $prefix']);
        expect(bodies.last['status'], 'cancelled');
      });
    }

    test('a read-only archive row has no resource at all', () async {
      expect(
        () => api.load(_task(TaskSource.readOnly)),
        throwsA(isA<Object>()),
      );
      expect(calls, isEmpty);
    });
  });
}

TaskEditApi _api(
  List<String> calls,
  List<Map<String, Object?>> bodies, {
  Map<String, Object?>? row,
  int archiveStatus = 200,
}) {
  final MockClient transport = MockClient((http.Request request) async {
    calls.add('${request.method} ${request.url.path}');
    if (request.body.isNotEmpty) {
      bodies.add(jsonDecode(request.body) as Map<String, Object?>);
    }
    if (request.method == 'GET') {
      // The charset is not decoration: without it `http` falls back to latin1
      // and the Azerbaijani in this row will not survive the round trip.
      return http.Response(
        jsonEncode(row ?? _row),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }
    if (request.url.path.contains('task-archive')) {
      return http.Response('{}', archiveStatus);
    }
    return http.Response('{}', 200);
  });
  return TaskEditApi(ApiClient(tokens: TokenStore(), httpClient: transport));
}

TaskItem _task(TaskSource source) => TaskItem(
  id: 12,
  source: source,
  company: 'Güvən Finans MMC',
  workType: 'Frontend',
  status: TaskStatus.inProgress,
  assignedTo: 'Əli Balakişiyev',
  assignedToId: 7,
);

/// The task as `GET /tasks/{id}` answers it.
const Map<String, Object?> _row = <String, Object?>{
  'id': 12,
  'task_code': 'TASK-2026-118',
  'task_title': 'Saytın ödəniş səhifəsi',
  'task_description': 'Ödəniş formu yenilənsin',
  'assigned_to': 7,
  'created_by': 4,
  'creator_name': 'Məhəmməd Qasımov',
  'company_id': 51,
  'company_name': 'Güvən Finans MMC',
  'priority': 'high',
  'due_date': '2026-09-30',
  'started_date': '2026-09-02',
  'work_type_id': 3,
  'notes': 'Ödəniş sonra həll olunacaq',
  'partner_notes': 'Ödəniş sonra həll olunacaq',
  'estimated_hours': '8.00',
  'actual_hours': '6.50',
  'is_billable': true,
  'tags': <String>['ödəniş'],
  'file_uuids': <String>[_uuid],
  'department_id': null,
};
