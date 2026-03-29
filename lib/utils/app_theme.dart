import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const String themeModePreferenceKey = 'app_theme_mode';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

class AppPalette {
  static const Color ink = Color(0xFF0B1220);
  static const Color inkSoft = Color(0xFF111827);
  static const Color surface = Color(0xFFF4F5F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentWarm = Color(0xFFF59E0B);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color darkSurface = Color(0xFF08111F);
  static const Color darkSurfaceRaised = Color(0xFF101B2D);
  static const Color darkCard = Color(0xFF142033);
  static const Color darkCardSoft = Color(0xFF19263A);
  static const Color darkOutline = Color(0xFF243247);
  static const Color darkText = Color(0xFFE5EEF8);
  static const Color darkTextSoft = Color(0xFF94A3B8);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF07101E), Color(0xFF0C1627), Color(0xFF152338)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.accent,
      brightness: Brightness.light,
    );
    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppPalette.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppPalette.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppPalette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.accent, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.inkSoft,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          foregroundColor: AppPalette.inkSoft,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFFE2E8F0),
        selectedColor: const Color(0xFFDBEAFE),
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppPalette.ink,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.ink,
        contentTextStyle: GoogleFonts.manrope(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.ink;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.accent.withAlpha((0.45 * 255).round());
          }
          return Colors.grey.shade300;
        }),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.accent,
      brightness: Brightness.dark,
      surface: AppPalette.darkCard,
    );
    final textTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(
        surface: AppPalette.darkCard,
        primary: AppPalette.accent,
        secondary: AppPalette.accentWarm,
        onSurface: AppPalette.darkText,
        outline: AppPalette.darkOutline,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppPalette.darkText,
        displayColor: AppPalette.darkText,
      ),
      scaffoldBackgroundColor: AppPalette.darkSurface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.darkText,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppPalette.darkText,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppPalette.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkSurfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.accent, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.darkTextSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: AppPalette.ink,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.darkText,
          side: const BorderSide(color: AppPalette.darkOutline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          foregroundColor: AppPalette.darkText,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppPalette.darkSurfaceRaised,
        selectedColor: const Color(0xFF15324F),
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppPalette.darkText,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.darkOutline),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppPalette.darkCard,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppPalette.darkTextSoft,
        selectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.darkCardSoft,
        contentTextStyle: GoogleFonts.manrope(color: AppPalette.darkText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.accent;
          return AppPalette.darkText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.accent.withAlpha((0.35 * 255).round());
          }
          return AppPalette.darkOutline;
        }),
      ),
    );
  }

  static ThemeMode parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }

  static String themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
