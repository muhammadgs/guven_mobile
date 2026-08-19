import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/onboarding/presentation/onboarding_metrics.dart';

/// The onboarding's floating brand layer and its page bodies used to be
/// positioned by two unrelated formulas, so whether they collided depended on
/// the device: the pair sat 22px apart on the design canvas, 44px *through*
/// each other on a Galaxy S23 with three-button navigation, and 98px through
/// each other on a short 16:9 phone.
///
/// Every anchor now comes from [OnboardingMetrics], which means the question
/// "can a body land on the thing above it" is answerable by arithmetic. These
/// tests answer it across the screens, insets and font scales the app ships to.
void main() {
  const List<_Device> devices = <_Device>[
    // The canvas the design was drawn against.
    _Device('iPhone 14 Pro', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
    _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
    // The two phones in the bug report, in both navigation modes. The
    // three-button rows are the ones that used to overlap.
    _Device('S23 Ultra gesture', Size(384, 824), EdgeInsets.only(top: 32, bottom: 24)),
    _Device('S23 Ultra 3-button', Size(384, 824), EdgeInsets.only(top: 32, bottom: 48)),
    _Device('S23 gesture', Size(360, 780), EdgeInsets.only(top: 30, bottom: 24)),
    _Device('S23 3-button', Size(360, 780), EdgeInsets.only(top: 30, bottom: 48)),
    // A short, wide 16:9 phone — the worst case for anchors keyed off height.
    _Device('16:9 phone', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
    // Tall and narrow, and a tablet.
    _Device('tall 21:9', Size(360, 900), EdgeInsets.only(top: 40, bottom: 24)),
    _Device('iPad 11"', Size(834, 1194), EdgeInsets.only(top: 24, bottom: 20)),
  ];

  const List<double> fontScales = <double>[1.0, 1.2];

  for (final _Device device in devices) {
    for (final double fontScale in fontScales) {
      final String name = '${device.name} @ ${fontScale}x';

      testWidgets('$name — no page body overlaps the layer above it',
          (WidgetTester tester) async {
        final OnboardingMetrics metrics =
            await _metricsFor(tester, device, fontScale);

        // Page one: the welcome text starts below the wordmark.
        expect(metrics.welcomeBodyTop,
            greaterThan(metrics.lockupAt(0).bottom),
            reason: 'welcome body must clear the brand lockup');

        // Page two: the paragraph starts below "GF44".
        expect(metrics.overviewBodyTop,
            greaterThan(metrics.headlineAt(1).headlineBottom),
            reason: 'overview paragraph must clear the headline');

        // Page three: the icon grid starts below the two-line subtitle.
        expect(metrics.dataHubBodyTop,
            greaterThan(metrics.headlineAt(2).bottom),
            reason: 'icon grid must clear the headline and its subtitle');

        // Page four: the start button starts below the logo.
        expect(metrics.startCtaTop,
            greaterThan(metrics.lockupAt(3).logoBottom),
            reason: 'start button must clear the logo');
      });

      testWidgets('$name — every anchor stays inside the usable band',
          (WidgetTester tester) async {
        final OnboardingMetrics metrics =
            await _metricsFor(tester, device, fontScale);

        expect(metrics.band, greaterThan(0));
        for (final MapEntry<String, double> anchor in <String, double>{
          'welcome': metrics.welcomeBodyTop,
          'overview': metrics.overviewBodyTop,
          'data hub': metrics.dataHubBodyTop,
          'start CTA': metrics.startCtaTop,
        }.entries) {
          expect(anchor.value, greaterThan(metrics.safeTop),
              reason: '${anchor.key} must start below the status bar');
          expect(anchor.value, lessThan(metrics.floor),
              reason: '${anchor.key} must start above the page indicator');
        }
      });
    }
  }

  testWidgets('the floating layer tracks the system insets', (tester) async {
    // The regression in one assertion: switching a phone from gesture
    // navigation to a three-button bar used to move the page bodies while
    // leaving the floating layer where it was, which is what drove them
    // together. Both must now move, and by the same amount.
    const _Device gesture =
        _Device('gesture', Size(360, 780), EdgeInsets.only(top: 30, bottom: 24));
    const _Device buttons = _Device(
        '3-button', Size(360, 780), EdgeInsets.only(top: 30, bottom: 48));

    final OnboardingMetrics a = await _metricsFor(tester, gesture, 1);
    final OnboardingMetrics b = await _metricsFor(tester, buttons, 1);

    final double layerShift = a.lockupAt(0).top - b.lockupAt(0).top;
    final double bodyShift = a.welcomeBodyTop - b.welcomeBodyTop;

    expect(layerShift, greaterThan(0),
        reason: 'a taller navigation bar must lift the floating layer too');
    expect(bodyShift, closeTo(layerShift, 0.01),
        reason: 'layer and body must move together, not apart');
  });
}

Future<OnboardingMetrics> _metricsFor(
  WidgetTester tester,
  _Device device,
  double fontScale,
) async {
  late OnboardingMetrics metrics;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          metrics = OnboardingMetrics.of(context);
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
