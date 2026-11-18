import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/shell/data/nav_layout_store.dart';
import 'package:guven_mobile/src/features/shell/domain/shell_destination.dart';
import 'package:guven_mobile/src/features/shell/presentation/main_shell.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/guven_glass_bottom_bar.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/more_menu.dart';
import 'package:guven_mobile/src/features/shell/presentation/widgets/native_ios_tab_bar.dart';

void main() {
  tearDown(PlatformVersion.reset);

  test('Android never gets the native bar', () {
    expect(defaultTargetPlatform, TargetPlatform.android);
    PlatformVersion.debugOverrideVersions(iosVersion: 27);
    expect(useNativeIosTabBar(), isFalse);
  });

  test('an iPhone below iOS 26 keeps our own bar', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    PlatformVersion.debugOverrideVersions(iosVersion: 18);
    expect(useNativeIosTabBar(), isFalse);
  });

  testWidgets('left to ask the phone, a test phone (Android) gets our bar', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, native: null);
    expect(find.byType(GuvenGlassBottomBar), findsOneWidget);
    expect(find.byType(NativeIosTabBar), findsNothing);
  });

  testWidgets('the native bar gets the same five cells and ends on our line', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, native: true);
    expect(find.byType(GuvenGlassBottomBar), findsNothing);

    final NativeIosTabBar bar = _bar(tester);
    final List<ShellDestination> row = ShellNavLayout.defaults.bar;
    expect(bar.labels, <String>[
      row[0].title,
      row[1].title,
      kMenuTitle,
      row[2].title,
      row[3].title,
    ]);
    expect(bar.icons, <String>[
      row[0].icon,
      row[1].icon,
      kMenuIcon,
      row[2].icon,
      row[3].icon,
    ]);
    expect(bar.selectedIndex, _homeCell);
    expect(bar.menuOpen, isFalse);

    final BuildContext context = tester.element(find.byType(MainShell));
    expect(
      tester.getRect(find.byType(NativeIosTabBar)).bottom,
      closeTo(MainShell.barRect(context).bottom, 0.01),
    );
  });

  testWidgets('a tap on the native bar changes the page', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, native: true);
    final int cell = ShellNavLayout.defaults.cellOfDestination(
      ShellDestination.tasks,
    )!;
    _bar(tester).onSelected(cell);
    await tester.pumpAndSettle();
    expect(_bar(tester).selectedIndex, cell);
    expect(find.text('page:tasks'), findsOneWidget);
  });

  testWidgets('Daha çox on the native bar opens the fan and shuts it again', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, native: true);

    _bar(tester).onSelected(ShellNavLayout.menuCell);
    await tester.pumpAndSettle();
    expect(_bar(tester).menuOpen, isTrue);
    expect(_bar(tester).selectedIndex, ShellNavLayout.menuCell);
    expect(find.byType(MoreMenuDisc), findsWidgets);

    // The second tap on the selected cell is reported too, and shuts it.
    _bar(tester).onSelected(ShellNavLayout.menuCell);
    await tester.pumpAndSettle();
    expect(_bar(tester).menuOpen, isFalse);
    expect(_bar(tester).selectedIndex, _homeCell);
    expect(find.byType(MoreMenuDisc), findsNothing);
  });
}

/// The shell opens on the home page, wherever its button is.
final int _homeCell = ShellNavLayout.defaults.cellOfDestination(
  ShellDestination.home,
)!;

NativeIosTabBar _bar(WidgetTester tester) =>
    tester.widget<NativeIosTabBar>(find.byType(NativeIosTabBar));

Future<void> _pumpShell(WidgetTester tester, {required bool? native}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        store: MemoryNavLayoutStore(null),
        nativeTabBar: native,
        pageBuilder: (ShellDestination page, double reserve) =>
            Center(child: Text('page:${page.name}')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The package holds back the first native bar of a run for half a second
  // (its `PlatformViewGuard`); let that timer run out inside the test.
  await tester.pump(const Duration(seconds: 1));
}
