import 'package:flutter/material.dart';

/// Accent choices: indigo (default), teal, orange, purple from AGENTS.md
/// section 14, plus pink. [light] and [darkFill] are button/avatar fills
/// (always with white text); [darkText] is the lighter tint used for links
/// and the active tab in dark mode.
class AccentOption {
  const AccentOption({
    required this.key,
    required this.light,
    required this.darkFill,
    required this.darkText,
  });

  final String key;
  final Color light;
  final Color darkFill;
  final Color darkText;
}

const accentOptions = <AccentOption>[
  AccentOption(
    key: 'indigo',
    light: Color(0xFF1C5D99),
    darkFill: Color(0xFF2E86C1),
    darkText: Color(0xFF8FD0F5),
  ),
  AccentOption(
    key: 'teal',
    light: Color(0xFF1F6F5C),
    darkFill: Color(0xFF2E8C75),
    darkText: Color(0xFF7ED8C3),
  ),
  AccentOption(
    key: 'orange',
    light: Color(0xFFA65A22),
    darkFill: Color(0xFFC4702E),
    darkText: Color(0xFFF4B77C),
  ),
  AccentOption(
    key: 'purple',
    light: Color(0xFF6B4C8A),
    darkFill: Color(0xFF8A6AA8),
    darkText: Color(0xFFD0B8E8),
  ),
  AccentOption(
    key: 'pink',
    light: Color(0xFFA33B5C),
    darkFill: Color(0xFFC25B7A),
    darkText: Color(0xFFF2A7BB),
  ),
];

/// Looks an accent up by its stored key; unknown keys fall back to indigo.
AccentOption accentByKey(String? key) => accentOptions.firstWhere(
  (option) => option.key == key,
  orElse: () => accentOptions.first,
);

abstract final class AppColors {
  /// Fixed badge colors picked when creating a subject. Each subject stores
  /// its own color, so these do not follow the theme accent.
  static const subjectBadges = <Color>[
    Color(0xFF1C5D99),
    Color(0xFF1F6F5C),
    Color(0xFFA65A22),
    Color(0xFF6B4C8A),
  ];
}

/// Every theme-dependent color (AGENTS.md section 14 design tokens).
/// Light and dark palettes carry their own status chip, deadline, and
/// overdue colors; only the accent follows the user's choice.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.deadlineText,
    required this.deadlineBg,
    required this.overdue,
    required this.draftText,
    required this.draftBg,
    required this.inProgressText,
    required this.inProgressBg,
    required this.finalText,
    required this.finalBg,
    required this.submittedText,
    required this.submittedBg,
  });

  final Color background;
  final Color card;
  final Color cardBorder;
  final Color text;
  final Color mutedText;

  /// Button fills and the avatar background; [onAccent] is its text color.
  final Color accent;

  /// Links, the active tab, rings, and marker dots; lighter in dark mode.
  final Color accentText;
  final Color onAccent;

  final Color deadlineText;
  final Color deadlineBg;
  final Color overdue;

  final Color draftText;
  final Color draftBg;
  final Color inProgressText;
  final Color inProgressBg;
  final Color finalText;
  final Color finalBg;
  final Color submittedText;
  final Color submittedBg;

  static AppPalette light(String accentKey) {
    final accent = accentByKey(accentKey);
    return AppPalette(
      background: const Color(0xFFF6F1E7),
      card: const Color(0xFFFFFCF6),
      cardBorder: const Color(0xFFD9D0BF),
      text: const Color(0xFF1B1A17),
      mutedText: const Color(0xFF6B665B),
      accent: accent.light,
      accentText: accent.light,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFF8A4E00),
      deadlineBg: const Color(0xFFF3E2C2),
      overdue: const Color(0xFFA92F24),
      draftText: const Color(0xFF5A574F),
      draftBg: const Color(0xFFECE7DC),
      inProgressText: const Color(0xFF1C5D99),
      inProgressBg: const Color(0xFFDDE9F2),
      finalText: const Color(0xFF25624F),
      finalBg: const Color(0xFFDDEBE3),
      submittedText: const Color(0xFF4E5A24),
      submittedBg: const Color(0xFFE7EBD5),
    );
  }

  static AppPalette dark(String accentKey) {
    final accent = accentByKey(accentKey);
    return AppPalette(
      background: const Color(0xFF111315),
      card: const Color(0xFF1A1D20),
      cardBorder: const Color(0xFF30353A),
      text: const Color(0xFFF3EEE3),
      mutedText: const Color(0xFFA8A196),
      accent: accent.darkFill,
      accentText: accent.darkText,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFFF0C98A),
      // The warm amber at 20% over the dark background.
      deadlineBg: const Color(0x33F3E2C2),
      overdue: const Color(0xFFFF9A8F),
      draftText: const Color(0xFFC9C3B8),
      draftBg: const Color(0x335A574F),
      inProgressText: const Color(0xFF8FD0F5),
      inProgressBg: const Color(0x331C5D99),
      finalText: const Color(0xFF7ED8C3),
      finalBg: const Color(0x3325624F),
      submittedText: const Color(0xFFC4D18A),
      submittedBg: const Color(0x334E5A24),
    );
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? cardBorder,
    Color? text,
    Color? mutedText,
    Color? accent,
    Color? accentText,
    Color? onAccent,
    Color? deadlineText,
    Color? deadlineBg,
    Color? overdue,
    Color? draftText,
    Color? draftBg,
    Color? inProgressText,
    Color? inProgressBg,
    Color? finalText,
    Color? finalBg,
    Color? submittedText,
    Color? submittedBg,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      onAccent: onAccent ?? this.onAccent,
      deadlineText: deadlineText ?? this.deadlineText,
      deadlineBg: deadlineBg ?? this.deadlineBg,
      overdue: overdue ?? this.overdue,
      draftText: draftText ?? this.draftText,
      draftBg: draftBg ?? this.draftBg,
      inProgressText: inProgressText ?? this.inProgressText,
      inProgressBg: inProgressBg ?? this.inProgressBg,
      finalText: finalText ?? this.finalText,
      finalBg: finalBg ?? this.finalBg,
      submittedText: submittedText ?? this.submittedText,
      submittedBg: submittedBg ?? this.submittedBg,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      card: mix(card, other.card),
      cardBorder: mix(cardBorder, other.cardBorder),
      text: mix(text, other.text),
      mutedText: mix(mutedText, other.mutedText),
      accent: mix(accent, other.accent),
      accentText: mix(accentText, other.accentText),
      onAccent: mix(onAccent, other.onAccent),
      deadlineText: mix(deadlineText, other.deadlineText),
      deadlineBg: mix(deadlineBg, other.deadlineBg),
      overdue: mix(overdue, other.overdue),
      draftText: mix(draftText, other.draftText),
      draftBg: mix(draftBg, other.draftBg),
      inProgressText: mix(inProgressText, other.inProgressText),
      inProgressBg: mix(inProgressBg, other.inProgressBg),
      finalText: mix(finalText, other.finalText),
      finalBg: mix(finalBg, other.finalBg),
      submittedText: mix(submittedText, other.submittedText),
      submittedBg: mix(submittedBg, other.submittedBg),
    );
  }
}

/// `context.palette` from any widget under the app's theme.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Campus-editorial design system: warm paper, ink text, serif headings,
/// monospaced labels, thin rules, and almost no elevation. The logo supplies
/// the default blue; the other accents are muted to sit on paper.
abstract final class AppTheme {
  static const double screenPadding = 22;
  static const double cardRadius = 6;
  static const double buttonRadius = 4;

  static const String serifFamily = 'serif';
  static const String monoFamily = 'monospace';

  static ThemeData light(String accentKey) =>
      _build(AppPalette.light(accentKey), Brightness.light);

  static ThemeData dark(String accentKey) =>
      _build(AppPalette.dark(accentKey), Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
          primary: palette.accent,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          secondary: palette.accentText,
          onSecondary: palette.onAccent,
          surface: palette.card,
          onSurface: palette.text,
          error: palette.overdue,
          onError: Colors.white,
          outline: palette.cardBorder,
        );

    final baseText = base.textTheme.apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    );

    TextStyle? asSerif(
      TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? letterSpacing,
      double? height,
    }) => style?.copyWith(
      fontFamily: serifFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );

    TextStyle? asMono(
      TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? letterSpacing,
      double? height,
    }) => style?.copyWith(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );

    final textTheme = baseText.copyWith(
      displayLarge: asSerif(
        baseText.displayLarge,
        size: 46,
        weight: FontWeight.w700,
        letterSpacing: -1.8,
        height: 0.98,
      ),
      displayMedium: asSerif(
        baseText.displayMedium,
        size: 38,
        weight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.0,
      ),
      displaySmall: asSerif(
        baseText.displaySmall,
        size: 32,
        weight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.04,
      ),
      headlineLarge: asSerif(
        baseText.headlineLarge,
        size: 30,
        weight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.08,
      ),
      headlineMedium: asSerif(
        baseText.headlineMedium,
        size: 26,
        weight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      headlineSmall: asSerif(
        baseText.headlineSmall,
        size: 23,
        weight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      titleLarge: asSerif(
        baseText.titleLarge,
        size: 21,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: asSerif(
        baseText.titleMedium,
        size: 17,
        weight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: asMono(
        baseText.titleSmall,
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12.5, height: 1.35),
      labelLarge: asMono(
        baseText.labelLarge,
        size: 12,
        weight: FontWeight.w600,
        letterSpacing: 0.45,
      ),
      labelMedium: asMono(
        baseText.labelMedium,
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 0.9,
      ),
      labelSmall: asMono(
        baseText.labelSmall,
        size: 10,
        weight: FontWeight.w600,
        letterSpacing: 0.9,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: palette.text, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: palette.text),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: palette.cardBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius + 2),
          side: BorderSide(color: palette.cardBorder),
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: palette.text),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.mutedText,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.cardBorder,
          disabledForegroundColor: palette.mutedText,
          minimumSize: const Size(64, 48),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            color: palette.onAccent,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(64, 44),
          side: BorderSide(color: palette.cardBorder),
          textStyle: textTheme.labelLarge?.copyWith(
            color: palette.text,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentText,
          textStyle: textTheme.labelLarge?.copyWith(
            color: palette.accentText,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.mutedText),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.accentText, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: palette.overdue),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.accent.withValues(alpha: 0.12),
        disabledColor: palette.card,
        side: BorderSide(color: palette.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: palette.accentText,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: palette.cardBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accentText,
        linearTrackColor: palette.cardBorder,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accentText,
        selectionColor: palette.accent.withValues(alpha: 0.22),
        selectionHandleColor: palette.accent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: palette.accent.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.accentText
                : palette.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? palette.accentText
                : palette.mutedText,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.mutedText,
        textColor: palette.text,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.mutedText,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.text,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.background,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      extensions: [palette],
    );
  }
}
