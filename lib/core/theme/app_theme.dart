import 'package:flutter/material.dart';

class AppTheme {
  // Brand palette
  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF11182A);
  static const card = Color(0xFF161F36);
  static const border = Color(0xFF22304C);
  static const borderLight = Color(0xFF2E3F63);
  static const muted = Color(0xFF9AA8C2);
  static const textPrimary = Color(0xFFF1F5F9);
  static const accent = Color(0xFF8B9CFF);
  static const accentDark = Color(0xFF6B7DFE);

  // Status indicators
  static const statusCreated = Color(0xFF94A3B8);
  static const statusPlanning = Color(0xFFA78BFA);
  static const statusRunning = Color(0xFF60A5FA);
  static const statusWaiting = Color(0xFFFBBF24);
  static const statusCompleted = Color(0xFF34D399);
  static const statusFailed = Color(0xFFF87171);

  // Agent role badges
  static Color agentColor(String agent) {
    switch (agent.toLowerCase().trim()) {
      case 'planner':
        return const Color(0xFFA78BFA);
      case 'researcher':
        return const Color(0xFF38BDF8);
      case 'developer':
        return const Color(0xFF818CF8);
      case 'coder':
        return const Color(0xFF2DD4BF);
      case 'tester':
        return const Color(0xFF34D399);
      case 'reviewer':
        return const Color(0xFFFB923C);
      default:
        return accent;
    }
  }

  static IconData agentIcon(String agent) {
    switch (agent.toLowerCase().trim()) {
      case 'planner':
        return Icons.psychology_outlined;
      case 'researcher':
        return Icons.search_rounded;
      case 'developer':
        return Icons.code_rounded;
      case 'coder':
        return Icons.terminal_rounded;
      case 'tester':
        return Icons.verified_outlined;
      case 'reviewer':
        return Icons.rate_review_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  static Color statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s.contains('fail') || s.contains('error')) return statusFailed;
    if (s.contains('complet') || s.contains('success') || s == 'healthy') return statusCompleted;
    if (s.contains('wait') || s.contains('approv')) return statusWaiting;
    if (s.contains('run') || s.contains('progress')) return statusRunning;
    if (s.contains('plan')) return statusPlanning;
    return statusCreated;
  }

  static Color priorityColor(String priority) {
    switch (priority.toLowerCase().trim()) {
      case 'critical':
        return statusFailed;
      case 'high':
        return const Color(0xFFFB923C);
      case 'medium':
        return const Color(0xFF60A5FA);
      case 'low':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF60A5FA);
    }
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
