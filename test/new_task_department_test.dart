import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/auth/domain/auth_user.dart';
import 'package:guven_mobile/src/features/tasks/application/new_task_controller.dart';
import 'package:guven_mobile/src/features/tasks/data/task_create_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';

/// `Şöbə` follows the executor: choosing who carries the task out fills in
/// their department, and the user can still change it afterwards — the way
/// the website's `autoSelectDepartmentByEmployee` does it.
void main() {
  test('an employee row carries its department in any spelling', () {
    expect(
      TaskOption.employee(<String, Object?>{
        'id': 7,
        'first_name': 'Əli',
        'department_id': 3,
      })?.departmentId,
      3,
    );
    expect(
      TaskOption.employee(<String, Object?>{
        'id': 7,
        'first_name': 'Əli',
        'department': <String, Object?>{'id': '5'},
      })?.departmentId,
      5,
    );
    expect(
      TaskOption.employee(<String, Object?>{
        'id': 7,
        'first_name': 'Əli',
      })?.departmentId,
      isNull,
    );
  });

  test(
    'Şöbə comes straight after İcra edən; the watcher sits by the switch',
    () {
      final NewTaskController c = NewTaskController(_Session(), api: _Api());
      addTearDown(c.dispose);

      c.begin(NewTaskKind.internal);
      expect(c.fieldsAboveDeadline, <NewTaskField>[
        NewTaskField.company,
        NewTaskField.executor,
        NewTaskField.department,
        NewTaskField.workType,
      ]);
      expect(c.fieldsBelowDeadline, <NewTaskField>[NewTaskField.otherWorker]);

      // On a task handed to another company their person *is* the executor,
      // so they take İcra edən's place and Şöbə follows them.
      c.begin(NewTaskKind.company);
      expect(c.fieldsAboveDeadline, <NewTaskField>[
        NewTaskField.company,
        NewTaskField.otherWorker,
        NewTaskField.department,
        NewTaskField.workType,
      ]);
      expect(c.fieldsBelowDeadline, isEmpty);
    },
  );

  test(
    'choosing the executor fills Şöbə, and the user may change it',
    () async {
      final NewTaskController c = NewTaskController(_Session(), api: _Api());
      addTearDown(c.dispose);
      c.begin(NewTaskKind.internal);
      await pumpEventQueue();

      c.choose(NewTaskField.executor, _ali);
      expect(c.chosen(NewTaskField.department)?.name, 'Mühasibatlıq');

      c.choose(NewTaskField.department, _it);
      expect(c.chosen(NewTaskField.department)?.name, 'IT');

      // A different executor brings their own department with them.
      c.choose(NewTaskField.executor, _ali);
      expect(c.chosen(NewTaskField.department)?.name, 'Mühasibatlıq');
    },
  );

  test(
    'an executor chosen before the departments arrive is honoured later',
    () async {
      final _Api api = _Api(slowDepartments: true);
      final NewTaskController c = NewTaskController(_Session(), api: api);
      addTearDown(c.dispose);
      c.begin(NewTaskKind.internal);
      await pumpEventQueue();

      c.choose(NewTaskField.executor, _ali);
      expect(c.chosen(NewTaskField.department), isNull);

      api.releaseDepartments();
      await pumpEventQueue();
      expect(c.chosen(NewTaskField.department)?.name, 'Mühasibatlıq');
    },
  );

  test(
    'a row without a department asks /users/{id}, like the website',
    () async {
      final _Api api = _Api();
      final NewTaskController c = NewTaskController(_Session(), api: api);
      addTearDown(c.dispose);
      c.begin(NewTaskKind.internal);
      await pumpEventQueue();

      c.choose(NewTaskField.executor, const TaskOption(id: 9, name: 'Nigar'));
      await pumpEventQueue();

      expect(api.askedAbout, <int>[9]);
      expect(c.chosen(NewTaskField.department)?.name, 'IT');
    },
  );

  test('a choice made by hand is never overwritten by a late lookup', () async {
    final _Api api = _Api(slowUser: true);
    final NewTaskController c = NewTaskController(_Session(), api: api);
    addTearDown(c.dispose);
    c.begin(NewTaskKind.internal);
    await pumpEventQueue();

    c.choose(NewTaskField.executor, const TaskOption(id: 9, name: 'Nigar'));
    c.choose(NewTaskField.department, _accounting);

    api.releaseUser();
    await pumpEventQueue();
    expect(c.chosen(NewTaskField.department)?.name, 'Mühasibatlıq');
  });

  test('the watcher on the internal form does not touch Şöbə', () async {
    final NewTaskController c = NewTaskController(_Session(), api: _Api());
    addTearDown(c.dispose);
    c.begin(NewTaskKind.internal);
    await pumpEventQueue();

    c.choose(NewTaskField.otherWorker, _ali);
    expect(c.chosen(NewTaskField.department), isNull);
  });
}

const TaskOption _accounting = TaskOption(id: 3, name: 'Mühasibatlıq');
const TaskOption _it = TaskOption(id: 4, name: 'IT');
const TaskOption _ali = TaskOption(
  id: 7,
  name: 'Əli Balakişiyev',
  departmentId: 3,
);

class _Session extends SessionController {
  @override
  AuthUser? get user => const AuthUser(
    id: 4,
    statedRole: UserRole.owner,
    companyCode: 'GUV26001',
    firstName: 'Məhəmməd',
    lastName: 'Qasımov',
    companyId: 51,
    companyName: 'Güvən Finans MMC',
  );
}

class _Api extends TaskCreateApi {
  _Api({this.slowDepartments = false, this.slowUser = false})
    : super(ApiClient(tokens: TokenStore()));

  final bool slowDepartments;
  final bool slowUser;
  final List<int> askedAbout = <int>[];

  final Completer<void> _departments = Completer<void>();
  final Completer<void> _user = Completer<void>();

  void releaseDepartments() => _departments.complete();
  void releaseUser() => _user.complete();

  @override
  Future<List<TaskOption>> subCompanies(String companyCode) async =>
      const <TaskOption>[];

  @override
  Future<List<TaskOption>> employees(String companyCode) async =>
      const <TaskOption>[_ali];

  @override
  Future<List<TaskOption>> departments(String companyCode) async {
    if (slowDepartments) await _departments.future;
    return const <TaskOption>[_accounting, _it];
  }

  @override
  Future<List<TaskOption>> workTypes(int companyId) async =>
      const <TaskOption>[];

  @override
  Future<int?> departmentOf(int userId) async {
    askedAbout.add(userId);
    if (slowUser) await _user.future;
    return 4;
  }
}
