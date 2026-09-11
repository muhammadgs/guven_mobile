import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/shell/domain/shell_destination.dart';
import 'package:guven_mobile/src/features/shell/presentation/main_shell.dart';
import 'package:guven_mobile/src/features/shell/presentation/more_menu_metrics.dart';

/// The `Daha çox` fan is placed by arithmetic, not by a layout: eight buttons
/// on two arcs, anchored to the bar's top edge. Nothing in the widget tree
/// would notice a name running off the side of a narrow phone, or one
/// button's name sitting on its neighbour's disc — so "does it fit" and "do
/// they collide" are answered here, across the screens, insets and font
/// scales the app ships to.
///
/// The names are measured in the real Poppins, not the test font: whether
/// `Rəsmi Qurumlar` fits its box is a question about Poppins.
void main() {
  setUpAll(() async {
    final Uint8List bytes = await File(
      'assets/fonts/Poppins-Medium.ttf',
    ).readAsBytes();
    final FontLoader loader = FontLoader('Poppins')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

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
  final int count = ShellNavLayout.defaults.more.length;

  test('eight buttons make an arc of five over an arc of three', () {
    expect(MoreMenuMetrics.rowSizes(count), <int>[5, 3]);
    // No arc ever holds more than five, however many pages there come to be.
    for (int n = 1; n <= 17; n++) {
      final List<int> rows = MoreMenuMetrics.rowSizes(n);
      expect(rows.fold<int>(0, (int a, int b) => a + b), n);
      expect(rows.every((int r) => r <= MoreMenuMetrics.kMaxPerRow), isTrue);
    }
  });

  for (final _Device device in devices) {
    for (final double fontScale in fontScales) {
      final String name = '${device.name} @ ${fontScale}x';

      testWidgets('$name — every button and name is on screen, above the bar', (
        WidgetTester tester,
      ) async {
        final MoreMenuMetrics m = await _metricsFor(tester, device, fontScale);

        for (int i = 0; i < count; i++) {
          for (final Rect r in <Rect>[m.bubbleRect(i), m.labelRect(i)]) {
            expect(r.left, greaterThanOrEqualTo(m.band.left - 0.01),
                reason: 'button $i runs off the left');
            expect(r.right, lessThanOrEqualTo(m.band.right + 0.01),
                reason: 'button $i runs off the right');
            expect(r.top, greaterThanOrEqualTo(m.band.top - 0.01),
                reason: 'button $i runs under the status bar');
            // The lowest names must still leave the bar visibly alone.
            expect(r.bottom, lessThanOrEqualTo(m.bar.top - 8 * m.unit),
                reason: 'button $i sits on the bar');
          }
        }
      });

      testWidgets('$name — no button touches another, however they are '
          'arranged', (WidgetTester tester) async {
        final MoreMenuMetrics m = await _metricsFor(tester, device, fontScale);
        // Any page can be dragged into any slot, so every name is tried in
        // every slot against every other name in every other slot — as it is
        // actually drawn, scaled down into its box if it had to be.
        final double gap = 3 * m.unit;
        final List<Size> names = <Size>[
          for (final ShellDestination page in ShellDestination.values)
            _drawnName(m, page.title),
        ];
        for (int i = 0; i < count; i++) {
          final Rect disc = m.bubbleRect(i).inflate(gap);
          for (int j = 0; j < count; j++) {
            if (i == j) continue;
            expect(disc.overlaps(m.bubbleRect(j)), isFalse,
                reason: 'disc $i on disc $j');
            for (int a = 0; a < names.length; a++) {
              final Rect nameI = _at(m.labelRect(i), names[a]).inflate(gap);
              expect(disc.overlaps(_at(m.labelRect(j), names[a])), isFalse,
                  reason: 'disc $i on `${ShellDestination.values[a].title}` '
                      'in slot $j');
              for (int b = 0; b < names.length; b++) {
                if (a == b) continue;
                expect(nameI.overlaps(_at(m.labelRect(j), names[b])), isFalse,
                    reason: '`${ShellDestination.values[a].title}` in slot $i '
                        'on `${ShellDestination.values[b].title}` in slot $j');
              }
            }
          }
        }
      });

      testWidgets('$name — the arcs are the design\'s', (
        WidgetTester tester,
      ) async {
        final MoreMenuMetrics m = await _metricsFor(tester, device, fontScale);
        final double mid = m.bar.center.dx;

        // Mirrored about the bar's middle, where `Daha çox` is.
        expect(m.center(2).dx, closeTo(mid, 0.01));
        expect(m.center(6).dx, closeTo(mid, 0.01));
        expect(m.center(0).dx + m.center(4).dx, closeTo(2 * mid, 0.01));
        expect(m.center(5).dx + m.center(7).dx, closeTo(2 * mid, 0.01));

        // Both arcs are domes: highest in the middle.
        expect(m.center(2).dy, lessThan(m.center(1).dy));
        expect(m.center(1).dy, lessThan(m.center(0).dy));
        expect(m.center(6).dy, lessThan(m.center(5).dy));

        // Every name on the outer arc sits above every one on the inner.
        for (int outer = 0; outer < 5; outer++) {
          for (int inner = 5; inner < 8; inner++) {
            expect(m.labelRect(outer).bottom,
                lessThan(m.labelRect(inner).top + 0.01));
          }
        }
      });

      if (fontScale == 1.0) {
        testWidgets('$name — every page name fits its box without shrinking', (
          WidgetTester tester,
        ) async {
          final MoreMenuMetrics m = await _metricsFor(tester, device, fontScale);
          for (final ShellDestination page in ShellDestination.values) {
            final TextPainter painter = TextPainter(
              text: TextSpan(
                text: page.title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: m.labelSize,
                  height: MoreMenuMetrics.kLabelLineHeight,
                ),
              ),
              textDirection: TextDirection.ltr,
              textScaler: m.textScaler,
              maxLines: 1,
            )..layout();
            expect(painter.width, lessThanOrEqualTo(m.labelWidth),
                reason: '`${page.title}` is ${painter.width} wide');
            expect(painter.height, lessThanOrEqualTo(m.labelHeight + 0.5));
          }
        });
      }
    }
  }

  testWidgets('the fan keeps its shape on a narrow phone — smaller, not '
      'squeezed', (WidgetTester tester) async {
    final MoreMenuMetrics canvas = await _metricsFor(
      tester,
      const _Device('iPhone 14 Pro', Size(393, 852), EdgeInsets.zero),
      1,
    );
    final MoreMenuMetrics se = await _metricsFor(
      tester,
      const _Device('iPhone SE', Size(320, 568), EdgeInsets.zero),
      1,
    );
    Offset rel(MoreMenuMetrics m, int i) => (m.center(i) - m.pivot) / m.unit;
    for (int i = 0; i < 8; i++) {
      expect(rel(se, i).dx, closeTo(rel(canvas, i).dx, 0.01));
      expect(rel(se, i).dy, closeTo(rel(canvas, i).dy, 0.01));
    }
    expect(se.bubble / se.labelWidth,
        closeTo(canvas.bubble / canvas.labelWidth, 0.0001));
  });
}

/// How big [title] is drawn: its natural size, scaled down — both ways, the
/// way `FittedBox` does it — if it is wider than the name box.
Size _drawnName(MoreMenuMetrics m, String title) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: title,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w500,
        fontSize: m.labelSize,
        height: MoreMenuMetrics.kLabelLineHeight,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: m.textScaler,
    maxLines: 1,
  )..layout();
  final double fit = (m.labelWidth / painter.width).clamp(0.0, 1.0);
  return Size(painter.width * fit, painter.height * fit);
}

/// A name of [size], centred in the name box [box] as `FittedBox` centres it.
Rect _at(Rect box, Size size) =>
    Rect.fromCenter(center: box.center, width: size.width, height: size.height);

Future<MoreMenuMetrics> _metricsFor(
  WidgetTester tester,
  _Device device,
  double fontScale,
) async {
  late MoreMenuMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          metrics = MoreMenuMetrics.of(
            context,
            bar: MainShell.barRect(context),
            count: ShellNavLayout.defaults.more.length,
          );
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
