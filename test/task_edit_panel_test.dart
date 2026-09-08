import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/auth/domain/auth_user.dart';
import 'package:guven_mobile/src/features/tasks/application/task_edit_controller.dart';
import 'package:guven_mobile/src/features/tasks/data/task_create_api.dart';
import 'package:guven_mobile/src/features/tasks/data/task_edit_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_edit.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_box.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_edit_panel.dart';

/// The `Redaktə` sheet: does it draw the design's rows, does it open with the
/// task's own answers already in them, and does it send only what was actually
/// changed.
///
/// That last one is the point of the whole controller. The write is a PATCH
/// over a shared row, so a sheet that posted its whole form back would undo
/// whatever anybody else had changed in the meantime — including the columns
/// this sheet never draws.
void main() {
  testWidgets('the sheet draws the design\'s rows, in order', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Redaktə'), findsOneWidget);
    for (final String row in <String>[
      'İcra edən',
      'İşin növü',
      'Tapşırıq açıqlaması',
      'Qeyd',
      'Son müddət',
      'Seçilmiş şirkətə göstər',
      'Status',
      'İmtina',
      'Yadda saxla',
    ]) {
      await tester.dragUntilVisible(
        find.text(row),
        find.byType(ListView),
        const Offset(0, -120),
      );
      expect(find.text(row), findsOneWidget, reason: row);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('it opens with the task\'s own answers in it', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    // The executor and the work type come off the card; the note and the
    // deadline come off the task's own row, which no list endpoint carries.
    expect(find.text('Əli Balakişiyev'), findsOneWidget);
    expect(find.text('Frontend'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Ödəniş sonra həll olunacaq'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    expect(find.text('Ödəniş sonra həll olunacaq'), findsOneWidget);

    // `Status` is the one field that opens blank: it asks where to *leave* the
    // task, not where it is.
    await tester.dragUntilVisible(
      find.text('Status seçin'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    expect(find.text('Status seçin'), findsOneWidget);
  });

  testWidgets('Status offers the three ends and nothing else', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.dragUntilVisible(
      find.text('Status seçin'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.tap(find.text('Status seçin'));
    await tester.pumpAndSettle();

    for (final TaskEditStatus status in TaskEditStatus.values) {
      expect(find.text(status.label), findsOneWidget, reason: status.label);
    }
    // The box the list grew out of is not drawn under it — two lenses in one
    // place read as a double image.
    expect(_hiddenBoxes(tester), 1);

    await tester.tap(find.text('Tamamla'));
    await tester.pumpAndSettle();

    expect(find.text('Status seçin'), findsNothing);
    expect(find.text('Tamamla'), findsOneWidget);
    expect(_hiddenBoxes(tester), 0);
  });

  testWidgets('an untouched sheet writes nothing', (WidgetTester tester) async {
    final _StubEditApi api = _StubEditApi();
    await _pump(tester, api: api);

    await _tapSave(tester);

    expect(api.saved, isNull);
    expect(api.status, isNull);
  });

  testWidgets('only what changed is sent', (WidgetTester tester) async {
    final _StubEditApi api = _StubEditApi();
    final TaskEditController controller = await _pump(tester, api: api);

    controller.setDueDate(DateTime(2026, 10, 15));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    // The deadline moved and nothing else did, so nothing else is in the body
    // — not the description this sheet is holding, and not the executor.
    expect(api.saved, isNotNull);
    expect(api.saved!['due_date'], isNotNull);
    expect(api.saved!.containsKey('assigned_to'), isFalse);
    expect(api.saved!.containsKey('task_description'), isFalse);
    expect(api.saved!.containsKey('work_type_id'), isFalse);
  });

  testWidgets('a status is applied after the fields, and reported back', (
    WidgetTester tester,
  ) async {
    final _StubEditApi api = _StubEditApi();
    TaskEditOutcome? outcome;
    final TaskEditController controller = await _pump(
      tester,
      api: api,
      onSaved: (TaskEditOutcome saved) => outcome = saved,
    );

    controller.setStatus(TaskEditStatus.complete);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(api.status, TaskEditStatus.complete);
    expect(outcome?.saved, isTrue);
    // The card takes this straight away, so its chip swaps at the speed of the
    // tap rather than of the next list fetch.
    expect(outcome?.status, TaskStatus.completed);
  });

  testWidgets('a completed task is filed in the archive', (
    WidgetTester tester,
  ) async {
    // The backend archives nothing, so the sheet has to — `Arxiv` is read from
    // `/task-archive/…` and a task nobody filed finishes and then vanishes.
    final _StubEditApi api = _StubEditApi();
    TaskEditOutcome? outcome;
    final TaskEditController controller = await _pump(
      tester,
      api: api,
      onSaved: (TaskEditOutcome saved) => outcome = saved,
    );

    controller.setStatus(TaskEditStatus.complete);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(api.archived, isTrue);
    expect(outcome?.message, 'Tapşırıq tamamlandı və arxivə köçürüldü.');
  });

  testWidgets('a cancelled one is not', (WidgetTester tester) async {
    final _StubEditApi api = _StubEditApi();
    final TaskEditController controller = await _pump(tester, api: api);

    controller.setStatus(TaskEditStatus.cancel);
    await tester.pumpAndSettle();
    await _tapSave(tester);

    // The site files neither of the other two ends, and an archive full of
    // cancelled tasks is not an archive of anything.
    expect(api.status, TaskEditStatus.cancel);
    expect(api.archived, isFalse);
  });

  testWidgets('a partner task is not asked what it cannot store', (
    WidgetTester tester,
  ) async {
    await _pump(tester, source: TaskSource.partner);

    // `PartnerTaskUpdate` declares neither, and a field sent to a schema that
    // does not declare it is dropped in silence.
    expect(find.text('İşin növü'), findsNothing);
    expect(find.text('Seçilmiş şirkətə göstər'), findsNothing);

    // What it can store is still there.
    expect(find.text('İcra edən'), findsOneWidget);
    for (final String row in <String>['Qeyd', 'Status']) {
      await tester.dragUntilVisible(
        find.text(row),
        find.byType(ListView),
        const Offset(0, -120),
      );
      expect(find.text(row), findsOneWidget, reason: row);
    }
  });
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('Yadda saxla'),
    find.byType(ListView),
    const Offset(0, -120),
  );
  await tester.tap(find.text('Yadda saxla'));
  await tester.pumpAndSettle();
}

int _hiddenBoxes(WidgetTester tester) => tester
    .widgetList<NewTaskBox>(find.byType(NewTaskBox))
    .where((NewTaskBox box) => box.hidden)
    .length;

TaskItem _task(TaskSource source) => TaskItem(
  id: 12,
  source: source,
  company: 'Güvən Finans MMC',
  workType: 'Frontend',
  status: TaskStatus.inProgress,
  assignedBy: 'Məhəmməd Qasımov',
  assignedById: 4,
  assignedTo: 'Əli Balakişiyev',
  assignedToId: 7,
  workTypeId: 3,
  description: 'Sayt yenilənsin',
  dueDate: DateTime(2026, 9, 30),
);

Future<TaskEditController> _pump(
  WidgetTester tester, {
  _StubEditApi? api,
  TaskSource source = TaskSource.internal,
  ValueChanged<TaskEditOutcome>? onSaved,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final TaskItem task = _task(source);
  final TaskEditController controller = TaskEditController(
    _StubSession(),
    task,
    api: api ?? _StubEditApi(),
    options: _StubOptions(),
  );
  addTearDown(controller.dispose);

  // A `MaterialApp` rather than a bare `MediaQuery`: the description and the
  // note are `TextField`s, which will not build without
  // `MaterialLocalizations`, and in the app this panel is a route inside one.
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: 59, bottom: 34)),
          child: TaskEditPanel(
            session: SessionController(),
            task: task,
            onSaved: onSaved ?? (_) {},
            controller: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// A session that knows who it is and never touches the network.
class _StubSession extends SessionController {
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

class _StubEditApi extends TaskEditApi {
  _StubEditApi() : super(ApiClient(tokens: TokenStore()));

  /// The body of the one write this sheet made, or null when it made none.
  Map<String, Object?>? saved;
  TaskEditStatus? status;

  /// Whether the finished task's copy was filed under `Arxiv`.
  bool archived = false;

  @override
  Future<TaskEditSnapshot> load(TaskItem task) async => TaskEditSnapshot(
    assignedToId: 7,
    assignedToName: 'Əli Balakişiyev',
    workTypeId: 3,
    workTypeName: 'Frontend',
    description: 'Sayt yenilənsin',
    note: 'Ödəniş sonra həll olunacaq',
    dueDate: DateTime(2026, 9, 30),
    showToCompany: true,
  );

  @override
  Future<void> save({
    required TaskItem task,
    required int? myUserId,
    int? assignedTo,
    int? workTypeId,
    String? description,
    String? note,
    DateTime? dueDate,
    bool? showToCompany,
    int? viewableCompanyId,
  }) async {
    saved = <String, Object?>{
      'assigned_to': ?assignedTo,
      'work_type_id': ?workTypeId,
      'task_description': ?description,
      'notes': ?note,
      'due_date': ?dueDate,
      'is_company_viewable': ?showToCompany,
    };
  }

  @override
  Future<void> setStatus({
    required TaskItem task,
    required TaskEditStatus status,
    required int? myUserId,
  }) async {
    this.status = status;
  }

  @override
  Future<bool> archive({
    required TaskItem task,
    required int? myUserId,
  }) async {
    archived = true;
    return true;
  }
}

class _StubOptions extends TaskCreateApi {
  _StubOptions() : super(ApiClient(tokens: TokenStore()));

  @override
  Future<List<TaskOption>> employees(String companyCode) async =>
      const <TaskOption>[
        TaskOption(id: 7, name: 'Əli Balakişiyev'),
        TaskOption(id: 8, name: 'Nigar Həsənova'),
      ];

  @override
  Future<List<TaskOption>> workTypes(int companyId) async => const <TaskOption>[
    TaskOption(id: 3, name: 'Frontend'),
  ];

  @override
  Future<List<TaskOption>> partners(String companyCode) async =>
      const <TaskOption>[
        TaskOption(
          id: 17,
          name: 'Güvən Finans MMC',
          code: 'GUV26001',
          companyId: 51,
        ),
      ];

  @override
  Future<List<TaskOption>> parentCompanies(String companyCode) async =>
      const <TaskOption>[
        TaskOption(id: 51, name: 'Güvən Finans MMC', code: 'GUV26001'),
      ];
}
