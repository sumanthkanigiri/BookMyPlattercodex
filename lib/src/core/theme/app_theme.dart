import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    final generated = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3C1285),
      brightness: Brightness.light,
    );
    final scheme = generated.copyWith(
      primary: const Color(0xFF3C1285),
      secondary: const Color(0xFFF5B300),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF9FD),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: 7),
        elevation: 3,
        shadowColor: Color(0x263C1285),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
