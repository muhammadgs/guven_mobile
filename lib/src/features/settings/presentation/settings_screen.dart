import 'package:flutter/material.dart';

import '../../auth/application/session_controller.dart';
import '../../home/presentation/widgets/home_glass.dart' show kGlassInk;
import '../domain/settings_category.dart';
import 'settings_metrics.dart';
import 'widgets/settings_pill.dart';

/// `Tənzimləmələr` — the app's settings, filed under categories.
///
/// Two levels under one fixed title. The first lists the categories as pills;
/// tapping one slides the list away and brings the category in, its name
/// under the title and its options under that. Back — Android's button or a
/// swipe in from the left edge — slides it out again.
///
/// Only `Hesab` exists so far, and in it only `Çıxış edin`, which ends the
/// session: the root flow then swaps the shell for the onboarding, the
/// app's first screen, where the login starts.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.bottomReserve,
    required this.active,
    this.onSignOut,
  });

  /// Vertical space the floating nav bar occupies.
  final double bottomReserve;

  /// Whether this is the tab on screen. The shell keeps every page alive, so
  /// without it Back on another tab would close a category here.
  final bool active;

  /// Stands in for the session's sign-out in the widget tests.
  @visibleForTesting
  final Future<void> Function()? onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  /// 0 on the category list, 1 inside [_category].
  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  /// The category open, or last open — kept while it slides out so it does
  /// not go blank on the way.
  SettingsCategory _category = SettingsCategory.account;

  /// True from the tap into a category until Back.
  bool _deep = false;

  bool _signingOut = false;

  @override
  void dispose() {
    _level.dispose();
    super.dispose();
  }

  void _enter(SettingsCategory category) {
    if (_deep) return;
    setState(() {
      _category = category;
      _deep = true;
    });
    _level.forward();
  }

  void _back() {
    if (!_deep || _signingOut) return;
    setState(() => _deep = false);
    _level.reverse();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      final Future<void> Function() signOut =
          widget.onSignOut ?? SessionScope.read(context).signOut;
      await signOut();
    } finally {
      // Normally this screen is gone by now — signing out drops the whole
      // shell — so this only matters if it is still here.
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsMetrics m = SettingsMetrics.of(context);
    final double s = m.scale;

    return PopScope<Object?>(
      canPop: !(widget.active && _deep),
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && widget.active && _deep) _back();
      },
      child: AnimatedBuilder(
        animation: _level,
        builder: (BuildContext context, _) {
          final double t = Curves.easeInOutCubic.transform(_level.value);
          // The list leaves to the left as the category comes in from the
          // right, a short way each: a push, not a page turn.
          final double travel = 28 * s;

          return Stack(
            children: <Widget>[
              Positioned(
                left: m.titleLeft,
                right: m.margin,
                top: m.titleTop,
                child: const _Title(),
              ),

              // ── first level: the categories ─────────────────────────────
              for (final SettingsCategory category in SettingsCategory.values)
                Positioned(
                  left: m.margin - travel * t,
                  width: m.pillWidth,
                  top: m.pillTop(m.categoriesTop, category.index),
                  child: IgnorePointer(
                    ignoring: _deep,
                    child: SettingsPill(
                      metrics: m,
                      label: category.title,
                      icon: category.icon,
                      // Measured off the design's `Hesab` row.
                      iconLeft: 26,
                      iconSize: const Size(24, 24),
                      labelLeft: 62.4,
                      fill: kSettingsPillFill,
                      ink: kGlassInk,
                      presence: 1 - t,
                      onTap: () => _enter(category),
                    ),
                  ),
                ),

              // ── second level: the open category ─────────────────────────
              if (t > 0) ...<Widget>[
                Positioned(
                  left: m.subtitleLeft + travel * (1 - t),
                  right: m.margin,
                  top: m.subtitleTop,
                  child: _Subtitle(text: _category.title, presence: t),
                ),
                ..._options(m, t, travel),
              ],

              // iOS has no Back button: a swipe in from the left edge does
              // what Android's does.
              if (_deep)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: widget.bottomReserve,
                  width: 22 * s,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (DragEndDetails details) {
                      if ((details.primaryVelocity ?? 0) > 200) _back();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _options(SettingsMetrics m, double t, double travel) {
    return switch (_category) {
      SettingsCategory.account => <Widget>[
        Positioned(
          left: m.margin + travel * (1 - t),
          width: m.pillWidth,
          top: m.pillTop(m.optionsTop, 0),
          child: IgnorePointer(
            ignoring: !_deep || _signingOut,
            child: SettingsPill(
              metrics: m,
              label: 'Çıxış edin',
              icon: kSettingsExitIcon,
              // Measured off the design's `Çıxış edin` row.
              iconLeft: 13.4,
              iconSize: const Size(18.8, 16.9),
              labelLeft: 48.2,
              fill: kSettingsExitFill,
              ink: kSettingsExitInk,
              presence: t,
              onTap: _signOut,
            ),
          ),
        ),
      ],
    };
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final double s = SettingsMetrics.of(context).scale;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        'Tənzimləmələr',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: kGlassInk,
          fontFamily: 'CalSans',
          fontSize: SettingsMetrics.titleSize * s,
          height: SettingsMetrics.titleLineHeight,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// The open category's name, under the title.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, required this.presence});

  final String text;
  final double presence;

  @override
  Widget build(BuildContext context) {
    final double s = SettingsMetrics.of(context).scale;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: kGlassInk.withValues(alpha: presence.clamp(0.0, 1.0)),
          fontFamily: 'CalSans',
          fontSize: SettingsMetrics.subtitleSize * s,
          height: SettingsMetrics.subtitleLineHeight,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
