import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Everything the lock remembers between launches.
@immutable
class PasscodeRecord {
  const PasscodeRecord({
    this.hash,
    this.biometricEnabled = false,
    this.failures = 0,
    this.name,
  });

  /// `PasscodeHash.encode()`, or null when no code has been set.
  final String? hash;

  /// The person said yes to Face ID / fingerprint on the setup screen.
  final bool biometricEnabled;

  /// Wrong codes in a row. Kept on disk so killing the app does not hand out
  /// a fresh set of attempts.
  final int failures;

  /// The given name the lock greets with — kept so the greeting is right on
  /// the very first frame, before `/auth/me` has answered, and offline.
  final String? name;
}

/// Where the passcode's record lives.
abstract class PasscodeStore {
  Future<PasscodeRecord> read();
  Future<void> writeHash(String encoded);
  Future<void> writeBiometric(bool enabled);
  Future<void> writeFailures(int count);
  Future<void> writeName(String? name);

  /// Drops everything — the session it belonged to is over.
  Future<void> clear();
}

/// The platform keystore: iOS Keychain, Android `EncryptedSharedPreferences`
/// under a Keystore-wrapped key — the same place, and the same options, as the
/// session tokens in `TokenStore`.
class SecurePasscodeStore implements PasscodeStore {
  SecurePasscodeStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const String _hashKey = 'guven_passcode_hash';
  static const String _biometricKey = 'guven_passcode_biometric';
  static const String _failuresKey = 'guven_passcode_failures';
  static const String _nameKey = 'guven_passcode_name';

  final FlutterSecureStorage _storage;

  @override
  Future<PasscodeRecord> read() async {
    // A keystore whose keys were invalidated (a restored backup, a changed
    // screen lock) fails the read outright. That is the same as no passcode:
    // the person signs in again and sets a new one.
    try {
      final String? hash = await _storage.read(key: _hashKey);
      final String? biometric = await _storage.read(key: _biometricKey);
      final String? failures = await _storage.read(key: _failuresKey);
      final String? name = await _storage.read(key: _nameKey);
      return PasscodeRecord(
        hash: hash,
        biometricEnabled: biometric == '1',
        failures: int.tryParse(failures ?? '') ?? 0,
        name: name,
      );
    } catch (_) {
      return const PasscodeRecord();
    }
  }

  @override
  Future<void> writeHash(String encoded) =>
      _storage.write(key: _hashKey, value: encoded);

  @override
  Future<void> writeBiometric(bool enabled) =>
      _storage.write(key: _biometricKey, value: enabled ? '1' : '0');

  @override
  Future<void> writeFailures(int count) =>
      _storage.write(key: _failuresKey, value: '$count');

  @override
  Future<void> writeName(String? name) async {
    if (name == null || name.isEmpty) {
      await _storage.delete(key: _nameKey);
    } else {
      await _storage.write(key: _nameKey, value: name);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _failuresKey);
    await _storage.delete(key: _nameKey);
  }
}

/// Keeps the record in memory — for tests, and nothing else.
class MemoryPasscodeStore implements PasscodeStore {
  MemoryPasscodeStore([this.record = const PasscodeRecord()]);

  PasscodeRecord record;

  @override
  Future<PasscodeRecord> read() async => record;

  @override
  Future<void> writeHash(String encoded) async => record = PasscodeRecord(
    hash: encoded,
    biometricEnabled: record.biometricEnabled,
    failures: record.failures,
    name: record.name,
  );

  @override
  Future<void> writeBiometric(bool enabled) async => record = PasscodeRecord(
    hash: record.hash,
    biometricEnabled: enabled,
    failures: record.failures,
    name: record.name,
  );

  @override
  Future<void> writeFailures(int count) async => record = PasscodeRecord(
    hash: record.hash,
    biometricEnabled: record.biometricEnabled,
    failures: count,
    name: record.name,
  );

  @override
  Future<void> writeName(String? name) async => record = PasscodeRecord(
    hash: record.hash,
    biometricEnabled: record.biometricEnabled,
    failures: record.failures,
    name: name,
  );

  @override
  Future<void> clear() async => record = const PasscodeRecord();
}
