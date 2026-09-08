import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_edit.dart';

/// Every glyph the two task sheets ask for, loaded from the bundle.
///
/// A path that is not in `pubspec.yaml`, or an SVG this renderer cannot parse,
/// fails at the moment the sheet is opened on a device and nowhere earlier —
/// which is a bad place to find out. The lists below are the only places these
/// paths are written, so a renamed file breaks here first.
void main() {
  final List<String> icons = <String>[
    for (final NewTaskKind kind in NewTaskKind.values) kind.icon,
    for (final NewTaskField field in NewTaskField.values) field.icon,
    'assets/images/icons/new_task_icons/son_muddet.svg',
    'assets/images/icons/new_task_icons/secilmis_sirkete_goster.svg',
    'assets/images/icons/new_task_icons/aciqlama.svg',
    'assets/images/icons/new_task_icons/ses_qeydi.svg',
    'assets/images/icons/new_task_icons/fayl.svg',
    // `Redaktə` wears the new-task sheet's glyphs everywhere the two forms ask
    // the same question; these two are the rows only it has.
    for (final TaskEditField field in TaskEditField.values) field.icon,
    kTaskEditNoteIcon,
    kTaskEditStatusIcon,
  ];

  for (final String icon in icons) {
    testWidgets('$icon loads and draws', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }
}
