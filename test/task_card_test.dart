import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_scope.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_card.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_card_layout.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/task_scope_bar.dart';

const String _description =
    'Əməkdaşların ümumi siyahısı ancaq səlahiyyəti olan şəxslər görə '
    'bilməsin. lazım olan əmokdaş filtirə yazanda görsənə bilər feature '
    'kimi əlavə olunsun ki, siyahı hamıya açıq qalmasın.';

TaskItem _task({TaskStatus status = TaskStatus.pendingApproval}) {
  return TaskItem(
    id: 1,
    source: TaskSource.internal,
    company: 'Güvən Finans MMC',
    workType: 'Frontend Developer',
    status: status,
    assignedBy: 'Əli Balakişiyev',
    assignedTo: 'Məhəmməd Qasımov',
    assignedToId: 7,
    description: _description,
    createdAt: DateTime(2026, 8, 25, 18, 15),
    dueDate: DateTime(2026, 8, 28),
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Material(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 390, child: BackdropGroup(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('a shut card shows the design\'s two columns', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        TaskCard(
          task: _task(),
          mine: true,
          busy: false,
          attachments: const [],
          onAction: (_) {},
          onOpened: () {},
        ),
      ),
    );

    expect(find.text('Güvən Finans MMC'), findsOneWidget);
    expect(find.text('Frontend Developer'), findsOneWidget);
    expect(find.text('2026-08-25'), findsOneWidget);
    expect(find.text('18:15'), findsOneWidget);
    // The executor is the signed-in user, so the design puts their name in
    // bold and gives the card its two buttons.
    expect(find.text('Təsdiq et'), findsOneWidget);
    expect(find.text('İmtina et'), findsOneWidget);
    // Shut, the deadline is laid out — the open height is measured from it
    // every frame — but drawn at nothing.
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.text('Son müddət:'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      0,
    );

    final Rect title = tester.getRect(find.text('Güvən Finans MMC'));
    final Rect stamp = tester.getRect(find.text('2026-08-25'));
    // Two columns: the timestamp sits to the right of the company name, on the
    // same line rather than above it.
    expect(stamp.left, greaterThan(title.right));

    // And the description keeps to the right-hand column, beside the buttons
    // rather than under them.
    final Rect description = tester.getRect(find.text(_description).first);
    final Rect approve = tester.getRect(find.text('Təsdiq et'));
    expect(description.left, greaterThan(approve.right));
  });

  testWidgets('opening a card moves its parts and grows it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool opened = false;
    await tester.pumpWidget(
      _host(
        TaskCard(
          task: _task(),
          mine: true,
          busy: false,
          attachments: const [],
          onAction: (_) {},
          onOpened: () => opened = true,
        ),
      ),
    );

    final Finder card = find.byType(TaskCardLayout);
    final double shutHeight = tester.getSize(card).height;

    await tester.tap(find.text('Güvən Finans MMC'));
    // Mid-flight: the layout is a blend of the two, so nothing has jumped.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final double midHeight = tester.getSize(card).height;
    expect(midHeight, greaterThan(shutHeight));

    await tester.pumpAndSettle();
    final double openHeight = tester.getSize(card).height;
    expect(openHeight, greaterThan(midHeight));
    expect(opened, isTrue);

    // Open, the timestamp has moved above the company name and centred.
    final Rect title = tester.getRect(find.text('Güvən Finans MMC'));
    final Rect stamp = tester.getRect(find.text('2026-08-25'));
    expect(stamp.bottom, lessThanOrEqualTo(title.top + 1));

    // And the columns only an opened card has room for are there.
    expect(find.text('Son müddət:'), findsOneWidget);
    expect(find.text('2026-08-28'), findsOneWidget);

    // Shutting it again runs the same journey backwards.
    await tester.tap(find.text('Güvən Finans MMC'));
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, closeTo(shutHeight, 0.5));
  });

  testWidgets('a task somebody else is carrying out shows its status instead', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        TaskCard(
          task: _task(status: TaskStatus.overdue),
          mine: false,
          busy: false,
          attachments: const [],
          onAction: (_) {},
          onOpened: () {},
        ),
      ),
    );

    expect(find.text(TaskStatus.overdue.label), findsOneWidget);
    expect(find.text('Başla'), findsNothing);
  });

  testWidgets('the scope bar selects the cell that was tapped', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    TaskScope? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 350,
              child: TaskScopeBar(
                scopes: TaskScope.values,
                selected: TaskScope.internal,
                onSelected: (TaskScope scope) => picked = scope,
                height: 40,
                iconSize: 15,
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Every cell is on screen: the rail packs them to the bar's width rather
    // than letting the longest label push the last one off the end.
    for (final TaskScope scope in TaskScope.values) {
      expect(find.text(scope.label), findsOneWidget);
    }

    // The cells sit under an `IgnorePointer` so the marker's own gesture
    // detector owns every touch on the bar; the tap still lands on the cell it
    // was aimed at.
    await tester.tap(find.text('Arxiv'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, TaskScope.archive);
  });
}
