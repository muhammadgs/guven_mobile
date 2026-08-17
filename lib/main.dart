import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app/guven_app.dart';
import 'src/shared/glass/app_glass.dart';
import 'src/shared/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockOrientation();
  await _warmUpGlassShaders();

  runApp(const GuvenApp());
}

/// Performs any startup work the glass backends require.
///
/// The renderer loads its shaders through its own widget pipeline.
/// `liquid_glass_easy` benefits from eager loading, and the nav bar's
/// travelling indicator uses it on every run, so the adapter warms it whether
/// or not the app-wide rollback flag is set.
Future<void> _warmUpGlassShaders() async {
  try {
    await warmUpAppGlassShaders();
  } catch (_) {
    // Unsupported engine or a broken asset bundle — both backends can fall
    // back to frosted glass.
  }
}

/// Phones are portrait-only: the onboarding pages reserve fixed vertical space
/// for the indicator stack, which landscape leaves no room for. Tablets are
/// tall enough in either direction, and iPadOS expects an app to rotate.
Future<void> _lockOrientation() async {
  final ui.FlutterView view =
      WidgetsBinding.instance.platformDispatcher.views.first;
  final double shortestSide =
      view.physicalSize.shortestSide / view.devicePixelRatio;

  await SystemChrome.setPreferredOrientations(
    shortestSide >= kTabletBreakpoint
        ? DeviceOrientation.values
        : const <DeviceOrientation>[DeviceOrientation.portraitUp],
  );
}
