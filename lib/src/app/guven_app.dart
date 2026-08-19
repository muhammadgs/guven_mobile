import 'package:flutter/material.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/auth_flow_shell.dart';
import '../features/shell/presentation/main_shell.dart';
import 'app_theme.dart';

class GuvenApp extends StatefulWidget {
  const GuvenApp({super.key});

  @override
  State<GuvenApp> createState() => _GuvenAppState();
}

class _GuvenAppState extends State<GuvenApp> {
  /// Created here and never replaced: it owns the token store and the API
  /// client, so its lifetime is the app's.
  late final SessionController _session = SessionController()..restore();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: MaterialApp(
        title: 'Güvən Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        builder: _clampTextScale,
        home: const _RootFlow(),
      ),
    );
  }
}

/// Bounds the system font scale for the whole app.
///
/// Every surface here is a fixed-height glass shape sized against a phone
/// canvas: a pill, a lens, a bar. Left unbounded, a phone set to 200% type —
/// which Android 14 and One UI both reach, and which One UI applies
/// non-linearly, so the same setting is a different multiplier per device —
/// pushes text straight out of those shapes.
///
/// This one clamp replaces the `TextScaler.noScaling` that used to be written
/// on individual `Text` widgets. Pinning them one at a time meant a screen was
/// only ever as robust as its least-recently-edited label: the two that were
/// missed — the GF44 paragraph and the welcome headline — grew while the
/// widgets around them stayed put, which is what drove them into each other.
/// Bounding it once, here, cannot be forgotten on the next label added, and it
/// keeps 20% of real accessibility headroom instead of refusing the setting
/// outright.
Widget _clampTextScale(BuildContext context, Widget? child) {
  final MediaQueryData query = MediaQuery.of(context);
  return MediaQuery(
    data: query.copyWith(
      textScaler: query.textScaler.clamp(
        minScaleFactor: 1,
        maxScaleFactor: 1.2,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

/// Swaps the pre-login flow for the signed-in shell.
///
/// A swap rather than a route push, because the two are whole worlds: the auth
/// flow owns a looping video backdrop and its own nested navigator, the shell
/// owns the tab stack. Pushing one over the other would leave the video
/// decoding behind the dashboard for the rest of the session.
///
/// The swap is covered by a scrim that wipes off, and **not** by an
/// [AnimatedSwitcher]: its cross-fade is an [Opacity], an opacity layer is a
/// `saveLayer`, and a backdrop-sampling glass surface inside one has no
/// backdrop left to sample — the incoming shell's surfaces would cross-fade
/// in black.
/// A scrim painted as a sibling *above* the tree tints the same pixels without
/// ever wrapping them.
class _RootFlow extends StatefulWidget {
  const _RootFlow();

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<_RootFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wipe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  )..reverse();

  SessionStatus? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SessionStatus status = SessionScope.of(context).status;
    if (_shown != null && _shown != status) {
      // The new world is built underneath in the same frame; the scrim goes
      // straight back to opaque over it and then pulls off.
      _wipe.value = 1;
      _wipe.reverse();
    }
    _shown = status;
  }

  @override
  void dispose() {
    _wipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionStatus status = SessionScope.of(context).status;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        switch (status) {
          // The keystore read is fast enough that a spinner would only flash;
          // the platform launch screen is still up underneath.
          SessionStatus.restoring => const ColoredBox(color: _scrimColor),
          SessionStatus.signedOut => const AuthFlowShell(),
          SessionStatus.signedIn => const MainShell(),
        },
        AnimatedBuilder(
          animation: _wipe,
          builder: (BuildContext context, _) {
            final double t = Curves.easeOut.transform(_wipe.value);
            if (t <= 0.01) return const SizedBox.shrink();
            return IgnorePointer(
              // The alpha is animated on the colour itself. Wrapping this in
              // an `Opacity` would reintroduce exactly the layer the scrim
              // exists to avoid.
              child: ColoredBox(color: _scrimColor.withValues(alpha: t)),
            );
          },
        ),
      ],
    );
  }
}

/// The pale ground both worlds sit on, and what the swap wipes through.
const Color _scrimColor = Color(0xFFF2F7FE);
