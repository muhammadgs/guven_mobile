import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/auth/application/session_controller.dart';
import 'package:guven_mobile/src/features/passcode/application/passcode_controller.dart';
import 'package:guven_mobile/src/features/passcode/data/biometric_gate.dart';
import 'package:guven_mobile/src/features/passcode/data/passcode_store.dart';
import 'package:guven_mobile/src/features/passcode/domain/passcode_greeting.dart';
import 'package:guven_mobile/src/features/passcode/domain/passcode_hash.dart';
import 'package:guven_mobile/src/features/passcode/presentation/passcode_metrics.dart';
import 'package:guven_mobile/src/features/passcode/presentation/passcode_screen.dart';

const MethodChannel _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// The passcode lock: its layout across the phones the app ships to, the
/// hash, the rules (attempts, relock, biometric opt-in) and both screens
/// driven by taps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  group('metrics', () {
    const List<_Device> devices = <_Device>[
      _Device(
        'iPhone 16 Pro',
        Size(402, 874),
        EdgeInsets.only(top: 62, bottom: 34),
      ),
      _Device('iPhone SE', Size(320, 568), EdgeInsets.only(top: 20)),
      _Device(
        'S23 Ultra gesture',
        Size(384, 824),
        EdgeInsets.only(top: 32, bottom: 24),
      ),
      _Device(
        'S23 Ultra 3-button',
        Size(384, 824),
        EdgeInsets.only(top: 32, bottom: 48),
      ),
      _Device(
        'S23 gesture',
        Size(360, 780),
        EdgeInsets.only(top: 30, bottom: 24),
      ),
      _Device(
        'S23 3-button',
        Size(360, 780),
        EdgeInsets.only(top: 30, bottom: 48),
      ),
      _Device('Android, no inset', Size(412, 915), EdgeInsets.only(top: 52)),
      _Device(
        '16:9 phone',
        Size(360, 640),
        EdgeInsets.only(top: 24, bottom: 48),
      ),
      _Device(
        'tall 21:9',
        Size(360, 900),
        EdgeInsets.only(top: 40, bottom: 24),
      ),
      _Device(
        'iPad 11"',
        Size(834, 1194),
        EdgeInsets.only(top: 24, bottom: 20),
      ),
      _Device(
        'iPad 11" landscape',
        Size(1194, 834),
        EdgeInsets.only(top: 24, bottom: 20),
      ),
    ];

    for (final _Device device in devices) {
      for (final double fontScale in <double>[1.0, 1.2]) {
        testWidgets('${device.name} @ ${fontScale}x — nothing collides', (
          WidgetTester tester,
        ) async {
          final PasscodeMetrics m = await _metrics(tester, device, fontScale);
          final double ts = fontScale;
          final double floor =
              device.size.height -
              (device.padding.bottom > 0 ? device.padding.bottom : 0);

          expect(
            m.compositionTop,
            greaterThan(device.padding.top),
            reason: 'the title starts below the status bar',
          );
          expect(
            m.compositionBottom,
            lessThan(floor),
            reason: 'the 0 key ends above the bottom inset',
          );

          // Title (descenders ~0.3em) above the subtitle's ascenders.
          final double titleBottom = m.titleBaseline + m.welcomeSize * ts * 0.3;
          final double subtitleTop =
              m.subtitleBaseline - m.subtitleSize * ts * 0.8;
          expect(
            subtitleTop,
            greaterThan(titleBottom),
            reason: 'the subtitle clears the title',
          );

          final double subtitleBottom =
              m.subtitleBaseline + m.subtitleSize * ts * 0.3;
          expect(
            m.dotsRect.top,
            greaterThan(subtitleBottom),
            reason: 'the dots clear the subtitle',
          );
          expect(
            m.keypadRect.top,
            greaterThan(m.dotsRect.bottom),
            reason: 'the keypad clears the dots',
          );

          expect(
            m.columnPitch,
            greaterThan(m.keyDiameter),
            reason: 'keys in a row do not touch',
          );
          expect(
            m.rowPitch,
            greaterThan(m.keyDiameter),
            reason: 'keys in a column do not touch',
          );
          expect(m.keypadRect.left, greaterThan(0));
          expect(m.keypadRect.right, lessThan(device.size.width));
          expect(m.titleMaxWidth, greaterThan(200));

          // The biometric question, built on the keypad's grid.
          expect(m.biometricDisc.top, greaterThan(subtitleBottom));
          expect(m.biometricAccept.top, greaterThan(m.biometricDisc.bottom));
          expect(
            m.biometricDecline.center.dy,
            greaterThan(m.biometricAccept.bottom),
          );
          expect(m.biometricDecline.center.dy, lessThan(floor));
        });
      }
    }

    testWidgets('on the design frame the numbers are the design\'s', (
      WidgetTester tester,
    ) async {
      final PasscodeMetrics m = await _metrics(
        tester,
        const _Device(
          'frame',
          Size(402, 874),
          EdgeInsets.only(top: 62, bottom: 34),
        ),
        1,
      );
      expect(m.scale, closeTo(1, 1e-9));
      expect(m.keyDiameter, closeTo(70.5, 1e-9));
      // Key centres measured off the export: 108.25 / 200.75 / 293.25 across,
      // 421.25 down for the first row, 93.75pt a row.
      expect(m.keyCenter(0, 0).dx, closeTo(108.5, 0.6));
      expect(m.keyCenter(0, 2).dx, closeTo(293.5, 0.6));
      expect(m.keyCenter(0, 1).dy, closeTo(421.25, 0.6));
      expect(m.keyCenter(3, 1).dy, closeTo(702.5, 0.6));
      expect(m.dotsCenter.dy, closeTo(358.75, 0.6));
      expect(m.titleBaseline, closeTo(270.75, 0.6));
      expect(m.subtitleBaseline, closeTo(301, 0.6));
    });
  });

  group('hash', () {
    test('matches only its own code, and survives a round trip', () {
      final PasscodeHash hash = PasscodeHash.create('2580', iterations: 50);
      expect(hash.matches('2580'), isTrue);
      expect(hash.matches('2581'), isFalse);
      final PasscodeHash? back = PasscodeHash.decode(hash.encode());
      expect(back, isNotNull);
      expect(back!.matches('2580'), isTrue);
      expect(back.iterations, 50);
      expect(hash.encode(), isNot(contains('2580')));
    });

    test('two hashes of one code differ (salted)', () {
      final PasscodeHash a = PasscodeHash.create('1111', iterations: 10);
      final PasscodeHash b = PasscodeHash.create('1111', iterations: 10);
      expect(a.encode(), isNot(b.encode()));
    });

    test('garbage does not decode', () {
      expect(PasscodeHash.decode(null), isNull);
      expect(PasscodeHash.decode('1234'), isNull);
      expect(PasscodeHash.decode('v1:x:abc:def'), isNull);
    });

    test('only four digits are a complete code', () {
      expect(isCompletePasscode('0912'), isTrue);
      expect(isCompletePasscode('091'), isFalse);
      expect(isCompletePasscode('09a2'), isFalse);
    });
  });

  group('greeting', () {
    String at(int hour) => passcodeGreeting(DateTime(2026, 11, 12, hour, 30));

    test('follows the phone\'s clock', () {
      expect(at(5), 'Sabahınız xeyir');
      expect(at(11), 'Sabahınız xeyir');
      expect(at(12), 'Hər vaxtınız xeyir');
      expect(at(17), 'Hər vaxtınız xeyir');
      expect(at(18), 'Axşamınız xeyir');
      expect(at(22), 'Axşamınız xeyir');
      expect(at(23), 'Gecəniz xeyir');
      expect(at(0), 'Gecəniz xeyir');
      expect(at(4), 'Gecəniz xeyir');
    });

    test('carries the name, or stands without one', () {
      expect(passcodeWelcomeLine('Məhəmməd'), 'Xoş Gəldiniz, Məhəmməd.');
      expect(passcodeWelcomeLine(null), 'Xoş Gəldiniz.');
      expect(
        passcodeGreetingLine(DateTime(2026, 1, 1, 9), 'Məhəmməd'),
        'Sabahınız xeyir, Məhəmməd.',
      );
    });
  });

  group('controller', () {
    test('a set code checks, counts failures and gives up at five', () async {
      final MemoryPasscodeStore store = MemoryPasscodeStore();
      final PasscodeController lock = _controller(store: store);
      await lock.load();
      expect(lock.hasPasscode, isFalse);

      await lock.setPasscode('4321');
      expect(lock.hasPasscode, isTrue);
      expect(store.record.hash, isNot(contains('4321')));

      expect(await lock.check('1111'), PasscodeCheck.wrong);
      expect(lock.attemptsLeft, 4);
      expect(await lock.check('4321'), PasscodeCheck.correct);
      expect(lock.failures, 0, reason: 'a right code resets the count');

      for (int i = 0; i < 4; i++) {
        expect(await lock.check('0000'), PasscodeCheck.wrong);
      }
      expect(await lock.check('0000'), PasscodeCheck.exhausted);
      lock.dispose();
    });

    test('the count survives a restart', () async {
      final MemoryPasscodeStore store = MemoryPasscodeStore();
      final PasscodeController first = _controller(store: store);
      await first.load();
      await first.setPasscode('1357');
      await first.check('0000');
      await first.check('0000');
      first.dispose();

      final PasscodeController second = _controller(store: store);
      await second.load();
      expect(second.hasPasscode, isTrue);
      expect(second.isUnlocked, isFalse, reason: 'every launch starts locked');
      expect(second.failures, 2);
      second.dispose();
    });

    test('relocks after two minutes away, not after a short trip', () async {
      DateTime now = DateTime(2026, 11, 12, 10);
      final PasscodeController lock = _controller(clock: () => now);
      await lock.load();
      await lock.setPasscode('1234');
      lock.unlock();

      lock.didHide();
      now = now.add(const Duration(seconds: 90));
      lock.didShow();
      expect(lock.isUnlocked, isTrue, reason: 'a file picker is not absence');

      lock.didHide();
      now = now.add(const Duration(minutes: 2));
      lock.didShow();
      expect(lock.isUnlocked, isFalse);
      lock.dispose();
    });

    test('biometrics switch on only after a successful prompt', () async {
      final _FakeBiometrics bio = _FakeBiometrics(BiometricKind.fingerprint);
      final MemoryPasscodeStore store = MemoryPasscodeStore();
      final PasscodeController lock = _controller(store: store, bio: bio);
      await lock.load();
      await lock.setPasscode('1234');

      bio.answer = false;
      expect(await lock.enableBiometric(), isFalse);
      expect(lock.canUseBiometric, isFalse);

      bio.answer = true;
      expect(await lock.enableBiometric(), isTrue);
      expect(lock.canUseBiometric, isTrue);
      expect(store.record.biometricEnabled, isTrue);
      lock.dispose();
    });

    test('forget wipes everything', () async {
      final MemoryPasscodeStore store = MemoryPasscodeStore();
      final PasscodeController lock = _controller(store: store);
      await lock.load();
      await lock.setPasscode('1234');
      await lock.rememberName('Məhəmməd');
      await lock.forget();
      expect(lock.hasPasscode, isFalse);
      expect(store.record.hash, isNull);
      expect(store.record.name, isNull);
      lock.dispose();
    });

    test(
      'a read that started before forget does not bring the code back',
      () async {
        final PasscodeHash old = PasscodeHash.create('1234', iterations: 8);
        final _SlowStore store = _SlowStore(PasscodeRecord(hash: old.encode()));
        final PasscodeController lock = _controller(store: store);
        final Future<void> loading = lock.load();
        await lock.forget();
        store.release();
        await loading;
        expect(lock.isLoaded, isTrue);
        expect(lock.hasPasscode, isFalse);
        lock.dispose();
      },
    );
  });

  group('screens', () {
    testWidgets('setup: choose, confirm, done', (WidgetTester tester) async {
      final PasscodeController lock = _controller();
      await lock.load();
      await _pumpScreen(tester, lock, PasscodeScreenMode.setup);

      expect(find.text('Xoş Gəldiniz.'), findsOneWidget);
      expect(
        find.text('Təhlükəsizlik üçün giriş kodu təyin edin.'),
        findsOneWidget,
      );

      await _type(tester, '2468');
      expect(
        find.text('Kodu təsdiqləmək üçün yenidən daxil edin.'),
        findsOneWidget,
      );
      expect(lock.hasPasscode, isFalse, reason: 'nothing saved before confirm');

      await _type(tester, '2468');
      await tester.pump(const Duration(milliseconds: 600));
      expect(lock.hasPasscode, isTrue);
      expect(
        lock.isUnlocked,
        isTrue,
        reason: 'no biometrics on this phone, so setup ends here',
      );
      expect(await lock.check('2468'), PasscodeCheck.correct);
      lock.dispose();
    });

    testWidgets('setup: a mismatch starts over', (WidgetTester tester) async {
      final PasscodeController lock = _controller();
      await lock.load();
      await _pumpScreen(tester, lock, PasscodeScreenMode.setup);

      await _type(tester, '1111');
      await _type(tester, '2222');
      expect(
        find.text('Kodlar uyğun gəlmədi. Yenidən təyin edin.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(lock.hasPasscode, isFalse);

      await _type(tester, '3');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Təhlükəsizlik üçün giriş kodu təyin edin.'),
        findsOneWidget,
        reason: 'typing again goes back to the instruction',
      );
      lock.dispose();
    });

    testWidgets('setup: asks for the fingerprint when the phone has one', (
      WidgetTester tester,
    ) async {
      final _FakeBiometrics bio = _FakeBiometrics(BiometricKind.fingerprint);
      final PasscodeController lock = _controller(bio: bio);
      await lock.load();
      await _pumpScreen(tester, lock, PasscodeScreenMode.setup);

      await _type(tester, '1234');
      await _type(tester, '1234');
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.text('Barmaq izi ilə daxil olmaq istəyirsiniz?'),
        findsOneWidget,
      );
      expect(lock.isUnlocked, isFalse);

      await tester.tap(find.text('İndi yox'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(lock.isUnlocked, isTrue);
      expect(lock.canUseBiometric, isFalse);
      lock.dispose();
    });

    testWidgets('unlock: a wrong code says how many tries are left', (
      WidgetTester tester,
    ) async {
      final PasscodeController lock = _controller();
      await lock.load();
      await lock.setPasscode('9876');
      await _pumpScreen(tester, lock, PasscodeScreenMode.unlock);

      expect(find.textContaining('xeyir'), findsOneWidget);
      expect(find.text('Daxil ola\nbilmirəm'), findsOneWidget);

      await _type(tester, '0000');
      expect(find.text('Kod yanlışdır. 4 cəhd qaldı.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));

      await _type(tester, '9876');
      await tester.pump(const Duration(milliseconds: 600));
      expect(lock.isUnlocked, isTrue);
      // This session never finishes restoring: the lock says so instead of
      // dropping onto a blank screen.
      expect(find.text('Hesab yüklənir…'), findsOneWidget);
      lock.dispose();
    });

    testWidgets('unlock: Sil removes the last digit', (
      WidgetTester tester,
    ) async {
      final PasscodeController lock = _controller();
      await lock.load();
      await lock.setPasscode('1212');
      await _pumpScreen(tester, lock, PasscodeScreenMode.unlock);

      await _type(tester, '19');
      await tester.tap(find.text('Sil'));
      await tester.pump(const Duration(milliseconds: 200));
      await _type(tester, '212');
      await tester.pump(const Duration(milliseconds: 600));
      expect(lock.isUnlocked, isTrue);
      lock.dispose();
    });
  });
}

PasscodeController _controller({
  MemoryPasscodeStore? store,
  BiometricGate? bio,
  DateTime Function()? clock,
}) => PasscodeController(
  store: store ?? MemoryPasscodeStore(),
  biometrics: bio ?? _FakeBiometrics(null),
  hasher: const PasscodeHasher.inline(),
  clock: clock,
  observeLifecycle: false,
);

Future<void> _pumpScreen(
  WidgetTester tester,
  PasscodeController lock,
  PasscodeScreenMode mode,
) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final SessionController session = SessionController();
  addTearDown(session.dispose);
  await tester.pumpWidget(
    SessionScope(
      controller: session,
      child: PasscodeScope(
        controller: lock,
        child: MaterialApp(
          home: Material(
            color: const Color(0xFF1B5A80),
            child: PasscodeScreen(mode: mode),
          ),
        ),
      ),
    ),
  );
  // Let the entry finish.
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Taps each digit's key and lets the dots react.
Future<void> _type(WidgetTester tester, String digits) async {
  for (final String d in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(d).last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
  }
  // The fourth digit's fill, the check, the step change.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<PasscodeMetrics> _metrics(
  WidgetTester tester,
  _Device device,
  double fontScale,
) async {
  late PasscodeMetrics m;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: device.size,
        padding: device.padding,
        textScaler: TextScaler.linear(fontScale),
      ),
      child: Builder(
        builder: (BuildContext context) {
          m = PasscodeMetrics.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return m;
}

class _Device {
  const _Device(this.name, this.size, this.padding);
  final String name;
  final Size size;
  final EdgeInsets padding;
}

/// A keystore whose first read hangs until [release] — the launch race
/// between `load()` and a signed-out `forget()`.
class _SlowStore extends MemoryPasscodeStore {
  _SlowStore(super.record);

  final Completer<void> _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<PasscodeRecord> read() async {
    final PasscodeRecord snapshot = record;
    await _gate.future;
    return snapshot;
  }
}

class _FakeBiometrics implements BiometricGate {
  _FakeBiometrics(this.kind);

  final BiometricKind? kind;
  bool answer = true;

  @override
  Future<BiometricKind?> available() async => kind;

  @override
  Future<bool> authenticate({
    required String reason,
    required String cancel,
  }) async => answer;
}
