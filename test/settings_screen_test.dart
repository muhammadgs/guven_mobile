import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/settings/presentation/settings_metrics.dart';
import 'package:guven_mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:guven_mobile/src/features/settings/presentation/widgets/settings_pill.dart';
import 'package:guven_mobile/src/features/shell/presentation/main_shell.dart';

/// `Tənzimləmələr` is laid out by [SettingsMetrics] — every block hangs off
/// the measured bottom of the one above — so whether anything can collide is
/// a question of arithmetic, answered here across the phones the app ships
/// to; and the two levels, Back and `Çıxış edin` are driven on a real tree.
void main() {
  const List<_Device> devices = <_Device>[
    _Device('iPhone 16 Pro', Size(402, 874), EdgeInsets.only(top: 62, bottom: 34)),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    _Device('S23 Ultra gesture', Size(384, 824), EdgeInsets.only(top: 32, bottom: 24)),
    _Device('S23 Ultra 3-button', Size(384, 824), EdgeInsets.only(top: 32, bottom: 48)),
    _Device('S23 gesture', Size(360, 780), EdgeInsets.only(top: 30, bottom: 24)),
    _Device('S23 3-button', Size(360, 780), EdgeInsets.only(top: 30, bottom: 48)),
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('tall 21:9', Size(360, 900), EdgeInsets.only(top: 40, bottom: 24)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  for (final _Device device in devices) {
    for (final double fontScale in <double>[1.0, 1.2]) {
      testWidgets('${device.name} @ ${fontScale}x — nothing collides',
          (WidgetTester tester) async {
        late SettingsMetrics m;
        late Rect bar;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: device.size,
              padding: device.padding,
              textScaler: TextScaler.linear(fontScale),
            ),
            child: Builder(
              builder: (BuildContext context) {
                m = SettingsMetrics.of(context);
                bar = MainShell.barRect(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(m.titleTop, greaterThan(device.padding.top),
            reason: 'the title starts below the status bar');
        expect(m.categoriesTop, greaterThan(m.titleBottom),
            reason: 'the category pills clear the title');
        expect(m.subtitleTop, greaterThan(m.titleBottom),
            reason: 'the category name clears the title');
        expect(m.optionsTop, greaterThan(m.subtitleBottom),
            reason: 'the options clear the category name');
        expect(m.pillTop(m.optionsTop, 0) + m.pillHeight,
            lessThan(bar.top),
            reason: 'the options sit above the nav bar');
        expect(m.pillWidth, greaterThan(0));
        expect(m.margin * 2 + m.pillWidth, closeTo(device.size.width, 0.001),
            reason: 'the pills are centred');
      });
    }
  }

  testWidgets('on the design frame the numbers are the design\'s',
      (WidgetTester tester) async {
    final SettingsMetrics m = await _metricsOn(
      tester,
      const _Device('iPhone 16 Pro', Size(402, 874), EdgeInsets.only(top: 62)),
    );
    // Measured off the export (frame top at 8px, 1.4925px a point).
    expect(m.scale, closeTo(1, 0.0001));
    expect(m.categoriesTop, closeTo(162.1, 0.5));
    expect(m.subtitleTop, closeTo(141.1, 0.5));
    expect(m.optionsTop, closeTo(184.2, 0.5));
    expect(m.pillHeight, closeTo(48, 0.001));
  });

  testWidgets('Hesab opens, Back closes, Çıxış edin signs out',
      (WidgetTester tester) async {
    int signOuts = 0;
    await _pumpScreen(tester, onSignOut: () async => signOuts++);

    expect(find.text('Tənzimləmələr'), findsOneWidget);
    expect(find.text('Hesab'), findsOneWidget);
    expect(find.text('Çıxış edin'), findsNothing);

    // The first level's pill is where the metrics put it.
    final SettingsMetrics m = SettingsMetrics.of(
      tester.element(find.byType(SettingsScreen)),
    );
    final Rect hesab = tester.getRect(find.byType(SettingsPill));
    expect(hesab.top, closeTo(m.categoriesTop, 0.01));
    expect(hesab.left, closeTo(m.margin, 0.01));
    expect(hesab.height, closeTo(m.pillHeight, 0.01));

    await tester.tap(find.text('Hesab'));
    await tester.pumpAndSettle();

    // `Hesab` is now the name under the title, and its option is up.
    expect(find.text('Çıxış edin'), findsOneWidget);
    final Rect exit = tester.getRect(
      find.ancestor(
        of: find.text('Çıxış edin'),
        matching: find.byType(SettingsPill),
      ),
    );
    expect(exit.top, closeTo(m.optionsTop, 0.01));
    expect(exit.left, closeTo(m.margin, 0.01));

    // Back — Android's button — returns to the list instead of leaving.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Çıxış edin'), findsNothing);
    expect(find.text('Hesab'), findsOneWidget);
    expect(signOuts, 0);

    await tester.tap(find.text('Hesab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıxış edin'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
  });

  testWidgets('a swipe in from the left edge closes the category',
      (WidgetTester tester) async {
    await _pumpScreen(tester, onSignOut: () async {});
    await tester.tap(find.text('Hesab'));
    await tester.pumpAndSettle();
    expect(find.text('Çıxış edin'), findsOneWidget);

    await tester.flingFrom(const Offset(4, 500), const Offset(200, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Çıxış edin'), findsNothing);
  });

}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Future<void> Function() onSignOut,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        type: MaterialType.transparency,
        child: SettingsScreen(
          bottomReserve: 100,
          active: true,
          onSignOut: onSignOut,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SettingsMetrics> _metricsOn(WidgetTester tester, _Device device) async {
  late SettingsMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: device.size, padding: device.padding),
      child: Builder(
        builder: (BuildContext context) {
          metrics = SettingsMetrics.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return metrics;
}

class _Device {
  const _Device(this.name, this.size, this.padding);

  final String name;
  final Size size;
  final EdgeInsets padding;
}
