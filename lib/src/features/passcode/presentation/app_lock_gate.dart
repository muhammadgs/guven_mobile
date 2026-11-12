import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/auth_background.dart';
import '../../auth/application/session_controller.dart';
import '../application/passcode_controller.dart';
import 'passcode_metrics.dart';
import 'passcode_screen.dart';

/// Status-bar icon colours only — the navigation bar is hidden natively and
/// its fields are left alone (`SystemUiOverlayStyle.light` would paint it).
const SystemUiOverlayStyle _kLightStatusIcons = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);
const SystemUiOverlayStyle _kDarkStatusIcons = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// What the lock is showing.
enum _LockView {
  none,

  /// Signed in, but the keystore has not been read yet: the video alone, so
  /// the dashboard never flashes before the lock knows whether to ask.
  blank,
  setup,
  unlock,
}

/// What the app under the lock needs to know about it.
@immutable
class AppLockState {
  const AppLockState({
    required this.covered,
    required this.holdAuth,
    required this.shellActive,
  });

  static const AppLockState open = AppLockState(
    covered: false,
    holdAuth: false,
    shellActive: true,
  );

  /// The lock hides the app completely: the shell need not paint.
  final bool covered;

  /// The lock is fading in over the login screen; keep the login world on
  /// screen under it until it is opaque.
  final bool holdAuth;

  /// Nothing of the lock is left on screen: the shell may start what it
  /// starts on arrival — the attendance reminder, for one.
  final bool shellActive;
}

class AppLockScope extends InheritedWidget {
  const AppLockScope({super.key, required this.state, required super.child});

  final AppLockState state;

  static AppLockState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.state ??
      AppLockState.open;

  @override
  bool updateShouldNotify(AppLockScope oldWidget) =>
      oldWidget.state.covered != state.covered ||
      oldWidget.state.holdAuth != state.holdAuth ||
      oldWidget.state.shellActive != state.shellActive;
}

/// The passcode lock, laid over the whole app.
///
/// It lives in `MaterialApp.builder` — *above* the navigator — so nothing the
/// app has pushed (a card, a sheet, a reminder) can sit on top of it.
///
/// Three transitions:
/// * **Signed in → set a code.** The lock's video fades in over the login
///   screen's identical video (one shared player), so the login card simply
///   dissolves and the keypad blooms in its place.
/// * **Right code → dashboard.** A hole opens in the lock from the dots and
///   grows past the corners, the dashboard settling from a slight zoom
///   underneath, a soft bright ring riding the edge.
/// * **Back after a while away → locked.** Instantly, with no animation —
///   the dashboard must not be seen first.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );

  _LockView _shown = _LockView.none;
  bool _revealing = false;
  bool _overAuth = false;
  SessionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _enter.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && _overAuth) {
        setState(() => _overAuth = false);
      }
    });
    _reveal.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _revealing = false;
          _shown = _LockView.none;
          _reveal.value = 0;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _enter.dispose();
    _reveal.dispose();
    super.dispose();
  }

  _LockView _target(SessionController session, PasscodeController lock) {
    switch (session.status) {
      case SessionStatus.signedOut:
        return _LockView.none;
      case SessionStatus.restoring:
        // A code on disk means a session was left signed in: ask for it
        // straight away, while `/auth/me` is still confirming the token —
        // and stay up, right code or not, until it has. Under the lock is
        // only the blank restoring screen, for up to the API's 20 s when
        // the server is slow; the reveal waits for the dashboard.
        return lock.isLoaded && lock.hasPasscode
            ? _LockView.unlock
            : _LockView.none;
      case SessionStatus.signedIn:
        if (!lock.isLoaded) return _LockView.blank;
        if (lock.isUnlocked) return _LockView.none;
        return lock.hasPasscode ? _LockView.unlock : _LockView.setup;
    }
  }

  /// Moves [_shown] towards what the session and the lock call for.
  void _sync() {
    final SessionController session = SessionScope.of(context);
    final PasscodeController lock = PasscodeScope.of(context);
    final SessionStatus status = session.status;
    final SessionStatus? previous = _lastStatus;
    _lastStatus = status;
    final _LockView target = _target(session, lock);

    if (target == _LockView.none) {
      if (_shown == _LockView.none || _revealing) return;
      if (status == SessionStatus.signedIn && lock.isUnlocked) {
        // The right code (or face) — open onto the dashboard.
        _revealing = true;
        _reveal.forward(from: 0);
      } else {
        // Signed out from under the lock. The login world below shows the
        // same video frame, so dropping the lock is seamless.
        _shown = _LockView.none;
      }
      return;
    }

    if (_revealing) {
      // Locked again mid-reveal (it can only be a very quick trip away).
      _revealing = false;
      _reveal.value = 0;
    }

    // Setup is latched: saving the code makes `hasPasscode` true halfway
    // through it, which must not swap the welcome screen for the lock.
    if (_shown == _LockView.setup && target == _LockView.unlock) return;
    if (_shown == target) return;

    final bool wasHidden = _shown == _LockView.none;
    _shown = target;
    if (wasHidden &&
        previous == SessionStatus.signedOut &&
        status == SessionStatus.signedIn) {
      _overAuth = true;
      _enter.forward(from: 0);
    } else if (wasHidden) {
      _overAuth = false;
      _enter.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt by the scopes above; `_sync` has already run for this frame.
    final bool showing = _shown != _LockView.none;
    final AppLockState state = AppLockState(
      covered: showing && !_revealing && !_overAuth,
      holdAuth: showing && _overAuth,
      shellActive: !showing,
    );

    return AppLockScope(
      state: state,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_enter, _reveal]),
        builder: (BuildContext context, _) {
          final double r = Curves.easeInOutCubic.transform(_reveal.value);
          final PasscodeMetrics metrics = PasscodeMetrics.of(context);
          final Size screen = MediaQuery.sizeOf(context);
          final Offset center = metrics.dotsCenter;
          final double far = _farthestCorner(center, screen);
          final double radius = far * r;

          // The app's own status-bar icons, by its theme. Without this the
          // lock's white icons would outlive it over the light dashboard:
          // the system keeps the last style until someone sets another. A
          // region deeper in the app (none yet) still wins over this one.
          final SystemUiOverlayStyle appBar =
              Theme.of(context).brightness == Brightness.dark
              ? _kLightStatusIcons
              : _kDarkStatusIcons;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: appBar,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // The app. While the hole opens it settles from a slight zoom.
                Transform.scale(
                  scale: _revealing ? lerpDouble(1.06, 1, r)! : 1,
                  child: widget.child,
                ),
                if (showing)
                  IgnorePointer(
                    ignoring: _revealing,
                    child: ClipPath(
                      clipper: _HoleClipper(center: center, radius: radius),
                      // No clip at all until the hole opens — a clip layer
                      // over the whole lock for nothing is still a layer.
                      clipBehavior: _revealing ? Clip.antiAlias : Clip.none,
                      child: _LockWorld(
                        view: _shown,
                        videoOpacity: Curves.easeOut.transform(_enter.value),
                      ),
                    ),
                  ),
                if (_revealing && radius > 0)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RingPainter(
                        center: center,
                        radius: radius,
                        strength: 1 - r,
                        width: 2.4 * metrics.scale,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _farthestCorner(Offset c, Size s) {
    double best = 0;
    for (final Offset corner in <Offset>[
      Offset.zero,
      Offset(s.width, 0),
      Offset(0, s.height),
      Offset(s.width, s.height),
    ]) {
      best = math.max(best, (corner - c).distance);
    }
    // A little past the corner, so the soft ring is off screen at the end.
    return best + 24;
  }
}

/// The lock's own world: the shared video and the passcode screen on it.
class _LockWorld extends StatelessWidget {
  const _LockWorld({required this.view, required this.videoOpacity});

  final _LockView view;
  final double videoOpacity;

  @override
  Widget build(BuildContext context) {
    // White status-bar icons over the dark video, as in the design. The lock
    // is the top layer, so its region wins over the app's; while the hole
    // opens, the clip hands the status bar back once it has passed the top.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _kLightStatusIcons,
      child: Material(
        type: MaterialType.transparency,
        child: AuthBackground(
          videoOpacity: videoOpacity,
          child: switch (view) {
            _LockView.setup => const PasscodeScreen(
              key: ValueKey<_LockView>(_LockView.setup),
              mode: PasscodeScreenMode.setup,
            ),
            _LockView.unlock => const PasscodeScreen(
              key: ValueKey<_LockView>(_LockView.unlock),
              mode: PasscodeScreenMode.unlock,
            ),
            // Absorbs taps meant for the app underneath while the lock
            // decides.
            _LockView.blank || _LockView.none => const SizedBox.expand(),
          },
        ),
      ),
    );
  }
}

/// Everything except a circle — the lock with a hole in it.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    final Path path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    if (radius > 0) {
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    }
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}

/// A soft bright ring on the hole's edge, fading as it travels out.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.center,
    required this.radius,
    required this.strength,
    required this.width,
  });

  final Offset center;
  final double radius;
  final double strength;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final double a = strength.clamp(0.0, 1.0);
    if (a <= 0) return;
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 4
      ..color = Colors.white.withValues(alpha: 0.28 * a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 3);
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = Colors.white.withValues(alpha: 0.7 * a);
    canvas.drawCircle(center, radius, glow);
    canvas.drawCircle(center, radius, edge);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.strength != strength ||
      old.width != width;
}
