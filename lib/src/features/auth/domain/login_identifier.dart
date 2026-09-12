import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Which of the two things the login field accepts was typed into it.
enum LoginKind { email, phone }

/// A login that has been checked and put into the form the backend stores.
///
/// The login field takes an email or an Azerbaijani mobile number and nothing
/// else, and the only way to get a value to `/auth/login` is through [parse] —
/// so text that is neither, SQL fragments included, never leaves the phone.
/// That is a courtesy to the user and a filter for idle attempts, not the
/// security boundary: anyone can post to the endpoint without this app, and
/// the backend has to refuse such input on its own.
class LoginIdentifier {
  const LoginIdentifier._(this.username, this.kind);

  /// What is sent as `username`: the email as typed, or the number as
  /// `+994XXXXXXXXX` — the exact shape every registration form on the website
  /// stores it in, so the backend's lookup matches.
  final String username;

  final LoginKind kind;

  /// Keeps the field to the characters an email or a phone number can hold.
  ///
  /// Anything else — quotes, `;`, spaces, brackets — is dropped as it is typed
  /// or pasted, so a pasted `+994 50 123 45 67` arrives as `+994501234567`.
  /// `-` stays because email domains use it; a number typed as `050-123-45-67`
  /// has its hyphens removed by [parse].
  static final List<TextInputFormatter> inputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._+\-]')),
    // The longest address an email may be.
    LengthLimitingTextInputFormatter(254),
  ];

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._+\-]+@(?:[A-Za-z0-9\-]+\.)+[A-Za-z]{2,}$',
  );

  static final RegExp _digits = RegExp(r'^\+?\d+$');

  /// The checked login, or null when [raw] is neither a well-formed email nor
  /// an Azerbaijani mobile number.
  static LoginIdentifier? parse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return null;

    if (text.contains('@')) {
      final bool wellFormed = _email.hasMatch(text) &&
          !text.contains('..') &&
          !text.startsWith('.') &&
          !text.contains('.@');
      return wellFormed ? LoginIdentifier._(text, LoginKind.email) : null;
    }

    final String? phone = _azerbaijaniMobile(text.replaceAll('-', ''));
    return phone == null ? null : LoginIdentifier._(phone, LoginKind.phone);
  }

  /// [text] as `+994XXXXXXXXX` when it is a real Azerbaijani mobile number.
  ///
  /// Accepts the ways people write one: `0501234567`, `501234567`,
  /// `994501234567`, `+994501234567`. The operator is checked against the
  /// numbering plan, so `0201234567` — a Baku landline — is refused along with
  /// numbers that are simply the wrong length.
  static String? _azerbaijaniMobile(String text) {
    if (!_digits.hasMatch(text)) return null;
    // Written with the country code but without the plus, which the parser
    // would otherwise read as a national number that is three digits long.
    final String candidate =
        !text.startsWith('+') && text.startsWith('994') && text.length == 12
            ? '+$text'
            : text;
    try {
      final PhoneNumber number = PhoneNumber.parse(
        candidate,
        callerCountry: IsoCode.AZ,
      );
      if (number.isoCode != IsoCode.AZ) return null;
      if (!number.isValid(type: PhoneNumberType.mobile)) return null;
      return number.international;
    } on PhoneNumberException {
      return null;
    }
  }
}
