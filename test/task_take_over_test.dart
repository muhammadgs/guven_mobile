import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/tasks/data/tasks_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `Götür` — who may take a refused task over, and what taking it writes.
///
/// The rule, in the user's words on 2026-09-08: a refusal only ends *this*
/// executor's part in the task. Anybody else may pick it up, the person who
/// raised it included — they then carry out their own task. The one person who
/// may not is the executor it was refused by, and that holds however they came
/// to be one. Getting this wrong in either direction is a real fault: too
/// narrow and refused work sits in the list with nobody able to touch it, too
/// wide and the refusal can be undone by the very person who made it.
void main() {
  TaskItem task({
    TaskStatus status = TaskStatus.rejected,
    TaskSource source = TaskSource.internal,
    int? id = 12,
    int? assignedToId = 7,
    String? assignedTo = 'Əli Balakişiyev',
    int? assignedById = 4,
    String? assignedBy = 'Məhəmməd Qasımov',
  }) {
    return TaskItem(
      id: id,
      source: source,
      company: 'Güvən Finans MMC',
      workType: 'Frontend',
      status: status,
      assignedBy: assignedBy,
      assignedById: assignedById,
      assignedTo: assignedTo,
      assignedToId: assignedToId,
    );
  }

  group('who may take a refused task', () {
    test('anybody who is not carrying it may', () {
      expect(task().canTakeOver(userId: 99), isTrue);
    });

    test('whoever raised it may, and becomes its executor', () {
      // Even when they are the one who refused it: a creator refusing a task
      // they handed to somebody else has not refused it *as* its executor.
      expect(task().canTakeOver(userId: 4), isTrue);
    });

    test('the executor it was refused by may not', () {
      expect(task().canTakeOver(userId: 7), isFalse);
    });

    test('…including when that executor also raised it', () {
      // The one case the two rules could disagree about. They do not: this
      // person is the executor, so taking it straight back would undo their
      // own refusal instead of handing the work on.
      final TaskItem own = task(assignedById: 7, assignedBy: 'Əli Balakişiyev');
      expect(own.canTakeOver(userId: 7), isFalse);
    });

    test('a name stands in where the row carries no ids', () {
      final TaskItem row = task(assignedToId: null, assignedById: null);
      expect(row.canTakeOver(fullName: 'əli balakişiyev'), isFalse);
      expect(row.canTakeOver(fullName: 'Məhəmməd Qasımov'), isTrue);
    });

    test('only a refusal offers it', () {
      for (final TaskStatus other in TaskStatus.values) {
        if (other == TaskStatus.rejected) continue;
        expect(
          task(status: other).canTakeOver(userId: 99),
          isFalse,
          reason: '$other',
        );
      }
    });

    test('an archive row has no endpoint to write to', () {
      expect(
        task(source: TaskSource.readOnly).canTakeOver(userId: 99),
        isFalse,
      );
      expect(task(id: null).canTakeOver(userId: 99), isFalse);
    });
  });

  group('the button a refused card offers', () {
    test('is the hand, and nothing else', () {
      expect(actionsFor(TaskStatus.rejected, mine: false, canTake: true), <
        TaskAction
      >[
        TaskAction.take,
      ]);
    });

    test('is not offered to the executor who refused it', () {
      // Their card is the status chip alone: `Redaktə` is shut on finished
      // work too, so there is nothing left for them to press.
      expect(actionsFor(TaskStatus.rejected, mine: true), isEmpty);
      expect(actionsFor(TaskStatus.rejected, mine: true, canEdit: true), <
        TaskAction
      >[
        TaskAction.edit,
      ]);
    });

    test('wears an icon instead of a word, and it is the only one that does', () {
      for (final TaskAction action in TaskAction.values) {
        expect(
          action.icon != null,
          action == TaskAction.take,
          reason: action.label,
        );
      }
      // The label survives anyway: it is what a screen reader is given.
      expect(TaskAction.take.label, 'Götür');
    });
  });

  group('what taking it writes', () {
    late List<String> calls;
    late List<Map<String, Object?>> bodies;
    late TasksApi api;

    setUp(() {
      calls = <String>[];
      bodies = <Map<String, Object?>>[];
      api = _api(calls, bodies);
    });

    test('two columns: the new executor, and a state to work in', () async {
      expect(await api.take(task(), myUserId: 99), TaskStatus.pending);

      // Through the ordinary update endpoint, like every other status this app
      // sets — the backend's own status verbs answer 500 and the website has
      // never called them.
      expect(calls, <String>['PATCH /api/v1/tasks/12']);
      expect(bodies.single, <String, Object?>{
        'assigned_to': 99,
        // Back where a freshly assigned task starts, so the new executor's
        // card offers `Başla`. Left at `rejected` it would stay a record.
        'status': 'pending',
      });
    });

    test('a partner task is the typed schema, so it carries updated_by', () async {
      await api.take(task(source: TaskSource.partner), myUserId: 99);

      expect(calls, <String>['PUT /api/v1/partner-tasks/12']);
      expect(bodies.single['updated_by'], 99);
      expect(bodies.single['assigned_to'], 99);
    });

    test('a cross-company task is written to its own table', () async {
      await api.take(task(source: TaskSource.external), myUserId: 99);
      expect(calls, <String>['PATCH /api/v1/tasks-external/12']);
    });

    test('nothing is written with nobody to hand it to', () async {
      // A write with a null executor would leave the task refused *and*
      // unassigned, which is worse than the refusal.
      await expectLater(api.take(task(), myUserId: null), throwsA(anything));
      expect(calls, isEmpty);
    });
  });
}

TasksApi _api(List<String> calls, List<Map<String, Object?>> bodies) {
  final MockClient transport = MockClient((http.Request request) async {
    calls.add('${request.method} ${request.url.path}');
    if (request.body.isNotEmpty) {
      bodies.add(jsonDecode(request.body) as Map<String, Object?>);
    }
    return http.Response('{}', 200);
  });
  return TasksApi(ApiClient(tokens: TokenStore(), httpClient: transport));
}
