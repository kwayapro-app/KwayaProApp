import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightOnPrimary,
        primaryContainer: AppColors.lightPrimaryContainer,
        onPrimaryContainer: AppColors.lightOnPrimaryContainer,
        secondary: AppColors.lightSecondary,
        onSecondary: AppColors.lightOnSecondary,
        secondaryContainer: AppColors.lightSecondaryContainer,
        onSecondaryContainer: AppColors.lightOnSecondaryContainer,
        tertiary: AppColors.lightTertiary,
        onTertiary: AppColors.lightOnTertiary,
        tertiaryContainer: AppColors.lightTertiaryContainer,
        onTertiaryContainer: AppColors.lightOnTertiaryContainer,
        error: AppColors.lightError,
        onError: AppColors.lightOnError,
        errorContainer: AppColors.lightErrorContainer,
        onErrorContainer: AppColors.lightOnErrorContainer,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightOnSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.lightOnSurface,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
      ),
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkOnSecondary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,
        tertiary: AppColors.darkTertiary,
        onTertiary: AppColors.darkOnTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        onTertiaryContainer: AppColors.darkOnTertiaryContainer,
        error: AppColors.darkError,
        onError: AppColors.darkOnError,
        errorContainer: AppColors.darkErrorContainer,
        onErrorContainer: AppColors.darkOnErrorContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurfaceVariant: AppColors.darkOnSurface,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
      ),
    );
  }

  static ThemeData _buildTheme({required ColorScheme colorScheme}) {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    
    // Customizing text styles with correct weights
    // Display/Headline: 800-900 (ExtraBold/Black)
    // Title: 800 (ExtraBold)
    // Body: 600 (SemiBold)
    // Label: 800 (ExtraBold), typically capitalized in UI
    final customTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface),
      displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurface),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: customTextTheme,
      
      // Sizing/Shape rule: Cards default corner = 24dp
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
      ),

      // Sizing/Shape rule: FAB default corner = 16dp
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
      ),

      // Sizing/Shape rule: Chips default corner = 8dp
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: colorScheme.surfaceContainerHighest,
        disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: customTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),

      // Sizing/Shape rule: Buttons = pill shape (50dp), min height 48dp
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          minimumSize: const Size.fromHeight(48),
          textStyle: customTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colorScheme.outline, width: 2),
          textStyle: customTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          minimumSize: const Size.fromHeight(48),
          textStyle: customTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      // Sizing/Shape rule: Dialog 28dp corner radius
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: colorScheme.surface,
        elevation: 6,
      ),

      // Sizing/Shape rule: Bottom sheet design
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 8,
      ),
    );
  }
}
