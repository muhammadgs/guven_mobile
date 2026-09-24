import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/database/application/database_controller.dart';
import 'package:guven_mobile/src/features/database/data/database_api.dart';
import 'package:guven_mobile/src/features/database/domain/database_metric.dart';
import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_screen.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_tools.dart';

/// The tab as the user meets it: the ten figures written the design's way,
/// and the menu button growing into `Detallar` and taking the tab somewhere
/// else.
void main() {
  testWidgets('Əsas panel shows the ten figures, written the design\'s way', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _answer);

    expect(find.text('Baza'), findsOneWidget);
    expect(find.text('Əsas panel'), findsOneWidget);
    for (final DatabaseMetric metric in DatabaseMetric.values) {
      expect(find.text(metric.label), findsOneWidget, reason: metric.label);
    }

    expect(find.text('475'), findsOneWidget);
    expect(find.text('7,224'), findsOneWidget);
    expect(find.text('7,204'), findsOneWidget);
    expect(find.text('730'), findsOneWidget);
    expect(find.text('1,455,475.61 ₼'), findsOneWidget);
    expect(find.text('1,105,035.18 ₼'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bridge that answers nothing says so above empty rows', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      (http.Request request) async => http.Response(
        jsonEncode(<String, Object?>{'detail': 'Baza tapılmadı'}),
        404,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    );

    expect(find.text('Baza tapılmadı'), findsOneWidget);
    expect(find.text('Yenidən cəhd et'), findsOneWidget);
    // Ten rows, every one of them unknown rather than zero.
    expect(find.text('—'), findsNWidgets(DatabaseMetric.values.length));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the menu takes the tab to the page chosen', (
    WidgetTester tester,
  ) async {
    final DatabaseController controller = await _pump(tester, _answer);

    await tester.tap(find.byType(GlassToolButton));
    await tester.pumpAndSettle();
    expect(find.text('Detallar'), findsOneWidget);

    await tester.tap(find.text('Əməliyyatlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satışlar'));
    await tester.pumpAndSettle();

    expect(controller.section, DatabaseSection.sales);
    // The menu has gone home, and the page says where the tab is now.
    expect(find.text('Detallar'), findsNothing);
    expect(find.text('Satışlar'), findsOneWidget);
    expect(find.text('Bu bölmə hazırlanır.'), findsOneWidget);

    // And back again, without going back to the network.
    await tester.tap(find.byType(GlassToolButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Əsas panel'));
    await tester.pumpAndSettle();

    expect(controller.section, DatabaseSection.overview);
    expect(find.text('7,224'), findsOneWidget);
  });
}

Future<DatabaseController> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final SessionController session = SessionController();
  addTearDown(session.dispose);
  final DatabaseController controller = DatabaseController(
    session,
    api: DatabaseApi(
      ApiClient(tokens: TokenStore(), httpClient: MockClient(handler)),
    ),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        type: MaterialType.transparency,
        child: DatabaseScreen(
          bottomReserve: 110,
          active: true,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<http.Response> _answer(http.Request request) async {
  final String path = request.url.path;
  final Object body = path.endsWith('/onec-data/summary/')
      ? <String, Object?>{
          'counts': <String, Object?>{
            'sales': 7204,
            'stock': 730,
            'team': 61,
            'creditors': 61,
            'debitors': 61,
          },
          'totals': <String, Object?>{
            'sales_amount': '1455475.61',
            'debitor_debt': '905035.18',
            'manager_debet': 200000,
          },
        }
      : <String, Object?>{
          'data': <Object?>[],
          'total': path.endsWith('/orders/')
              ? 7224
              : path.endsWith('/customers/')
              ? 312
              : 475,
        };
  return http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
