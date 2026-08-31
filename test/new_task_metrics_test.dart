import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';
import 'package:guven_mobile/src/features/tasks/presentation/new_task_metrics.dart';

/// `Yeni tapşırıq` is placed by arithmetic, not by a layout: the chooser grows
/// out of the `+` button's rect in global coordinates, the sheet grows out of
/// the chooser, and a field's list grows out of that field's own row. Nothing
/// in the widget tree is going to catch a panel that has walked off the bottom
/// of a short phone — so "does it fit" is answered here, across the screens,
/// insets and font scales the app ships to.
///
/// Same discipline as `task_filter_metrics_test.dart`, and for the same
/// reason: the onboarding screen once shipped a collision nobody saw on the
/// device it was built on.
void main() {
  const List<_Device> devices = <_Device>[
    // The canvas the design was drawn against.
    _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    ),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    _Device(
      'S23 Ultra gesture',
      Size(384, 824),
      EdgeInsets.only(top: 32, bottom: 24),
    ),
    _Device(
      'S23 Ultra 3-button',
      Size(384, 824),
      EdgeInsets.only(top: 32, bottom: 48),
    ),
    _Device('S23 gesture', Size(360, 780), EdgeInsets.only(top: 30, bottom: 24)),
    _Device('S23 3-button', Size(360, 780), EdgeInsets.only(top: 30, bottom: 48)),
    // Short and wide — the worst case for anything that has to fit vertically.
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    _Device('tall 21:9', Size(360, 900), EdgeInsets.only(top: 40, bottom: 24)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  const List<double> fontScales = <double>[1.0, 1.2];

  final int kinds = NewTaskKind.values.length;

  for (final _Device device in devices) {
    for (final double fontScale in fontScales) {
      final String name = '${device.name} @ ${fontScale}x';

      testWidgets('$name — the chooser fits, and so does every row', (
        WidgetTester tester,
      ) async {
        final NewTaskMetrics m = await _metricsFor(tester, device, fontScale);

        expect(m.menuPanel.left, greaterThanOrEqualTo(m.band.left - 0.01));
        expect(m.menuPanel.right, lessThanOrEqualTo(m.band.right + 0.01));
        expect(m.menuPanel.top, greaterThanOrEqualTo(m.band.top - 0.01));
        expect(m.menuPanel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));

        for (int i = 0; i < kinds; i++) {
          expect(m.menuRow(i).left, greaterThanOrEqualTo(m.menuPanel.left));
          expect(m.menuRow(i).right, lessThanOrEqualTo(m.menuPanel.right));
          expect(
            m.menuRow(i).bottom,
            lessThanOrEqualTo(
              m.menuPanel.bottom -
                  NewTaskMetrics.kMenuPadBottom * m.scale +
                  0.01,
            ),
            reason: 'the three kinds must fit without the chooser scrolling',
          );
        }
      });

      testWidgets('$name — the sheet fits, and leaves the screen showing', (
        WidgetTester tester,
      ) async {
        final NewTaskMetrics m = await _metricsFor(tester, device, fontScale);

        expect(m.sheet.left, greaterThanOrEqualTo(m.band.left - 0.01));
        expect(m.sheet.right, lessThanOrEqualTo(m.band.right + 0.01));
        expect(m.sheet.top, greaterThan(m.band.top));
        expect(m.sheet.bottom, lessThan(m.band.bottom));
        // The dimmed screen behind it is the whole point of a sheet rather
        // than a page — it has to stay visible at both ends.
        expect(m.sheet.top - m.band.top, greaterThan(20));
        expect(m.band.bottom - m.sheet.bottom, greaterThan(20));
        // …and it still has to be a form, not a letterbox.
        expect(m.sheet.height, greaterThan(m.sheet.width * 0.7));
      });

      testWidgets('$name — a field list opens on screen wherever the field is',
          (WidgetTester tester) async {
        final NewTaskMetrics m = await _metricsFor(tester, device, fontScale);

        // A field at the top of the sheet, in the middle, and at the very
        // bottom — the three ways a list can be pushed out of the band — with
        // a short list and one far longer than fits.
        final List<Rect> anchors = <Rect>[
          Rect.fromLTWH(m.sheet.left + m.sheetPadH, m.sheet.top + 40,
              m.sheet.width - 2 * m.sheetPadH, m.fieldHeight),
          Rect.fromLTWH(m.sheet.left + m.sheetPadH, m.sheet.center.dy,
              m.sheet.width - 2 * m.sheetPadH, m.fieldHeight),
          Rect.fromLTWH(
              m.sheet.left + m.sheetPadH,
              m.sheet.bottom - m.fieldHeight,
              m.sheet.width - 2 * m.sheetPadH,
              m.fieldHeight),
        ];

        for (final Rect anchor in anchors) {
          for (final int rows in <int>[1, 4, 60]) {
            final Rect panel = m.pickerPanel(anchor: anchor, rowCount: rows);
            final String where = '$rows rows at ${anchor.top.round()}';

            expect(panel.left, greaterThanOrEqualTo(m.band.left - 0.01),
                reason: where);
            expect(panel.right, lessThanOrEqualTo(m.band.right + 0.01),
                reason: where);
            expect(panel.top, greaterThanOrEqualTo(m.band.top - 0.01),
                reason: where);
            expect(panel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01),
                reason: where);
          }

          // The date wheel is the one panel whose height is not a row count.
          final Rect wheel = m.panelAt(anchor: anchor, height: 250 * m.scale);
          expect(wheel.top, greaterThanOrEqualTo(m.band.top - 0.01));
          expect(wheel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));
        }
      });
    }
  }

  testWidgets('the chooser opens at the button it grew out of', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'iPhone 14 Pro',
      Size(393, 852),
      EdgeInsets.only(top: 59, bottom: 34),
    );
    final NewTaskMetrics m = await _metricsFor(tester, device, 1);

    // It is the same glass, so it cannot start somewhere the button is not.
    expect(m.menuPanel.left, closeTo(m.button.left, 2.5));
    expect(m.menuPanel.top, closeTo(m.button.top, 0.01));
  });

  testWidgets('a keyboard raises the sheet\'s foot and leaves its head alone', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    );

    final NewTaskMetrics shut = await _metricsFor(tester, device, 1);
    final NewTaskMetrics open = await _metricsFor(
      tester,
      device,
      1,
      keyboard: 320,
    );

    expect(open.sheet.top, closeTo(shut.sheet.top, 0.01),
        reason: 'the title must not walk down the screen when the '
            'description field is tapped');
    expect(open.sheet.bottom, lessThan(shut.sheet.bottom));
    expect(open.sheet.bottom, lessThanOrEqualTo(780 - 320 + 0.01));
    expect(open.sheet.height, greaterThan(120));
  });

  testWidgets('a taller system font gives the rows more room, not less', (
    WidgetTester tester,
  ) async {
    const _Device device = _Device(
      'S23 gesture',
      Size(360, 780),
      EdgeInsets.only(top: 30, bottom: 24),
    );

    final NewTaskMetrics plain = await _metricsFor(tester, device, 1);
    final NewTaskMetrics large = await _metricsFor(tester, device, 2);

    // The app clamps the system scale at 1.2 (`guven_app.dart`), but the
    // metrics must not depend on that clamp being there.
    expect(large.menuRowHeight, greaterThan(plain.menuRowHeight));
    expect(large.fieldHeight, greaterThan(plain.fieldHeight));
    expect(large.pickerRowHeight, greaterThan(plain.pickerRowHeight));
    expect(large.menuPanel.bottom, lessThanOrEqualTo(large.band.bottom + 0.01));
  });

  testWidgets('a button in the far corner pulls the chooser back on screen', (
    WidgetTester tester,
  ) async {
    late NewTaskMetrics m;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          padding: EdgeInsets.only(top: 30, bottom: 48),
        ),
        child: Builder(
          builder: (BuildContext context) {
            m = NewTaskMetrics.of(
              context,
              // Not where this screen puts it, but the case the clamping is
              // there for.
              button: const Rect.fromLTWH(310, 720, 42, 42),
              menuRows: NewTaskKind.values.length,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(m.menuPanel.right, lessThanOrEqualTo(m.band.right + 0.01));
    expect(m.menuPanel.bottom, lessThanOrEqualTo(m.band.bottom + 0.01));
  });
}

Future<NewTaskMetrics> _metricsFor(
  WidgetTester tester,
  _Device device,
  double fontScale, {
  double keyboard = 0,
}) async {
  late NewTaskMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        viewInsets: EdgeInsets.only(bottom: keyboard),
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          metrics = NewTaskMetrics.of(
            context,
            button: _button(device),
            menuRows: NewTaskKind.values.length,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return metrics;
}

/// Where `TasksScreen` actually puts the `+`: at the screen's 22pt content
/// edge, one button-and-gap right of the funnel.
Rect _button(_Device device) {
  final double scale = (device.size.shortestSide / 390).clamp(0.85, 1.6);
  return Rect.fromLTWH(
    (22 + 42 + 12) * scale,
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
