import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Which unlock the phone has set up besides its own passcode — named the way
/// the person knows it from their phone's settings.
enum BiometricKind {
  /// iPhone with Face ID.
  faceId,

  /// iPhone or iPad with a Touch ID button.
  touchId,

  /// An Android fingerprint reader.
  fingerprint,

  /// Android face unlock (class 3 only — the weak kind cannot sign in here).
  face,

  /// Android reports "a strong biometric" without saying which. Most phones
  /// do exactly this, so it gets a name that covers both.
  generic;

  /// `Face ID ilə`, `Barmaq izi ilə` — what goes before "daxil olmaq".
  String get withPhrase => switch (this) {
    BiometricKind.faceId => 'Face ID ilə',
    BiometricKind.touchId => 'Touch ID ilə',
    BiometricKind.fingerprint => 'Barmaq izi ilə',
    BiometricKind.face => 'Üz tanıma ilə',
    BiometricKind.generic => 'Barmaq izi və ya üz tanıma ilə',
  };

  /// Whether the glyph for it is a face rather than a fingerprint.
  bool get isFace =>
      this == BiometricKind.faceId || this == BiometricKind.face;
}

/// The phone's own biometric check, behind an interface so the lock can be
/// tested without a fingerprint.
abstract class BiometricGate {
  /// What is enrolled right now, or null when nothing usable is.
  Future<BiometricKind?> available();

  /// Shows the system prompt. True only for a successful match; a cancel, a
  /// lockout or a missing sensor are all false — the passcode is always there
  /// to fall back on, so none of them is an error worth showing.
  Future<bool> authenticate({required String reason, required String cancel});
}

/// [BiometricGate] over `local_auth`.
class LocalBiometricGate implements BiometricGate {
  LocalBiometricGate({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricKind?> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return null;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return null;
      final bool apple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      if (apple) {
        if (types.contains(BiometricType.face)) return BiometricKind.faceId;
        if (types.contains(BiometricType.fingerprint)) {
          return BiometricKind.touchId;
        }
        return null;
      }
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricKind.fingerprint;
      }
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      // `weak` alone cannot satisfy a biometric-only prompt on Android.
      if (types.contains(BiometricType.strong)) return BiometricKind.generic;
      return null;
    } catch (_) {
      // A platform without the plugin (tests, desktop) or a sensor error:
      // either way there is no shortcut to offer.
      return null;
    }
  }

  @override
  Future<bool> authenticate({
    required String reason,
    required String cancel,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // The app's own passcode is the fallback, so the phone's PIN/pattern
        // is never offered in its place.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Güvən Finans',
            signInHint: reason,
            cancelButton: cancel,
          ),
          IOSAuthMessages(cancelButton: cancel),
        ],
      );
    } catch (_) {
      // Lockout, no sensor, no plugin — the passcode is the way in.
      return false;
    }
  }
}
