import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/widgets/database_menu.dart';

/// `Detallar` end to end, at rest: it draws, every heading opens exactly its
/// own pages, and a page chosen is the page reported.
///
/// Worth pumping rather than reasoning about, for the filter's reason: every
/// label here is laid out inside a lens, in an `OverflowBox` at the panel's
/// resting size, in a `Stack` positioned in global coordinates. An overflow or
/// a lens that throws would never show up in the arithmetic next door.
void main() {
  testWidgets('the menu offers Əsas panel and the five headings', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Detallar'), findsOneWidget);
    expect(find.text('Əsas panel'), findsOneWidget);
    for (final DatabaseGroup group in DatabaseGroup.values) {
      expect(find.text(group.title), findsOneWidget);
    }
    // Pages only appear under the heading that was opened.
    expect(find.text('Satışlar'), findsNothing);
  });

  for (final DatabaseGroup group in DatabaseGroup.values) {
    testWidgets('${group.title} opens its own pages and no others', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text(group.title));
      await tester.pumpAndSettle();

      for (final DatabaseSection section in DatabaseSection.values) {
        if (section.group == null) continue;
        expect(
          find.text(section.title),
          section.group == group ? findsOneWidget : findsNothing,
          reason: section.title,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching headings lets the first panel out first', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Əməliyyatlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kataloqlar'));
    await tester.pumpAndSettle();

    // Two panels at once would be two lenses refracting each other.
    expect(find.text('Satışlar'), findsNothing);
    expect(find.text('Ölçü Vahidləri'), findsOneWidget);

    // And the same heading again shuts it.
    await tester.tap(find.text('Kataloqlar'));
    await tester.pumpAndSettle();
    expect(find.text('Ölçü Vahidləri'), findsNothing);
  });

  testWidgets('a page chosen is the page reported', (
    WidgetTester tester,
  ) async {
    final List<DatabaseSection> chosen = <DatabaseSection>[];
    await _pump(tester, onSelect: chosen.add);

    await tester.tap(find.text('Maliyyə'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borc Bölgüsü'));
    await tester.pumpAndSettle();

    expect(chosen, <DatabaseSection>[DatabaseSection.debtAllocation]);
  });

  testWidgets('Əsas panel is a page of its own, with nothing under it', (
    WidgetTester tester,
  ) async {
    final List<DatabaseSection> chosen = <DatabaseSection>[];
    await _pump(tester, current: DatabaseSection.stock, onSelect: chosen.add);

    await tester.tap(find.text('Əsas panel'));
    await tester.pumpAndSettle();

    expect(chosen, <DatabaseSection>[DatabaseSection.overview]);
  });

  testWidgets('the longest name fits its panel', (WidgetTester tester) async {
    await _pump(tester);

    await tester.tap(find.text('Hesabatlar'));
    await tester.pumpAndSettle();

    // Set smaller if it has to be, never cut and never overflowing.
    expect(find.text('Menecer Statistikası'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Pumps the menu at rest — no morph, which is the state every assertion here
/// is about. The flight itself is `glass_morph.dart`'s, and covered there.
Future<void> _pump(
  WidgetTester tester, {
  DatabaseSection current = DatabaseSection.overview,
  ValueChanged<DatabaseSection>? onSelect,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: Size(402, 874),
        padding: EdgeInsets.only(top: 62, bottom: 34),
      ),
      child: MaterialApp(
        // No `Material` here on purpose: the route is pushed as a sibling of
        // the shell, so the menu has to bring its own.
        home: DatabaseMenuPanel(current: current, onSelect: onSelect ?? (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
