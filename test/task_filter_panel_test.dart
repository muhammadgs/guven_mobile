import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_filter_panel.dart';
import 'package:guven_mobile/src/features/tasks/application/task_filter_source.dart';
import 'package:guven_mobile/src/features/tasks/application/tasks_controller.dart';
import 'package:guven_mobile/src/features/tasks/data/tasks_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_filter.dart';

/// The task filter end to end, on the `Baza` filter's panel — the user's
/// one-to-one rule (2026-11-08): it draws, a column turns the same pane into
/// its values, typing narrows them, ticking one narrows the list, the dates
/// take a span of days, and `Hamısı` puts it back.
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

  testWidgets('typing narrows the values, letters folded the Baza way', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    await tester.tap(find.text('İşin növü'));
    await tester.pumpAndSettle();
    expect(find.text('Audit'), findsOneWidget);
    expect(find.text('Hesabat'), findsOneWidget);

    // No `ə` or `ş` on the keyboard: `sebeke` still finds `Şəbəkə`.
    await tester.enterText(find.byType(TextField), 'sebeke');
    await tester.pumpAndSettle();

    expect(find.text('Şəbəkə quraşdırma'), findsOneWidget);
    expect(find.text('Audit'), findsNothing);
    expect(find.text('Hesabat'), findsNothing);
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

    // Back to the columns on the same pane, then the next column.
    await tester.tap(find.bySemanticsLabel('Geri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şöbə'));
    await tester.pumpAndSettle();

    expect(find.text('Mühasibatlıq'), findsOneWidget);
    expect(
      find.text('AUDİT'),
      findsNothing,
      reason: 'no Ay Ulduz row is in AUDİT, so that value is unreachable',
    );
  });

  testWidgets('a date column takes a span of days, with the days under it', (
    WidgetTester tester,
  ) async {
    final TasksController tasks = await _loaded();
    await _pump(tester, tasks);

    await tester.tap(find.text('Tarix'));
    await tester.pumpAndSettle();

    expect(find.text('Min tarix'), findsOneWidget);
    expect(find.text('Maks tarix'), findsOneWidget);
    // The days, newest first, written the way the fields write them.
    expect(find.text('25.08.2026'), findsOneWidget);
    expect(find.text('24.08.2026'), findsOneWidget);

    // Digits only: the points come by themselves.
    await tester.enterText(find.byType(TextField).first, '25082026');
    await tester.pump();
    expect(find.text('25.08.2026'), findsWidgets);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(tasks.visibleTasks.length, 2);
    expect(tasks.filter.activeFieldCount, 1);

    // A day ticked lets go of the span.
    await tester.tap(find.text('24.08.2026'));
    await tester.pumpAndSettle();
    expect(tasks.filter.rangeOf(TaskFilterField.date), FilterRange.any);
    expect(tasks.visibleTasks.single.id, 3);
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
    await tester.tap(find.bySemanticsLabel('Geri'));
    await tester.pumpAndSettle();

    // In the title's line, so the panel does not grow a row taller under the
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
  final TaskFilterSource source = TaskFilterSource(tasks);
  addTearDown(source.dispose);
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
        child: MaterialApp(
          home: DatabaseFilterPanel(
            source: source,
            origin: const Offset(22, 190),
          ),
        ),
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
