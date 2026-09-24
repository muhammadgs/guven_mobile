/// How the `Baza` tab writes its figures: `7,224` and `1,455,475.61 ₼`.
///
/// Thousands grouped with a comma and the decimals after a point, the way the
/// design sets every number — not the `az-AZ` locale's `1 455 475,61`, which
/// is what the website prints. Written out here rather than pulled from `intl`
/// for two formats that never change.
library;

/// The manat sign. Neither Poppins nor Chakra Petch draws it, so it comes from
/// the platform's own fallback face.
const String kManat = '₼';

/// A count, grouped by thousands: `7224` → `7,224`.
String formatCount(int value) {
  final String digits = _group(value.abs().toString());
  return value < 0 ? '-$digits' : digits;
}

/// An amount in manat, to the qəpik: `1455475.61` → `1,455,475.61 ₼`.
String formatMoney(double value) {
  final String fixed = value.abs().toStringAsFixed(2);
  final int point = fixed.indexOf('.');
  final String amount =
      '${_group(fixed.substring(0, point))}'
      '${fixed.substring(point)}';
  // A debt that rounds to nothing is nothing, not "-0.00".
  final bool negative = value < 0 && fixed != '0.00';
  return '${negative ? '-' : ''}$amount $kManat';
}

String _group(String digits) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
