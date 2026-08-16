import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'src/app/guven_app.dart';
import 'src/shared/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockOrientation();
  await _warmUpGlassShaders();

  runApp(const GuvenApp());
}

/// Compiles the liquid-glass fragment programs before the first frame.
///
/// A lens loads them lazily in its own `initState`, which means the very first
/// build paints the frosted (blur + tint) fallback and only refracts one frame
/// later — visible as a flash on the start button. Failure is not fatal: the
/// lens keeps working, it just stays on the fallback.
Future<void> _warmUpGlassShaders() async {
  try {
    await LiquidGlassShaders.ensureLoaded();
  } catch (_) {
    // Unsupported engine or a broken asset bundle — nothing to do here.
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
