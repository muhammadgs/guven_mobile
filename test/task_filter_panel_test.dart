import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/tasks/application/tasks_controller.dart';
import 'package:guven_mobile/src/features/tasks/data/tasks_api.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_filter_panel.dart';

/// The panel end to end: it draws, a column opens its values, ticking one
/// narrows the list, and `Hamısı` puts it back.
///
/// Worth pumping rather than reasoning about, because everything visual here
/// is laid out inside a morphing lens — an `OverflowBox` at the panel's
/// resting size, inside a glass surface, inside a `Stack` positioned in global
/// coordinates. A layout that overflows or a lens that throws would never show
/// up in the arithmetic tests next door.
void main() {
  testWidgets('the columns are the ones the rows carry', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Şirkət'), findsOneWidget);
    expect(find.text('Şöbə'), findsOneWidget);
    expect(find.text('İcra edən'), findsOneWidget);

    // No row in the fixture has one, so the column is not offered.
    expect(find.text('Son müddət'), findsNothing);
  });

  testWidgets('a column opens its values, and one of them narrows the list', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    await tester.tap(find.text('Şöbə'));
    await tester.pumpAndSettle();

    expect(find.text('Hamısı'), findsOneWidget);
    expect(find.text('AUDİT'), findsOneWidget);
    expect(find.text('İKT'), findsOneWidget);

    await tester.tap(find.text('AUDİT'));
    await tester.pumpAndSettle();

    expect(tasks.visibleTasks.length, 1);
    expect(tasks.visibleTasks.single.department, 'AUDİT');
    expect(tasks.filter.activeFieldCount, 1);

    // And the way back out is on the same panel.
    await tester.tap(find.text('Hamısı'));
    await tester.pumpAndSettle();

    expect(tasks.filter.isEmpty, isTrue);
    expect(tasks.visibleTasks.length, 3);
  });

  testWidgets('the values of one column narrow the options of another', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    await tester.tap(find.text('Şirkət'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ay Ulduz ASC'));
    await tester.pumpAndSettle();

    // Switching columns lets the first panel out before the second comes in —
    // two lenses at once would refract each other.
    await tester.tap(find.text('Şöbə'));
    await tester.pumpAndSettle();

    expect(find.text('Mühasibatlıq'), findsOneWidget);
    expect(
      find.text('AUDİT'),
      findsNothing,
      reason: 'no Ay Ulduz row is in AUDİT, so that value is unreachable',
    );
  });

  testWidgets('the reset control appears once something is selected', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    expect(find.text('Sıfırla'), findsNothing);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İcra edilir'));
    await tester.pumpAndSettle();

    // In the title bar, so the panel does not grow a row taller under the
    // finger that just ticked something.
    expect(find.text('Sıfırla'), findsOneWidget);

    await tester.tap(find.text('Sıfırla'));
    await tester.pumpAndSettle();

    expect(tasks.filter.isEmpty, isTrue);
    expect(find.text('Sıfırla'), findsNothing);
  });
}

/// Pumps the panel at rest — no morph, which is the state every assertion
/// here is about. The flight itself is covered by `glass_morph_test.dart`.
Future<void> _pump(WidgetTester tester, TasksController tasks) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: Size(393, 852),
        padding: EdgeInsets.only(top: 59, bottom: 34),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        // No `Material` here on purpose. This route is pushed as a sibling
        // of the shell, so the panel has to bring its own or every label
        // comes out in the framework's yellow debug style.
        child: MaterialApp(home: TaskFilterPanel(controller: tasks)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A controller holding three rows that overlap in some columns and not
/// others — the same shape as the domain tests use, but arriving the way the
/// screen's rows really do, through `/tasks/detailed`.
Future<TasksController> _loaded() async {
  final MockClient transport = MockClient((http.Request request) async {
    return http.Response(
      jsonEncode(<String, Object?>{'tasks': _rows}),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });

  final TasksController tasks = TasksController(
    SessionController(),
    api: TasksApi(ApiClient(tokens: TokenStore(), httpClient: transport)),
  );
  await tasks.load();
  return tasks;
}

const List<Map<String, Object?>> _rows = <Map<String, Object?>>[
  <String, Object?>{
    'id': 1,
    'company_name': 'Rəqəm MMC',
    'work_type_name': 'Audit',
    'department_name': 'AUDİT',
    'creator_name': 'Elmar Əzizov',
    'assigned_to_name': 'Nigar Həsənli',
    'status': 'in_progress',
    'created_at': '2026-08-25T14:15:00',
  },
  <String, Object?>{
    'id': 2,
    'company_name': 'Rəqəm MMC',
    'work_type_name': 'Şəbəkə quraşdırma',
    'department_name': 'İKT',
    'creator_name': 'Elmar Əzizov',
    'assigned_to_name': 'Tural Quliyev',
    'status': 'pending',
    'created_at': '2026-08-25T05:05:00',
  },
  <String, Object?>{
    'id': 3,
    'company_name': 'Ay Ulduz ASC',
    'work_type_name': 'Hesabat',
    'department_name': 'Mühasibatlıq',
    'creator_name': 'Səbinə Məmmədova',
    'assigned_to_name': 'Nigar Həsənli',
    'status': 'in_progress',
    'created_at': '2026-08-24T07:00:00',
  },
];
