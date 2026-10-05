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

/// A figure to [digits] decimal places, grouped the same way but with no
/// currency after it: `1234.5` → `1,234.50`. `Satışlar` writes its currency
/// as a code after the figure (`58.20 AZN`), and its table writes none at all.
String formatDecimal(double value, {int digits = 2}) {
  final String fixed = value.abs().toStringAsFixed(digits);
  final int point = fixed.indexOf('.');
  final String whole = point < 0 ? fixed : fixed.substring(0, point);
  final String amount =
      '${_group(whole)}${point < 0 ? '' : fixed.substring(point)}';
  final bool negative = value < 0 && double.parse(fixed) != 0;
  return '${negative ? '-' : ''}$amount';
}

/// A quantity, as the website writes one: whole numbers bare, anything else
/// to at most three places with the trailing zeros dropped — `1` and
/// `1.094`, never `1.000`, since 1C weighs meat to the gram.
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return formatCount(value.round());
  String text = formatDecimal(value, digits: 3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

String _group(String digits) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
