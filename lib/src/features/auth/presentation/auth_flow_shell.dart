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
class AuthFlowShell extends StatelessWidget {
  const AuthFlowShell({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Navigator(
        onGenerateRoute: (RouteSettings settings) {
          return PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, _, _) => const OnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              // When a screen is pushed on top (login), dissolve the whole
              // onboarding into blur during the first half of that push, so
              // nothing lingers under the incoming screen. Runs in reverse
              // on pop, re-materialising the onboarding.
              final CurvedAnimation cover = CurvedAnimation(
                parent: secondaryAnimation,
                curve: const Interval(0.0, 0.55, curve: Curves.easeInOutCubic),
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
    );
  }
}
