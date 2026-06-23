import 'package:flutter/material.dart';

import '../features/splash/presentation/splash_screen.dart';
import 'app_theme.dart';

class GuvenApp extends StatelessWidget {
  const GuvenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Güvən Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: const SplashScreen(),
    );
  }
}