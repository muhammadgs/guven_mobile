import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/database/domain/database_section.dart';
import 'package:guven_mobile/src/features/database/presentation/database_menu_metrics.dart';

/// The `Detallar` panels are placed by arithmetic, not by a layout — the menu
/// grows out of the button's rect in global coordinates and a heading's panel
/// out of one row of the menu — so nothing in the widget tree will catch one
/// that has walked off a short phone or landed on the other. "Does it fit" and
/// "do they collide" are answered here, across the screens, insets and font
/// scales the app ships to, the same way the task filter's are.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A heading's panel is as wide as its longest name *measures*, so the
  // measuring has to be done in the real face. The test runner sets every
  // family in its own block font otherwise, which is far wider than Poppins.
  setUpAll(() async {
    final FontLoader poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    await poppins.load();
  });

  const List<_Device> devices = <_Device>[
    // The frame the design was drawn in.
    _Device(
      'iPhone 16 Pro',
      Size(402, 874),
      EdgeInsets.only(top: 62, bottom: 34),
    ),
    _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    ),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    ),
    _Device(
      'S23 3-button',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 48),
    ),
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  const List<double> fontScales = <double>[1.0, 1.2];

  for (final _Device device in devices) {
    for (final double fontScale in fontScales) {
      final String name = '${device.name} @ ${fontScale}x';

      testWidgets('$name — the menu fits, rows and all', (
        WidgetTester tester,
      ) async {
        final DatabaseMenuMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
        );
        final Rect menu = m.mainPanel;

        expect(menu.left, greaterThanOrEqualTo(m.band.left - 0.01));
        expect(menu.right, lessThanOrEqualTo(m.band.right + 0.01));
        expect(menu.top, greaterThanOrEqualTo(m.band.top - 0.01));
        expect(menu.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));

        // A heading's panel is anchored to its row, so a row that had to be
        // scrolled to would be a panel anchored to nothing.
        final int last = DatabaseMenuMetrics.entryCount - 1;
        expect(
          m.entryRow(last).bottom,
          lessThanOrEqualTo(menu.bottom - m.padBottom + 0.01),
        );
        for (int i = 0; i <= last; i++) {
          final Rect row = m.entryRow(i);
          expect(row.left, greaterThanOrEqualTo(menu.left));
          expect(row.right, lessThanOrEqualTo(menu.right));
          expect(m.entryCapsule(i).height, lessThanOrEqualTo(row.height));
        }
      });

      testWidgets('$name — every heading\'s panel clears the menu', (
        WidgetTester tester,
      ) async {
        final DatabaseMenuMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
        );
        final Rect menu = m.mainPanel;

        for (final DatabaseGroup group in DatabaseGroup.values) {
          final Rect panel = m.groupPanel(group);
          final String what = group.title;

          expect(
            panel.left,
            greaterThanOrEqualTo(menu.right - 0.01),
            reason: 'a heading\'s panel must not sit on the menu ($what)',
          );
          expect(
            panel.right,
            lessThanOrEqualTo(m.band.right + 0.01),
            reason: what,
          );
          expect(
            panel.top,
            greaterThanOrEqualTo(m.band.top - 0.01),
            reason: what,
          );
          expect(
            panel.bottom,
            lessThanOrEqualTo(m.band.bottom + 0.01),
            reason: what,
          );
          expect(
            panel.height,
            greaterThanOrEqualTo(group.sections.length * m.groupRowHeight),
            reason: 'every page under $what has a row of its own',
          );
        }
      });
    }
  }

  testWidgets('the menu opens at the button it grew out of', (
    WidgetTester tester,
  ) async {
    final DatabaseMenuMetrics m = await _metricsFor(tester, devices.first, 1);

    // It is the same glass, so it cannot start somewhere else.
    expect(m.mainPanel.topLeft, m.button.topLeft);
  });

  testWidgets('a heading\'s panel sits level with its heading', (
    WidgetTester tester,
  ) async {
    final DatabaseMenuMetrics m = await _metricsFor(tester, devices.first, 1);

    // The design centres `Əməliyyatlar`' pages on `Əməliyyatlar`.
    const DatabaseGroup group = DatabaseGroup.operations;
    expect(
      m.groupPanel(group).center.dy,
      closeTo(m.entryRow(1 + group.index).center.dy, 0.01),
    );
  });

  testWidgets('a longer name makes a wider panel, up to the room there is', (
    WidgetTester tester,
  ) async {
    final DatabaseMenuMetrics m = await _metricsFor(tester, devices.first, 1);

    final double operations = m.groupPanel(DatabaseGroup.operations).width;
    final double reports = m.groupPanel(DatabaseGroup.reports).width;

    // `Menecer Statistikası` against `Sifarişlər`.
    expect(reports, greaterThan(operations));
    expect(operations, closeTo(m.groupPanelMinWidth, 0.01));
  });
}

Future<DatabaseMenuMetrics> _metricsFor(
  WidgetTester tester,
  _Device device,
  double fontScale,
) async {
  late DatabaseMenuMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          metrics = DatabaseMenuMetrics.of(context, button: _button(device));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return metrics;
}

/// Where `DatabaseScreen` puts the menu button: at its 33.5pt content edge,
/// 105pt under the safe area — both on the design's 402pt frame — and at the
/// task list's size.
Rect _button(_Device device) {
  final double canvas = (device.size.shortestSide / 390).clamp(0.85, 1.6);
  final double frame = canvas * 390 / 402;
  return Rect.fromLTWH(
    33.5 * frame,
    device.padding.top + 105 * frame,
    42 * canvas,
    42 * canvas,
  );
}

class _Device {
  const _Device(this.name, this.size, this.padding);

  final String name;
  final Size size;
  final EdgeInsets padding;
}
