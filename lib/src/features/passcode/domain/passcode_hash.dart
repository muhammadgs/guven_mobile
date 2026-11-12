import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// How many digits a passcode has. The dots on screen, the keypad's
/// completion check and the store all read this one number.
const int kPasscodeLength = 4;

/// Whether [value] is a complete passcode: exactly [kPasscodeLength] ASCII
/// digits.
bool isCompletePasscode(String value) =>
    value.length == kPasscodeLength && RegExp(r'^[0-9]+$').hasMatch(value);

/// What is kept on disk instead of the passcode itself.
///
/// A four-digit code has only ten thousand values, so no hash makes it
/// uncrackable by someone who already holds the file — the protection is the
/// platform keystore it sits in, and the five-attempt limit in front of it.
/// The hash is there so the digits themselves never exist at rest: not in a
/// backup, not in a keystore dump, not in a log line someone adds later.
class PasscodeHash {
  const PasscodeHash({
    required this.salt,
    required this.digest,
    required this.iterations,
  });

  /// Random per passcode, so two accounts that pick `1234` store different
  /// digests.
  final Uint8List salt;
  final Uint8List digest;

  /// PBKDF2 rounds this digest was made with. Stored beside it, so the
  /// default can change without stranding codes set under the old one.
  final int iterations;

  /// PBKDF2-HMAC-SHA256 rounds for a new passcode. It runs once per entered
  /// code, after the fourth digit, and off the UI isolate.
  static const int defaultIterations = 20000;

  static const int _saltLength = 16;

  /// Hashes [passcode] with a fresh random salt.
  factory PasscodeHash.create(
    String passcode, {
    int iterations = defaultIterations,
    Random? random,
  }) {
    final Random source = random ?? Random.secure();
    final Uint8List salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => source.nextInt(256)),
    );
    return PasscodeHash(
      salt: salt,
      digest: _pbkdf2(passcode, salt, iterations),
      iterations: iterations,
    );
  }

  /// Whether [passcode] is the one this hash was made from.
  ///
  /// Compared in constant time — every byte is looked at whether or not an
  /// earlier one already differed.
  bool matches(String passcode) {
    final Uint8List candidate = _pbkdf2(passcode, salt, iterations);
    if (candidate.length != digest.length) return false;
    int difference = 0;
    for (int i = 0; i < digest.length; i++) {
      difference |= candidate[i] ^ digest[i];
    }
    return difference == 0;
  }

  /// `v1:iterations:salt:digest`, salt and digest in base64 — the single
  /// string the keystore holds.
  String encode() =>
      'v1:$iterations:${base64.encode(salt)}:${base64.encode(digest)}';

  /// Null for anything that is not what [encode] wrote.
  static PasscodeHash? decode(String? raw) {
    if (raw == null) return null;
    final List<String> parts = raw.split(':');
    if (parts.length != 4 || parts[0] != 'v1') return null;
    final int? iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return null;
    try {
      final Uint8List salt = base64.decode(parts[2]);
      final Uint8List digest = base64.decode(parts[3]);
      if (salt.isEmpty || digest.length != 32) return null;
      return PasscodeHash(salt: salt, digest: digest, iterations: iterations);
    } on FormatException {
      return null;
    }
  }

  /// One 32-byte PBKDF2 block — SHA-256's output length, so one block is the
  /// whole derived key.
  static Uint8List _pbkdf2(String passcode, Uint8List salt, int iterations) {
    final Hmac hmac = Hmac(sha256, utf8.encode(passcode));
    final Uint8List block = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..setAll(salt.length, const <int>[0, 0, 0, 1]);
    List<int> u = hmac.convert(block).bytes;
    final Uint8List result = Uint8List.fromList(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}

/// Creates and checks passcode hashes.
///
/// The default does the PBKDF2 work on a short-lived isolate: twenty thousand
/// HMAC rounds are tens of milliseconds in a release build but most of a
/// second in a debug one, and the dots are mid-animation when it runs. Tests
/// swap in [PasscodeHasher.inline] with a handful of rounds.
class PasscodeHasher {
  const PasscodeHasher({
    this.iterations = PasscodeHash.defaultIterations,
    this.offThread = true,
  });

  /// Same isolate, few rounds — for tests, where a spawned isolate does not
  /// run under the fake clock.
  const PasscodeHasher.inline({this.iterations = 8}) : offThread = false;

  final int iterations;
  final bool offThread;

  Future<PasscodeHash> create(String passcode) {
    final int rounds = iterations;
    if (!offThread) {
      return Future<PasscodeHash>.value(
        PasscodeHash.create(passcode, iterations: rounds),
      );
    }
    return Isolate.run(() => PasscodeHash.create(passcode, iterations: rounds));
  }

  Future<bool> matches(PasscodeHash hash, String passcode) {
    if (!offThread) return Future<bool>.value(hash.matches(passcode));
    return Isolate.run(() => hash.matches(passcode));
  }
}
