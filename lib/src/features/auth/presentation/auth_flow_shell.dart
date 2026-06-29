import 'package:flutter/material.dart';

import '../../../features/onboarding/presentation/onboarding_screen.dart';
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
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
