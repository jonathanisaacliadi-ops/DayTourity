import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forestGreen      = Color(0xFF2E7D32);
  static const forestGreenDark  = Color(0xFF1B5E20);
  static const forestGreenLight = Color(0xFF4CAF50);
  static const moss             = Color(0xFF558B2F);
  static const mossLight        = Color(0xFF8BC34A);
  static const earthBrown       = Color(0xFF5D4037);

  static const offWhite         = Color(0xFFF5F7F5);
  static const surface          = Color(0xFFFFFFFF);
  static const surfaceVariant   = Color(0xFFF0F4F0);
  static const border           = Color(0xFFAFC6AF);

  static const darkBackground     = Color(0xFF121A13);
  static const darkSurface        = Color(0xFF1E2B1F);
  static const darkSurfaceVariant = Color(0xFF2A3D2B);
  static const onDark             = Color(0xFFE8F5E9);

  static const error      = Color(0xFFD32F2F);
  static const errorLight = Color(0xFFEF5350);

  static const accentGlow          = forestGreenLight;
  static const darkOverlay         = Color(0xFF1A2B1C);
  static const darkSurfaceElevated = Color(0xFF243325);
  static const onDarkMuted         = Color(0xFF7A9E7E);
  static const onDarkSubtle        = Color(0xFFB0C8B0);
  static const budgetColor         = Color(0xFF0D9488);
  static const standardColor       = forestGreen;
  static const premiumColor        = Color(0xFFD97706);

}

abstract final class AppRadius {
  static const double sm   = 12;
  static const double md   = 16;
  static const double lg   = 24;
  static const double pill = 100;
}

abstract final class AppTheme {
  static ThemeData get lightNatureTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary:            AppColors.forestGreen,
      onPrimary:          Colors.white,
      primaryContainer:   Color(0xFFD6EED6),
      onPrimaryContainer: AppColors.forestGreenDark,
      secondary:          AppColors.moss,
      onSecondary:        Colors.white,
      secondaryContainer: Color(0xFFDCEDC8),
      onSecondaryContainer: AppColors.forestGreenDark,
      tertiary:           AppColors.earthBrown,
      onTertiary:         Colors.white,
      error:              AppColors.error,
      onError:            Colors.white,
      surface:            AppColors.surface,
      onSurface:          Color(0xFF111B13),
      surfaceContainerHighest: AppColors.surfaceVariant,
      outline:            AppColors.border,
      outlineVariant:     AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.offWhite,
      fontFamily: 'Outfit',
      textTheme: _buildTextTheme(colorScheme),
      inputDecorationTheme: _buildInputTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.border,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: .5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
  
  static ThemeData get darkNatureTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary:            AppColors.forestGreenLight,
      onPrimary:          AppColors.darkBackground,
      primaryContainer:   AppColors.forestGreenDark,
      onPrimaryContainer: AppColors.onDark,
      secondary:          AppColors.mossLight,
      onSecondary:        AppColors.darkBackground,
      secondaryContainer: AppColors.moss,
      onSecondaryContainer: AppColors.onDark,
      tertiary:           AppColors.earthBrown,
      onTertiary:         AppColors.offWhite,
      error:              AppColors.errorLight,
      onError:            AppColors.darkBackground,
      surface:            AppColors.darkSurface,
      onSurface:          AppColors.onDark,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      outline:            AppColors.moss,
      outlineVariant:     AppColors.forestGreenDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _buildTextTheme(colorScheme),
      inputDecorationTheme: _buildInputTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.forestGreenDark),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme scheme) => TextTheme(
        displayLarge:  TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: scheme.onSurface, letterSpacing: -0.25),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: scheme.onSurface),
        headlineMedium:TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: scheme.onSurface),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
        titleLarge:    TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
        titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface, letterSpacing: 0.1),
        titleSmall:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface),
        bodyLarge:     TextStyle(fontSize: 16, color: scheme.onSurface, letterSpacing: 0.3),
        bodyMedium:    TextStyle(fontSize: 14, color: scheme.onSurface, letterSpacing: 0.2),
        bodySmall:     TextStyle(fontSize: 12, color: scheme.onSurface),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface),
      );

  static InputDecorationTheme _buildInputTheme(ColorScheme scheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? AppColors.surfaceVariant
            : AppColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
        hintStyle:  TextStyle(color: scheme.onSurface.withOpacity(0.35)),
        prefixIconColor: scheme.primary,
      );

  static ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme scheme) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorScheme scheme) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      );

  static TextButtonThemeData _buildTextButtonTheme(ColorScheme scheme) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      );
}