import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/features/auth/domain/login_identifier.dart';

/// Runs [typed] through the login field's formatters, the way a keystroke or
/// a paste is.
String _filtered(String typed) {
  TextEditingValue value = TextEditingValue(
    text: typed,
    selection: TextSelection.collapsed(offset: typed.length),
  );
  for (final TextInputFormatter formatter in LoginIdentifier.inputFormatters) {
    value = formatter.formatEditUpdate(TextEditingValue.empty, value);
  }
  return value.text;
}

void main() {
  group('a phone number', () {
    test('is sent the way registration stores it, however it was typed', () {
      for (final String typed in <String>[
        '0501234567',
        '501234567',
        '994501234567',
        '+994501234567',
        '050-123-45-67',
        '  0501234567  ',
      ]) {
        final LoginIdentifier? login = LoginIdentifier.parse(typed);
        expect(login?.username, '+994501234567', reason: typed);
        expect(login?.kind, LoginKind.phone, reason: typed);
      }
    });

    test('every operator the registration forms offer is accepted', () {
      for (final String prefix in <String>[
        '10', '50', '51', '55', '70', '77', '99',
      ]) {
        expect(
          LoginIdentifier.parse('0${prefix}1234567')?.username,
          '+994${prefix}1234567',
          reason: prefix,
        );
      }
    });

    test('a landline, a foreign number or the wrong length is refused', () {
      for (final String typed in <String>[
        '0121234567', // Baku landline
        '+905321234567', // Turkish mobile
        '050123456', // a digit short
        '05012345678', // a digit over
        '12345',
      ]) {
        expect(LoginIdentifier.parse(typed), isNull, reason: typed);
      }
    });
  });

  group('an email', () {
    test('is sent exactly as typed, trimmed', () {
      final LoginIdentifier? login = LoginIdentifier.parse(' Ali.Veli@guvenfinans.az ');
      expect(login?.username, 'Ali.Veli@guvenfinans.az');
      expect(login?.kind, LoginKind.email);
      expect(LoginIdentifier.parse('a+b_c-d@mail.co.uk'), isNotNull);
    });

    test('a malformed address is refused', () {
      for (final String typed in <String>[
        'ali@',
        '@guvenfinans.az',
        'ali@guvenfinans',
        'ali@@guvenfinans.az',
        'ali..veli@guvenfinans.az',
        '.ali@guvenfinans.az',
        'ali.@guvenfinans.az',
      ]) {
        expect(LoginIdentifier.parse(typed), isNull, reason: typed);
      }
    });
  });

  test('SQL typed into the field never becomes a login', () {
    for (final String typed in <String>[
      "admin' OR '1'='1",
      "' OR 1=1 --",
      "admin'--@x.az",
      'x@y.az; DROP TABLE users',
      '1; SELECT * FROM users',
      'admin',
      '',
    ]) {
      expect(LoginIdentifier.parse(typed), isNull, reason: typed);
    }
  });

  group('the field itself', () {
    test('drops quotes, semicolons, spaces and brackets as they are typed', () {
      expect(_filtered("admin' OR '1'='1"), 'adminOR11');
      expect(_filtered('x@y.az; DROP TABLE users'), 'x@y.azDROPTABLEusers');
      expect(_filtered('"ali"@mail.az'), 'ali@mail.az');
    });

    test('a pasted, spaced-out number arrives ready to use', () {
      expect(_filtered('+994 (50) 123 45 67'), '+994501234567');
      expect(LoginIdentifier.parse(_filtered('+994 (50) 123 45 67')), isNotNull);
    });

    test('an ordinary email passes through untouched', () {
      expect(_filtered('ali.veli+work@guvenfinans.az'), 'ali.veli+work@guvenfinans.az');
      expect(_filtered('a-b_c@mail.az'), 'a-b_c@mail.az');
    });

    test('letters outside ASCII are dropped — no mailbox here uses them', () {
      expect(_filtered('əli@mail.az'), 'li@mail.az');
    });
  });
}
