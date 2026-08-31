import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/auth/domain/auth_user.dart';
import 'package:guven_mobile/src/features/tasks/application/new_task_controller.dart';
import 'package:guven_mobile/src/features/tasks/data/task_create_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_box.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_form.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_panel.dart';
import 'package:guven_mobile/src/shared/glass/app_glass.dart';

/// The chooser and the form are one surface, and the form is the tallest thing
/// this app draws. Two questions are worth answering without a phone: does the
/// chooser actually offer the three kinds, and does the form each of them opens
/// lay out inside the sheet rather than overflowing it.
///
/// The lists behind the fields are stubbed. The point here is the layout and
/// the wiring; what the backend answers with is [TaskCreateApi]'s business.
void main() {
  testWidgets('the chooser offers the three kinds', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Yeni'), findsOneWidget);
    for (final NewTaskKind kind in NewTaskKind.values) {
      expect(find.text(kind.label), findsOneWidget);
    }
  });

  for (final NewTaskKind kind in NewTaskKind.values) {
    testWidgets('${kind.label} opens a form that fits the sheet', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text(kind.label));
      await tester.pumpAndSettle();

      // The title says which kind is being filled in…
      expect(find.text(kind.sheetTitle), findsOneWidget);

      // …and the fields are the ones that kind actually asks for. Only the
      // internal form has an executor of ours, and only it can be hidden from
      // the company the work is for.
      expect(
        find.text('İcra edən'),
        kind.hasOwnExecutor ? findsOneWidget : findsNothing,
      );
      expect(find.text(kind.otherWorkerLabel), findsOneWidget);
      expect(find.text('İşin növü'), findsOneWidget);
      expect(find.text('Şöbə'), findsOneWidget);

      // The rest of the form is below the fold — the sheet scrolls, exactly as
      // the design's second screen shows it — so it has to be scrolled to
      // rather than merely looked for.
      for (final String below in <String>[
        'Son müddət',
        // Only the internal form can hide a task from the company it is for;
        // on the other two that company has to see it or it could not do it.
        if (kind.hasVisibilityToggle) 'Seçilmiş şirkətə göstər',
        'Tapşırıq açıqlaması',
        'Səs qeydi',
        'Fayllar',
        'Əlavə edin',
      ]) {
        await tester.dragUntilVisible(
          find.text(below),
          find.byType(ListView),
          const Offset(0, -120),
        );
        expect(find.text(below), findsOneWidget);
      }

      if (!kind.hasVisibilityToggle) {
        expect(find.text('Seçilmiş şirkətə göstər'), findsNothing);
      }

      // `pumpAndSettle` would already have thrown on an overflow, but say so
      // in the test rather than leaving it to a stray red banner.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a company chosen on the internal form loads its people', (
    WidgetTester tester,
  ) async {
    final _StubApi api = _StubApi();
    await _pump(tester, api: api);

    await tester.tap(find.text('Daxili'));
    await tester.pumpAndSettle();

    // Our own company heads the list and opens selected — the internal form is
    // for our own work most of the time.
    expect(find.text('Güvən Finans MMC'), findsOneWidget);
    expect(api.employeesFor, contains('GUV26001'));

    await tester.tap(find.text('Güvən Finans MMC'));
    await tester.pumpAndSettle();
    expect(find.text('Alt Şirkət'), findsOneWidget);

    await tester.tap(find.text('Alt Şirkət'));
    await tester.pumpAndSettle();

    // The other company's people are its own, not ours.
    expect(api.employeesFor, contains('ALT26002'));
  });

  testWidgets(
    'the boxes are flat while the sheet flies and glass once it lands',
    (WidgetTester tester) async {
      await _pump(tester);

      await tester.tap(find.text('Daxili'));
      // Mid-flight. The contents are inside an `Opacity` here, and a lens under
      // one samples that empty layer and renders black — so there must not be a
      // single one in the form yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_boxLenses(tester), isEmpty);

      await tester.pumpAndSettle();
      expect(
        _boxLenses(tester),
        isNotEmpty,
        reason: 'once it has landed every box is a real lens',
      );
    },
  );

  testWidgets('the field whose list is open steps out of its own way', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Daxili'));
    await tester.pumpAndSettle();

    expect(_hiddenBoxes(tester), 0);

    await tester.tap(find.text('Güvən Finans MMC'));
    await tester.pumpAndSettle();

    // The panel *is* that box's glass now, so the box underneath is not drawn
    // — two lenses in the same place would read as a double image.
    expect(_hiddenBoxes(tester), 1);

    await tester.tap(find.text('Alt Şirkət'));
    await tester.pumpAndSettle();
    expect(_hiddenBoxes(tester), 0);
  });

  testWidgets('the form refuses to send until it has been filled in', (
    WidgetTester tester,
  ) async {
    final NewTaskController controller = _controller(_StubApi());
    await _pump(tester, controller: controller);

    await tester.tap(find.text('Şirkət'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Əlavə edin'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.tap(find.text('Əlavə edin'));
    await tester.pumpAndSettle();

    // The company picker on this kind opens empty on purpose, so this is the
    // first thing missing.
    expect(find.text('Şirkət seçin.'), findsOneWidget);
  });
}

/// The lenses inside the form's boxes — not the sheet's own, which is a
/// sibling of the form rather than inside it.
Iterable<AppGlassSurface> _boxLenses(WidgetTester tester) =>
    tester.widgetList<AppGlassSurface>(
      find.descendant(
        of: find.byType(NewTaskForm),
        matching: find.byType(AppGlassSurface),
      ),
    );

int _hiddenBoxes(WidgetTester tester) => tester
    .widgetList<NewTaskBox>(find.byType(NewTaskBox))
    .where((NewTaskBox box) => box.hidden)
    .length;

Future<void> _pump(
  WidgetTester tester, {
  _StubApi? api,
  NewTaskController? controller,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final NewTaskController owned = controller ?? _controller(api ?? _StubApi());
  addTearDown(owned.dispose);

  // A `MaterialApp` rather than a bare `MediaQuery`: the description field is
  // a `TextField`, which will not build without `MaterialLocalizations`, and
  // in the app this panel is a route inside one. It also hands the panel the
  // screen's own tight constraints — anything looser would let the panel's
  // `Stack` shrink to nothing and stop hit-testing.
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: 59, bottom: 34)),
          child: NewTaskPanel(
            session: SessionController(),
            onCreated: (_) {},
            controller: owned,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NewTaskController _controller(_StubApi api) =>
    NewTaskController(_StubSession(), api: api);

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

class _StubApi extends TaskCreateApi {
  _StubApi() : super(ApiClient(tokens: TokenStore()));

  /// Every company code whose people have been asked for, so the cascade can
  /// be checked rather than assumed.
  final List<String> employeesFor = <String>[];

  @override
  Future<List<TaskOption>> subCompanies(String companyCode) async =>
      const <TaskOption>[
        TaskOption(id: 62, name: 'Alt Şirkət', code: 'ALT26002'),
      ];

  @override
  Future<List<TaskOption>> parentCompanies(String companyCode) async =>
      const <TaskOption>[];

  @override
  Future<List<TaskOption>> partners(String companyCode) async =>
      const <TaskOption>[
        TaskOption(id: 17, name: 'Lukoil', code: 'LUK25001', companyId: 26),
      ];

  @override
  Future<List<TaskOption>> employees(String companyCode) async {
    employeesFor.add(companyCode);
    return const <TaskOption>[TaskOption(id: 7, name: 'Əli Balakişiyev')];
  }

  @override
  Future<List<TaskOption>> departments(String companyCode) async =>
      const <TaskOption>[TaskOption(id: 3, name: 'Mühasibatlıq')];

  @override
  Future<List<TaskOption>> workTypes(int companyId) async => const <TaskOption>[
    TaskOption(id: 180, name: 'Texniki dəstək'),
  ];
}
