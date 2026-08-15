import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app/guven_app.dart';
import 'src/shared/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockOrientation();

  runApp(const GuvenApp());
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
