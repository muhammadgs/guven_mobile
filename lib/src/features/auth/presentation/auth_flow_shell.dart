import 'package:flutter/material.dart';

import '../../../features/onboarding/presentation/onboarding_screen.dart';
import '../../../shared/effects.dart';
import '../../../shared/widgets/auth_background.dart';

/// Root widget for the unauthenticated ("pre-login") flow.
///
/// Owns the single [AuthBackground] — the blurred looping video backdrop —
/// and drives all pre-login screens through a nested [Navigator]. Because the
/// background lives outside that Navigator, it persists unchanged as screens
/// are pushed or popped: no video restart, no flicker.
///
/// Screens to add later (login, register, OTP, …) simply `push` onto this
/// Navigator and inherit the background for free. When the user authenticates,
/// the root [MaterialApp] replaces this shell with the dashboard.
class AuthFlowShell extends StatefulWidget {
  const AuthFlowShell({super.key});

  @override
  State<AuthFlowShell> createState() => _AuthFlowShellState();
}

class _AuthFlowShellState extends State<AuthFlowShell> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      // Android's back button reaches the *root* navigator, which knows
      // nothing about the screens pushed here — without this, back on the
      // login screen closes the app instead of returning to the onboarding.
      // [NavigatorPopHandler] tracks whether this Navigator has anything to
      // pop and only intercepts when it does, so back at the onboarding still
      // leaves the app.
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (Object? result) => _navigator.currentState?.maybePop(),
        child: Navigator(
          key: _navigator,
          onGenerateRoute: (RouteSettings settings) {
            return PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (_, _, _) => const OnboardingScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                // When a screen is pushed on top (login), dissolve the whole
                // onboarding into blur, so nothing lingers under the incoming
                // screen. Runs in reverse on pop, re-materialising it.
                //
                // Gone by 42% of the push: the login card morphs out of the
                // start button (see GlassMorphRoute) and is still growing at
                // that point, so the page it grew from has to be out of the
                // way well before it lands.
                final CurvedAnimation cover = CurvedAnimation(
                  parent: secondaryAnimation,
                  curve:
                      const Interval(0.0, 0.42, curve: Curves.easeInOutCubic),
                );
                return AnimatedBuilder(
                  animation: cover,
                  child: child,
                  builder: (context, child) {
                    final double t = cover.value;
                    return Opacity(
                      opacity: 1 - t,
                      child: blurred(
                        16 * t,
                        Transform.scale(
                          scale: 1 + 0.03 * t,
                          child: child,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
