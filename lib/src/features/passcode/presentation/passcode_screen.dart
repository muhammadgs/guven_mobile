import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/glass/app_glass.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../application/passcode_controller.dart';
import '../data/biometric_gate.dart';
import '../domain/passcode_greeting.dart';
import '../domain/passcode_hash.dart';
import 'passcode_metrics.dart';
import 'passcode_style.dart';
import 'widgets/passcode_dots.dart';
import 'widgets/passcode_key.dart';
import 'widgets/passcode_text.dart';

/// Which of the two designs is on screen.
enum PasscodeScreenMode {
  /// First screen after signing in: `Xoş Gəldiniz` → choose a code → type it
  /// again → (if the phone has one) switch on Face ID / fingerprint.
  setup,

  /// Every later launch: `Sabahınız xeyir` → the code, or the biometric.
  unlock,
}

enum _SetupStep { create, confirm, biometric }

/// The passcode screen. It draws no background — it sits on the lock's video
/// (`AppLockGate`) — and it ends by calling [PasscodeController.unlock]; the
/// gate then opens onto the dashboard.
class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key, required this.mode});

  final PasscodeScreenMode mode;

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with TickerProviderStateMixin {
  /// Entry: the title sharpens out of a blur, the dots and keys bloom.
  /// Played backwards on the way out to the login screen.
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    reverseDuration: const Duration(milliseconds: 560),
  )..forward();

  /// The biometric question replacing the keypad (setup only).
  late final AnimationController _question = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  String _entered = '';
  String? _first;
  _SetupStep _step = _SetupStep.create;

  /// Shown in the subtitle's place: a mismatch, a wrong code, attempts left.
  String? _message;

  /// True while a code is being checked or the screen is on its way out —
  /// the keypad ignores input.
  bool _busy = false;
  bool _finished = false;

  int _shakeTick = 0;
  int _pulseTick = 0;

  /// Dots shown full regardless of [_entered] — a biometric unlock fills them.
  bool _forceFull = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PasscodeScreenMode.unlock) {
      // Offer the biometric as soon as the screen has landed, the way the
      // phone's own lock screen does. A cancel just leaves the keypad.
      Future<void>.delayed(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        final PasscodeController lock = PasscodeScope.read(context);
        if (lock.canUseBiometric) unawaited(_biometricUnlock());
      });
    }
  }

  @override
  void dispose() {
    _appear.dispose();
    _question.dispose();
    super.dispose();
  }

  bool get _setup => widget.mode == PasscodeScreenMode.setup;

  // ── Input ─────────────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_busy || _finished || _entered.length >= kPasscodeLength) return;
    setState(() {
      _entered += digit;
      // During setup a fresh attempt clears "Kodlar uyğun gəlmədi" back to
      // the instruction. On the lock the attempts-left line stays up while
      // the next try is typed — it is the thing worth knowing.
      if (_setup) _message = null;
    });
    if (_entered.length == kPasscodeLength) {
      // Let the fourth dot finish filling before anything reacts to it.
      _busy = true;
      Future<void>.delayed(const Duration(milliseconds: 160), _complete);
    }
  }

  void _onDelete() {
    if (_busy || _finished || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _complete() async {
    if (!mounted) return;
    final String code = _entered;
    if (_setup) {
      await _completeSetup(code);
    } else {
      await _completeUnlock(code);
    }
  }

  Future<void> _completeSetup(String code) async {
    final PasscodeController lock = PasscodeScope.read(context);
    if (_step == _SetupStep.create) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      setState(() {
        _first = code;
        _entered = '';
        _message = null;
        _step = _SetupStep.confirm;
        _busy = false;
      });
      return;
    }

    if (code != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _shakeTick++;
        _message = 'Kodlar uyğun gəlmədi. Yenidən təyin edin.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 560));
      if (!mounted) return;
      setState(() {
        _entered = '';
        _first = null;
        _step = _SetupStep.create;
        _busy = false;
      });
      return;
    }

    await lock.setPasscode(code);
    if (!mounted) return;
    setState(() => _pulseTick++);
    final BiometricKind? kind = await lock.refreshBiometrics();
    if (!mounted) return;
    if (kind == null) {
      await _finish();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _step = _SetupStep.biometric;
      _message = null;
    });
    await _question.forward();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _completeUnlock(String code) async {
    final PasscodeController lock = PasscodeScope.read(context);
    final PasscodeCheck result = await lock.check(code);
    if (!mounted) return;
    switch (result) {
      case PasscodeCheck.correct:
        await _finish();
      case PasscodeCheck.wrong:
        HapticFeedback.heavyImpact();
        final int left = lock.attemptsLeft;
        setState(() {
          _shakeTick++;
          _message = left == 1
              ? 'Kod yanlışdır. Son cəhd qaldı.'
              : 'Kod yanlışdır. $left cəhd qaldı.';
        });
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
        setState(() {
          _entered = '';
          _busy = false;
        });
      case PasscodeCheck.exhausted:
        HapticFeedback.heavyImpact();
        setState(() {
          _shakeTick++;
          _finished = true;
          _message =
              'Kod ${lock.maxFailures} dəfə yanlış yazıldı. Hesabdan çıxılır…';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1700));
        if (!mounted) return;
        await _leave();
    }
  }

  Future<void> _biometricUnlock() async {
    if (_busy || _finished) return;
    final PasscodeController lock = PasscodeScope.read(context);
    if (!lock.canUseBiometric) return;
    _busy = true;
    final bool ok = await lock.authenticateBiometric();
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _forceFull = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _finish();
  }

  Future<void> _acceptBiometric() async {
    if (_busy || _finished) return;
    final PasscodeController lock = PasscodeScope.read(context);
    _busy = true;
    final bool ok = await lock.enableBiometric();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _message = 'Təsdiqlənmədi. Yenidən yoxlayın və ya «İndi yox» seçin.';
      });
      return;
    }
    await _finish();
  }

  Future<void> _declineBiometric() async {
    if (_busy || _finished) return;
    await _finish();
  }

  /// Every dot swells at once, and the gate takes over.
  Future<void> _finish() async {
    if (_finished) return;
    final PasscodeController lock = PasscodeScope.read(context);
    setState(() {
      _finished = true;
      _busy = true;
      _pulseTick++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    lock.unlock();
  }

  /// "Daxil ola bilmirəm": straight out of the account, to sign in again
  /// and set a new code.
  Future<void> _cannotSignIn() async {
    if (_finished) return;
    setState(() {
      _finished = true;
      _busy = true;
    });
    await _leave();
  }

  /// Signs out. The screen folds itself away at once — signing out waits on
  /// `/auth/logout`, up to five seconds offline — and the lock lifts when
  /// the session has ended, onto the same video the login flow plays.
  Future<void> _leave() async {
    final SessionController session = SessionScope.read(context);
    unawaited(_appear.reverse());
    await session.signOut();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PasscodeController lock = PasscodeScope.of(context);
    final SessionController session = SessionScope.of(context);
    final AuthUser? user = session.user;
    final String? name = _nameOf(user) ?? lock.name;
    // The right code is in, but the session is still being confirmed with
    // the server: the lock stays up (see AppLockGate) and says why.
    final bool waiting =
        _finished &&
        lock.isUnlocked &&
        session.status == SessionStatus.restoring;
    final PasscodeMetrics m = PasscodeMetrics.of(context);

    final String title = _setup
        ? passcodeWelcomeLine(name)
        : passcodeGreetingLine(DateTime.now(), name);
    final double titleSize = _setup ? m.welcomeSize : m.greetingSize;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_appear, _question]),
      builder: (BuildContext context, _) {
        final double t = _appear.value;
        final double q = Curves.easeInOutCubic.transform(_question.value);
        final bool asking = _step == _SetupStep.biometric;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _Reveal(
              progress: _interval(t, 0, 0.5),
              child: PasscodeBaselineText(
                text: title,
                style: passcodeTitleStyle(titleSize),
                baseline: m.titleBaseline,
                maxWidth: m.titleMaxWidth,
              ),
            ),
            _Subtitle(
              metrics: m,
              text: waiting ? 'Hesab yüklənir…' : _subtitle(lock),
              appear: _interval(t, 0.08, 0.55),
            ),
            PasscodeDots(
              metrics: m,
              filled: _forceFull ? kPasscodeLength : _entered.length,
              shakeTick: _shakeTick,
              pulseTick: _pulseTick,
              appear: _interval(t, 0.14, 0.62) * (1 - q),
            ),
            ..._keys(m, t, q),
            ..._bottomRow(m, lock, t, q),
            if (asking || q > 0) ..._biometricQuestion(m, lock, q),
          ],
        );
      },
    );
  }

  String? _subtitle(PasscodeController lock) {
    final String? message = _message;
    if (message != null) return message;
    if (!_setup) return null;
    return switch (_step) {
      _SetupStep.create => 'Təhlükəsizlik üçün giriş kodu təyin edin.',
      _SetupStep.confirm => 'Kodu təsdiqləmək üçün yenidən daxil edin.',
      _SetupStep.biometric =>
        '${(lock.biometricKind ?? BiometricKind.generic).withPhrase} '
            'daxil olmaq istəyirsiniz?',
    };
  }

  /// The ten digits: 1–9 in three rows, 0 in the middle of the fourth.
  List<Widget> _keys(PasscodeMetrics m, double t, double q) {
    final List<Widget> keys = <Widget>[];
    for (int n = 0; n < 10; n++) {
      final int row = n == 0 ? 3 : (n - 1) ~/ 3;
      final int column = n == 0 ? 1 : (n - 1) % 3;
      // Rows land one after another, the outer columns a beat after the
      // middle; they leave in the opposite order for the biometric question.
      final double start = 0.24 + row * 0.07 + (column - 1).abs() * 0.035;
      final double inT = _interval(t, start, start + 0.42);
      final double outStart = (3 - row) * 0.09 + (column - 1).abs() * 0.04;
      final double outT = _interval(q, outStart, outStart + 0.55);
      keys.add(
        PasscodeKey(
          key: ValueKey<int>(n),
          metrics: m,
          digit: '$n',
          rect: m.keyRect(row, column),
          onDigit: _onDigit,
          appear: inT * (1 - outT),
        ),
      );
    }
    return keys;
  }

  List<Widget> _bottomRow(
    PasscodeMetrics m,
    PasscodeController lock,
    double t,
    double q,
  ) {
    final double row = _interval(t, 0.45, 0.9) * (1 - q);
    final TextStyle label = passcodeSideLabelStyle(
      m.sideLabelSize,
      PasscodeMetrics.sideLabelLineHeight,
    );
    final bool showBiometric =
        !_setup && _entered.isEmpty && !_forceFull && lock.canUseBiometric;
    // Gone once the code is accepted — nothing is left to correct, and it
    // would otherwise sit there through "Hesab yüklənir…".
    final bool showDelete = _entered.isNotEmpty && !_forceFull && !_finished;

    return <Widget>[
      if (!_setup)
        PasscodeTextKey(
          rect: m.cellRect(3, 0),
          visible: row,
          semanticLabel: 'Daxil ola bilmirəm',
          onTap: _finished ? null : _cannotSignIn,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Daxil ola\nbilmirəm',
              textAlign: TextAlign.center,
              style: label,
            ),
          ),
        ),
      PasscodeTextKey(
        rect: m.cellRect(3, 2),
        visible: showBiometric ? row : 0,
        semanticLabel: (lock.biometricKind ?? BiometricKind.generic).withPhrase,
        onTap: _biometricUnlock,
        child: Icon(
          (lock.biometricKind?.isFace ?? false)
              ? Icons.face_unlock_outlined
              : Icons.fingerprint_rounded,
          size: 34 * m.scale,
        ),
      ),
      PasscodeTextKey(
        rect: m.cellRect(3, 2),
        visible: showDelete ? row : 0,
        semanticLabel: 'Sil',
        onTap: _onDelete,
        child: Text('Sil', style: label),
      ),
    ];
  }

  List<Widget> _biometricQuestion(
    PasscodeMetrics m,
    PasscodeController lock,
    double q,
  ) {
    final BiometricKind kind = lock.biometricKind ?? BiometricKind.generic;
    final double disc = _interval(q, 0.35, 0.85);
    final double accept = _interval(q, 0.5, 1);
    final double decline = _interval(q, 0.62, 1);
    final Rect acceptRect = m.biometricAccept;
    final double grow = Curves.easeOutBack.transform(accept);

    return <Widget>[
      Positioned.fromRect(
        rect: m.biometricDisc,
        child: disc <= 0.01
            ? const SizedBox.shrink()
            : Transform.scale(
                scale: Curves.easeOutBack.transform(disc),
                child: Semantics(
                  button: true,
                  label: kind.withPhrase,
                  excludeSemantics: true,
                  child: AppGlassButton(
                    style: kPasscodeKeyGlass,
                    cornerRadius: m.biometricDisc.shortestSide / 2,
                    splashColor: kPasscodeKeySplash,
                    onTap: _acceptBiometric,
                    child: Center(
                      child: Icon(
                        kind.isFace
                            ? Icons.face_unlock_outlined
                            : Icons.fingerprint_rounded,
                        size: 52 * m.scale,
                        color: Colors.white.withValues(alpha: disc),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      Positioned.fromRect(
        rect: acceptRect,
        child: grow <= 0.01
            ? const SizedBox.shrink()
            : Transform.scale(
                scale: grow,
                child: Semantics(
                  button: true,
                  label: 'Aktivləşdir',
                  excludeSemantics: true,
                  child: AppGlassButton(
                    style: kPasscodeAcceptGlass,
                    cornerRadius: acceptRect.height / 2,
                    onTap: _acceptBiometric,
                    child: Center(
                      child: Text(
                        'Aktivləşdir',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: m.sideLabelSize,
                          color: kPasscodeInk.withValues(alpha: accept),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
      PasscodeTextKey(
        rect: m.biometricDecline,
        visible: decline,
        semanticLabel: 'İndi yox',
        onTap: _declineBiometric,
        child: Text(
          'İndi yox',
          style: passcodeSideLabelStyle(
            m.sideLabelSize,
            PasscodeMetrics.sideLabelLineHeight,
          ),
        ),
      ),
    ];
  }

  static String? _nameOf(AuthUser? user) {
    if (user == null) return null;
    final String name = user.greetingName;
    return name == 'İstifadəçi' ? null : name;
  }
}

/// [value]'s progress through [begin]–[end], clamped to 0–1.
double _interval(double value, double begin, double end) =>
    ((value - begin) / (end - begin)).clamp(0.0, 1.0);

/// Sharpens text in out of a blur as [progress] goes 0 → 1.
///
/// Text only: an `ImageFiltered` / `Opacity` over glass would black it out,
/// and nothing passed here holds any.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.progress, required this.child});

  final double progress;

  /// A [Positioned] — it is unwrapped so the filter goes inside it.
  final PasscodeBaselineText child;

  @override
  Widget build(BuildContext context) {
    final double t = Curves.easeOutCubic.transform(progress);
    if (t >= 1) return child;
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 10 * (1 - t),
              sigmaY: 10 * (1 - t),
            ),
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - t)),
              child: Stack(fit: StackFit.expand, children: <Widget>[child]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the title: instructions during setup, messages during
/// unlock. A new line sharpens in as the old one blurs out.
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.metrics,
    required this.text,
    required this.appear,
  });

  final PasscodeMetrics metrics;
  final String? text;
  final double appear;

  @override
  Widget build(BuildContext context) {
    final PasscodeMetrics m = metrics;
    final TextStyle style = passcodeSubtitleStyle(m.subtitleSize);
    final double above = m.subtitleSize * 3;
    final String? line = text;
    final double t = Curves.easeOutCubic.transform(appear);

    return Positioned(
      left: 0,
      right: 0,
      top: m.subtitleBaseline - above,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (BuildContext context, Widget? child) {
                  final double v = animation.value;
                  return Opacity(
                    opacity: v,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 6 * (1 - v),
                        sigmaY: 6 * (1 - v),
                      ),
                      child: child,
                    ),
                  );
                },
              );
            },
            child: line == null
                ? SizedBox(key: const ValueKey<String>(''), height: above)
                : Baseline(
                    key: ValueKey<String>(line),
                    baseline: above,
                    baselineType: TextBaseline.alphabetic,
                    child: Center(
                      child: Text(
                        line,
                        style: fitTextStyle(
                          context,
                          line,
                          style,
                          m.titleMaxWidth,
                        ),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
