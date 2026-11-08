import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/application/new_task_controller.dart';
import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/presentation/new_task_metrics.dart';
import 'package:guven_mobile/src/features/tasks/presentation/widgets/new_task_picker.dart';

/// A field's list on `Yeni tapşırıq` and `Redaktə` searches by name once it
/// is long (2026-11-08, the user): typing narrows it the way the `Baza`
/// filter's search does, and a short list stays a plain list.
void main() {
  const List<String> people = <String>[
    'Adil Musayev',
    'Cefer Sadiqov',
    'Elvin Memmedov',
    'Meherrem Teymurov',
    'Sadıq Cəfərov',
    'Server Resulov',
    'test1 test1',
  ];

  testWidgets('a long list narrows to what is typed', (
    WidgetTester tester,
  ) async {
    TaskOption? picked;
    await _pump(tester, people, onPick: (TaskOption o) => picked = o);

    expect(find.text('Adla axtar'), findsOneWidget);
    expect(find.text('Adil Musayev'), findsOneWidget);

    // Dotless `ı` and `ə` typed as a plain keyboard types them.
    await tester.enterText(find.byType(TextField), 'sadiq');
    await tester.pump();

    expect(find.text('Cefer Sadiqov'), findsOneWidget);
    expect(find.text('Sadıq Cəfərov'), findsOneWidget);
    expect(find.text('Adil Musayev'), findsNothing);

    await tester.tap(find.text('Sadıq Cəfərov'));
    expect(picked?.name, 'Sadıq Cəfərov');

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Heç nə tapılmadı'), findsOneWidget);

    // The cross empties it, and the whole list is back.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.text('Adil Musayev'), findsOneWidget);
  });

  testWidgets('a short list has no search field', (WidgetTester tester) async {
    await _pump(tester, people.take(3).toList());

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Adil Musayev'), findsOneWidget);
  });

  testWidgets('the list keeps above the keyboard', (WidgetTester tester) async {
    await _pump(tester, people, keyboard: 330);

    final Rect panel = tester.getRect(find.byType(DarkPanelSurface));
    expect(panel.bottom, lessThanOrEqualTo(852 - 330));
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<String> names, {
  ValueChanged<TaskOption>? onPick,
  double keyboard = 0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(393, 852),
        padding: const EdgeInsets.only(top: 59, bottom: 34),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: MaterialApp(
        home: Material(
          child: Builder(
            builder: (BuildContext context) {
              final NewTaskMetrics metrics = NewTaskMetrics.of(
                context,
                button: const Rect.fromLTWH(76, 190, 42, 42),
                menuRows: 3,
              );
              return Stack(
                children: <Widget>[
                  NewTaskPickerPanel(
                    metrics: metrics,
                    anchor: const Rect.fromLTWH(24, 400, 345, 46),
                    flight: const AlwaysStoppedAnimation<double>(1),
                    emptyMessage: 'İşçi tapılmadı',
                    list: OptionList(
                      options: <TaskOption>[
                        for (int i = 0; i < names.length; i++)
                          TaskOption(id: i, name: names[i]),
                      ],
                    ),
                    chosen: null,
                    onPick: onPick ?? (_) {},
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
