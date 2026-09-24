import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/database/presentation/database_format.dart';

/// The figures are written the way the design writes them — `7,224` and
/// `1,455,475.61 ₼` — and a figure written wrongly is a wrong figure.
void main() {
  group('counts', () {
    test('are grouped by thousands with a comma', () {
      expect(formatCount(0), '0');
      expect(formatCount(61), '61');
      expect(formatCount(475), '475');
      expect(formatCount(7224), '7,224');
      expect(formatCount(1000000), '1,000,000');
    });

    test('keep their sign outside the grouping', () {
      expect(formatCount(-7224), '-7,224');
      expect(formatCount(-100), '-100');
    });
  });

  group('amounts', () {
    test('are written to the qəpik, grouped, in manat', () {
      expect(formatMoney(1455475.61), '1,455,475.61 ₼');
      expect(formatMoney(1105035.18), '1,105,035.18 ₼');
      expect(formatMoney(0), '0.00 ₼');
      expect(formatMoney(999.5), '999.50 ₼');
      expect(formatMoney(1000), '1,000.00 ₼');
    });

    test('round to the nearest qəpik, carrying into the thousands', () {
      expect(formatMoney(12.346), '12.35 ₼');
      expect(formatMoney(12.344), '12.34 ₼');
      expect(formatMoney(999999.999), '1,000,000.00 ₼');
    });

    test('carry a minus only when there is something to owe', () {
      expect(formatMoney(-2500.4), '-2,500.40 ₼');
      expect(formatMoney(-0.001), '0.00 ₼');
    });
  });
}
