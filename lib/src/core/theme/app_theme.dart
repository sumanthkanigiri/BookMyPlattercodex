import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF3C1285);
  static const _gold = Color(0xFFF5B300);

  static ThemeData get light {
    final generated = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
    );
    final scheme = generated.copyWith(
      primary: _primary,
      secondary: _gold,
      surface: Colors.white,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFFAF9FD),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: 7),
        elevation: 3,
        shadowColor: Color(0x263C1285),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final generated = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
    );
    final scheme = generated.copyWith(
      primary: const Color(0xFFD8C1FF),
      secondary: _gold,
      surface: const Color(0xFF17111F),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF100B17),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: 7),
        elevation: 0,
        color: Color(0xFF1F1729),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
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
