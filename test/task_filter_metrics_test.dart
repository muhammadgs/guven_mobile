import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/task_filter.dart';
import 'package:guven_mobile/src/features/tasks/presentation/task_filter_metrics.dart';

/// The filter panels are placed by arithmetic, not by a layout: they grow out
/// of the filter button's rect in global coordinates, and the values panel
/// grows out of one *row* of the first panel. Nothing in the widget tree is
/// going to catch a panel that has walked off the bottom of a short phone or a
/// row that has fallen out of the panel it is drawn in — so the questions
/// "does it fit" and "do they collide" are answered here, across the screens,
/// insets and font scales the app ships to.
///
/// Same discipline as `onboarding_metrics_test.dart`, and for the same reason:
/// that screen shipped a collision nobody saw on the device it was built on.
void main() {
  const List<_Device> devices = <_Device>[
    // The canvas the design was drawn against.
    _Device('iPhone 14 Pro', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    // The two phones from the onboarding bug report, in both navigation modes.
    _Device('S23 Ultra gesture', Size(384, 824), EdgeInsets.only(top: 32, bottom: 24)),
    _Device('S23 Ultra 3-button', Size(384, 824), EdgeInsets.only(top: 32, bottom: 48)),
    _Device('S23 gesture', Size(360, 780), EdgeInsets.only(top: 30, bottom: 24)),
    _Device('S23 3-button', Size(360, 780), EdgeInsets.only(top: 30, bottom: 48)),
    // Short and wide — the worst case for anything that has to fit vertically.
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('tall 21:9', Size(360, 900), EdgeInsets.only(top: 40, bottom: 24)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  const List<double> fontScales = <double>[1.0, 1.2];

  /// Every column the filter can offer. The panel is at its tallest here, and
  /// this is the case that has to fit.
  final int allColumns = TaskFilterField.values.length;

  for (final _Device device in devices) {
    for (final double fontScale in fontScales) {
      final String name = '${device.name} @ ${fontScale}x';

      testWidgets('$name — the panel fits the screen', (
        WidgetTester tester,
      ) async {
        final TaskFilterMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
          columns: allColumns,
        );

        expect(m.columnPanel.left, greaterThanOrEqualTo(m.band.left - 0.01));
        expect(m.columnPanel.right, lessThanOrEqualTo(m.band.right + 0.01));
        expect(m.columnPanel.top, greaterThanOrEqualTo(m.band.top - 0.01));
        expect(m.columnPanel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));
      });

      testWidgets('$name — every column fits inside the panel', (
        WidgetTester tester,
      ) async {
        final TaskFilterMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
          columns: allColumns,
        );

        // The rows are laid out by the same arithmetic that positions the
        // sub-panel, so a row that does not fit is a sub-panel anchored to
        // nothing. Capping the panel and scrolling it would break that link.
        expect(
          m.columnRow(allColumns - 1).bottom,
          lessThanOrEqualTo(m.columnPanel.bottom - m.padBottom + 0.01),
          reason: 'the whole column list must fit without scrolling — the '
              'values panel is anchored to a row of it',
        );

        for (int i = 0; i < allColumns; i++) {
          expect(m.columnRow(i).top, greaterThanOrEqualTo(m.columnsTop - 0.01));
          expect(
            m.columnRow(i).bottom,
            lessThanOrEqualTo(m.columnPanel.bottom - m.padBottom + 0.01),
          );
          expect(m.columnRow(i).left, greaterThanOrEqualTo(m.columnPanel.left));
          expect(m.columnRow(i).right, lessThanOrEqualTo(m.columnPanel.right));
        }
      });

      testWidgets('$name — the values panel clears the columns', (
        WidgetTester tester,
      ) async {
        final TaskFilterMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
          columns: allColumns,
        );

        // Short list, long list, and the last row — the three ways a
        // sub-panel can be pushed out of the band.
        for (final int count in <int>[2, 40]) {
          for (final int index in <int>[0, allColumns ~/ 2, allColumns - 1]) {
            final Rect values = m.valuePanel(index: index, valueCount: count);
            final String where = '$count values at row $index';

            expect(
              values.left,
              greaterThanOrEqualTo(m.columnPanel.right - 0.01),
              reason: 'the values panel must not sit on the columns ($where)',
            );
            expect(values.right, lessThanOrEqualTo(m.band.right + 0.01),
                reason: where);
            expect(values.top, greaterThanOrEqualTo(m.band.top - 0.01),
                reason: where);
            expect(values.bottom, lessThanOrEqualTo(m.band.bottom + 0.01),
                reason: where);
          }
        }
      });

      testWidgets('$name — a panel stays wide enough to read', (
        WidgetTester tester,
      ) async {
        final TaskFilterMetrics m = await _metricsFor(
          tester,
          device,
          fontScale,
          columns: allColumns,
        );

        // `Kim tərəfindən` is the longest column label; below about this
        // width it would have to be cut, and Azerbaijani labels are not cut
        // in this app.
        expect(m.panelWidth, greaterThan(130));
      });
    }
  }

  testWidgets('the panel opens at the button it grew out of', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    );
    final TaskFilterMetrics m = await _metricsFor(
      tester,
      device,
      1,
      columns: 7,
    );

    // On the canvas the button sits at the screen's own content edge, which
    // is where the panel belongs: it is the same glass, so it cannot start
    // somewhere else.
    expect(m.columnPanel.left, closeTo(m.button.left, 2.5));
    expect(m.columnPanel.top, closeTo(m.button.top, 0.01));
  });

  testWidgets('a button near the bottom right pulls the panel back on screen', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'S23 3-button',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 48),
    );

    late TaskFilterMetrics m;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: device.size, padding: device.padding),
        child: Builder(
          builder: (BuildContext context) {
            m = TaskFilterMetrics.of(
              context,
              // A button in the far corner — not where this screen puts it,
              // but the case the clamping exists for.
              button: const Rect.fromLTWH(300, 700, 42, 42),
              columnCount: TaskFilterField.values.length,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(m.columnPanel.right, lessThanOrEqualTo(m.band.right + 0.01));
    expect(m.columnPanel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));
    expect(
      m.valuePanel(index: 0, valueCount: 6).right,
      lessThanOrEqualTo(m.band.right + 0.01),
    );
  });

  testWidgets('a taller system font gives the rows more room, not less', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    );

    final TaskFilterMetrics plain = await _metricsFor(
      tester, device, 1, columns: 8);
    final TaskFilterMetrics large = await _metricsFor(
      tester, device, 2, columns: 8);

    // The app clamps the system scale at 1.2 (`guven_app.dart`), but the
    // metrics must not depend on that clamp being there.
    expect(large.rowHeight, greaterThan(plain.rowHeight));
    expect(large.headerHeight, greaterThan(plain.headerHeight));
    expect(large.columnPanel.bottom, lessThanOrEqualTo(large.band.bottom + 0.01));
  });
}

Future<TaskFilterMetrics> _metricsFor(
  WidgetTester tester,
  _Device device,
  double fontScale, {
  required int columns,
}) async {
  late TaskFilterMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          metrics = TaskFilterMetrics.of(
            context,
            button: _button(device),
            columnCount: columns,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return metrics;
}

/// Where `TasksScreen` actually puts the filter button: at the screen's 22pt
/// content edge, under the title and the scope bar.
Rect _button(_Device device) {
  final double scale = (device.size.shortestSide / 390).clamp(0.85, 1.6);
  return Rect.fromLTWH(
    22 * scale,
    device.padding.top + 124 * scale,
    42 * scale,
    42 * scale,
  );
}

class _Device {
  const _Device(this.name, this.size, this.padding);

  final String name;
  final Size size;
  final EdgeInsets padding;
}
