import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/biometric_gate.dart';
import '../data/passcode_store.dart';
import '../domain/passcode_hash.dart';

/// What a typed code turned out to be.
enum PasscodeCheck {
  correct,

  /// Wrong, with attempts still left.
  wrong,

  /// Wrong for the [PasscodeController.maxFailures]th time in a row — the
  /// session has to end.
  exhausted,
}

/// The app's own lock: a four-digit code set after signing in, asked again on
/// every launch and after a while in the background, with Face ID /
/// fingerprint as an optional shortcut.
///
/// It is a *gate*, not authentication — the session stays signed in
/// underneath, as the user asked ("hesabda oturum qalacaq, bu sadəcə
/// təhlükəsizlik üçündür"). Ending the session ends the lock with it
/// ([forget]); the next sign-in starts from the welcome screen again.
class PasscodeController extends ChangeNotifier {
  PasscodeController({
    PasscodeStore? store,
    BiometricGate? biometrics,
    this._hasher = const PasscodeHasher(),
    DateTime Function()? clock,
    this.relockAfter = const Duration(minutes: 2),
    this.maxFailures = 5,
    bool observeLifecycle = true,
  }) : _store = store ?? SecurePasscodeStore(),
       _biometrics = biometrics ?? LocalBiometricGate(),
       _clock = clock ?? DateTime.now {
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(
        onHide: didHide,
        onShow: didShow,
        onResume: didShow,
      );
    }
  }

  final PasscodeStore _store;
  final BiometricGate _biometrics;
  final PasscodeHasher _hasher;
  final DateTime Function() _clock;
  AppLifecycleListener? _lifecycle;

  /// How long the app may sit in the background before the code is asked
  /// again. The user's choice, 2026-11-12: short trips out — picking a file,
  /// opening an attachment — must not lock; a real absence does.
  final Duration relockAfter;

  /// Wrong codes in a row that end the session. The user's choice,
  /// 2026-11-12. Four digits are ten thousand guesses; five tries is what
  /// keeps a found phone from being one of them.
  final int maxFailures;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  PasscodeHash? _hash;
  bool get hasPasscode => _hash != null;

  bool _unlocked = false;

  /// Past the lock for this visit.
  bool get isUnlocked => _unlocked;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  BiometricKind? _biometricKind;

  /// What the phone has enrolled right now, whether or not it was switched
  /// on here.
  BiometricKind? get biometricKind => _biometricKind;

  /// Switched on here *and* still enrolled on the phone.
  bool get canUseBiometric => _biometricEnabled && _biometricKind != null;

  int _failures = 0;
  int get failures => _failures;
  int get attemptsLeft => (maxFailures - _failures).clamp(0, maxFailures);

  String? _name;

  /// The given name to greet with, remembered from the last session.
  String? get name => _name;

  /// When the app was last hidden while unlocked.
  DateTime? _hiddenAt;

  bool _authenticating = false;

  /// Bumped by [forget]. At launch [load] and a "no token → signed out"
  /// [forget] race; a read that started before the wipe must not bring the
  /// wiped code back.
  int _epoch = 0;

  Future<void> load() async {
    final int epoch = _epoch;
    final PasscodeRecord read = await _store.read();
    final PasscodeRecord record = epoch == _epoch
        ? read
        : const PasscodeRecord();
    _hash = PasscodeHash.decode(record.hash);
    _biometricEnabled = record.biometricEnabled && _hash != null;
    _failures = _hash == null ? 0 : record.failures;
    _name = record.name;
    _unlocked = false;
    _loaded = true;
    notifyListeners();
    await refreshBiometrics();
  }

  /// Re-reads what the phone has enrolled. A fingerprint removed in Settings
  /// since the last launch quietly drops the shortcut; the code still works.
  Future<BiometricKind?> refreshBiometrics() async {
    final BiometricKind? kind = await _biometrics.available();
    if (kind != _biometricKind) {
      _biometricKind = kind;
      notifyListeners();
    }
    return kind;
  }

  /// Saves a newly chosen code. Does not unlock: the setup screen still has
  /// the biometric question to ask, and calls [unlock] when it is done.
  Future<void> setPasscode(String code) async {
    assert(isCompletePasscode(code));
    final PasscodeHash hash = await _hasher.create(code);
    // Side by side: each keystore write is a platform round trip, and the
    // person is watching four full dots until both are done.
    await Future.wait(<Future<void>>[
      _store.writeHash(hash.encode()),
      _store.writeFailures(0),
    ]);
    _hash = hash;
    _failures = 0;
    notifyListeners();
  }

  /// Checks a typed code. Counts the failures and, at [maxFailures], reports
  /// [PasscodeCheck.exhausted] — ending the session is the caller's job.
  Future<PasscodeCheck> check(String code) async {
    final PasscodeHash? hash = _hash;
    if (hash == null) return PasscodeCheck.wrong;
    if (await _hasher.matches(hash, code)) {
      if (_failures != 0) {
        _failures = 0;
        await _store.writeFailures(0);
      }
      notifyListeners();
      return PasscodeCheck.correct;
    }
    _failures += 1;
    await _store.writeFailures(_failures);
    notifyListeners();
    return _failures >= maxFailures
        ? PasscodeCheck.exhausted
        : PasscodeCheck.wrong;
  }

  /// Shows the phone's biometric prompt to get past the lock. True on a
  /// match; the caller then plays its success and calls [unlock].
  Future<bool> authenticateBiometric() => _prompt(
    reason: 'Güvən Finans-a daxil olmaq üçün təsdiqləyin',
    cancel: 'Kodla daxil ol',
  );

  /// Switches the shortcut on — only after the person has proved it works
  /// once, so a "yes" with a wet finger does not leave a broken shortcut.
  Future<bool> enableBiometric() async {
    final bool ok = await _prompt(
      reason: 'Sürətli giriş üçün təsdiqləyin',
      cancel: 'Ləğv et',
    );
    if (!ok) return false;
    _biometricEnabled = true;
    await _store.writeBiometric(true);
    notifyListeners();
    return true;
  }

  Future<bool> _prompt({required String reason, required String cancel}) async {
    if (_authenticating || _biometricKind == null) return false;
    _authenticating = true;
    try {
      return await _biometrics.authenticate(reason: reason, cancel: cancel);
    } finally {
      _authenticating = false;
    }
  }

  void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    _hiddenAt = null;
    notifyListeners();
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  /// Keeps the greeting's name current with the signed-in account.
  Future<void> rememberName(String? name) async {
    final String? next = (name == null || name.trim().isEmpty)
        ? null
        : name.trim();
    if (next == _name) return;
    _name = next;
    notifyListeners();
    await _store.writeName(next);
  }

  /// The session is over: the code, the shortcut and the count all go with
  /// it. The next sign-in sets a new code.
  Future<void> forget() async {
    _epoch++;
    _hash = null;
    _biometricEnabled = false;
    _failures = 0;
    _unlocked = false;
    _hiddenAt = null;
    notifyListeners();
    await _store.clear();
  }

  /// The app left the screen.
  @visibleForTesting
  void didHide() {
    if (_unlocked && hasPasscode) _hiddenAt ??= _clock();
  }

  /// The app is back. Locks if it was away for at least [relockAfter].
  @visibleForTesting
  void didShow() {
    final DateTime? hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || !_unlocked || !hasPasscode) return;
    if (_clock().difference(hiddenAt) >= relockAfter) lock();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}

/// Puts the [PasscodeController] in the tree, the way [SessionScope] does for
/// the session.
class PasscodeScope extends InheritedNotifier<PasscodeController> {
  const PasscodeScope({
    super.key,
    required PasscodeController controller,
    required super.child,
  }) : super(notifier: controller);

  static PasscodeController of(BuildContext context) {
    final PasscodeScope? scope = context
        .dependOnInheritedWidgetOfExactType<PasscodeScope>();
    assert(scope != null, 'No PasscodeScope above this widget.');
    return scope!.notifier!;
  }

  static PasscodeController read(BuildContext context) {
    final PasscodeScope? scope = context
        .getInheritedWidgetOfExactType<PasscodeScope>();
    assert(scope != null, 'No PasscodeScope above this widget.');
    return scope!.notifier!;
  }
}
