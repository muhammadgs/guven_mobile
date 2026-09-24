import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/database/domain/database_metric.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_menu.dart';

/// Every glyph the `Baza` tab asks for, loaded from the bundle.
///
/// A path missing from `pubspec.yaml` — or spelled with the wrong case, which
/// a Windows build forgives and a phone does not (`Kreditor.svg`,
/// `Debitor.svg`) — fails at the moment the tab is opened on a device and
/// nowhere earlier.
void main() {
  final List<String> icons = <String>[
    for (final DatabaseMetric metric in DatabaseMetric.values) metric.icon,
    kDatabaseMenuIcon,
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
