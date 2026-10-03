import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFFFF5722);
  static const _primaryBright = Color(0xFFFF6B3D);

  static ThemeData dark() => _base(Brightness.dark).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          secondary: _primaryBright,
          surface: Color(0xFF1E1E22),
          onSurface: Color(0xFFF6F4F2),
        ),
        cardColor: const Color(0xFF1E1E22),
        dividerColor: const Color(0x14FFFFFF),
      );

  static ThemeData light() => _base(Brightness.light).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F1EE),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD83D0C),
          secondary: Color(0xFFEC4B18),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF11100F),
        ),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0x24191614),
      );

  static ThemeData _base(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          indicatorColor: _primary.withValues(alpha: 0.14),
        ),
      );
}

class ThemeNotifier extends ChangeNotifier {
  bool isLight = false;
  void toggle() {
    isLight = !isLight;
    notifyListeners();
  }
}
