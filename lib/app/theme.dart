import 'package:flutter/material.dart';

/// Accent choices: indigo (default), teal, orange, and purple. [light] and
/// [darkFill] are button/avatar fills
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
    light: Color(0xFF2077BD),
    darkFill: Color(0xFF2077BD),
    darkText: Color(0xFF70B7F0),
  ),
  AccentOption(
    key: 'teal',
    light: Color(0xFF0B7A6B),
    darkFill: Color(0xFF0B7A6B),
    darkText: Color(0xFF4CC7B1),
  ),
  AccentOption(
    key: 'orange',
    light: Color(0xFFB4530A),
    darkFill: Color(0xFFB4530A),
    darkText: Color(0xFFFFA24D),
  ),
  AccentOption(
    key: 'purple',
    light: Color(0xFF7A3FB5),
    darkFill: Color(0xFF7A3FB5),
    darkText: Color(0xFFC89AF0),
  ),
];

/// Looks an accent up by its stored key; unknown keys fall back to indigo.
AccentOption accentByKey(String? key) => accentOptions.firstWhere(
  (option) => option.key == key,
  orElse: () => accentOptions.first,
);

abstract final class AppColors {
  static const navy = Color(0xFF12307F);
  static const brandBlue = Color(0xFF2077BD);
  static const sky = Color(0xFF55ABEE);
  static const cardShadow = Color(0x1412307F);

  /// Fixed badge colors picked when creating a subject. Each subject stores
  /// its own color, so these do not follow the theme accent.
  static const subjectBadges = <Color>[
    Color(0xFF3B4BDB),
    Color(0xFF0B7A6B),
    Color(0xFFB4530A),
    Color(0xFF7A3FB5),
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
    required this.overdueBg,
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
  final Color overdueBg;

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
      background: const Color(0xFFF3F7FD),
      // The design background is slightly blue to keep white cards distinct.
      card: const Color(0xFFFFFFFF),
      cardBorder: const Color(0xFFE1E8F3),
      text: const Color(0xFF0E1B3D),
      mutedText: const Color(0xFF566686),
      accent: accent.light,
      accentText: accent.light,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFF9A5B00),
      deadlineBg: const Color(0xFFFFF0DC),
      overdue: const Color(0xFFB42318),
      overdueBg: const Color(0xFFFDE8E6),
      draftText: const Color(0xFF475569),
      draftBg: const Color(0xFFE8EDF5),
      inProgressText: const Color(0xFF9A4B00),
      inProgressBg: const Color(0xFFFFF0DC),
      finalText: const Color(0xFF1B4FB8),
      finalBg: const Color(0xFFE3EDFF),
      submittedText: const Color(0xFF0B6B4F),
      submittedBg: const Color(0xFFDDF5EA),
    );
  }

  static AppPalette dark(String accentKey) {
    final accent = accentByKey(accentKey);
    return AppPalette(
      background: const Color(0xFF0B1226),
      card: const Color(0xFF141C36),
      cardBorder: const Color(0xFF27325A),
      text: const Color(0xFFEDF1FB),
      mutedText: const Color(0xFFA3AFCC),
      accent: accent.darkFill,
      accentText: accent.darkText,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFFFFC56A),
      deadlineBg: const Color(0x33FFB547),
      overdue: const Color(0xFFFF8E86),
      overdueBg: const Color(0x33B42318),
      draftText: const Color(0xFFC4CEE3),
      draftBg: const Color(0x33475569),
      inProgressText: const Color(0xFFFFB66E),
      inProgressBg: const Color(0x339A4B00),
      finalText: const Color(0xFF91B7FF),
      finalBg: const Color(0x331B4FB8),
      submittedText: const Color(0xFF75D7B5),
      submittedBg: const Color(0x330B6B4F),
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
    Color? overdueBg,
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
      overdueBg: overdueBg ?? this.overdueBg,
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
      overdueBg: mix(overdueBg, other.overdueBg),
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

abstract final class AppTheme {
  static const double screenPadding = 20;
  static const double cardRadius = 20;
  static const double buttonRadius = 16;
  static const String fontFamily = 'Plus Jakarta Sans';

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
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.onAccent,
          secondary: palette.accentText,
          onSecondary: palette.onAccent,
          surface: palette.card,
          onSurface: palette.text,
          error: palette.overdue,
          onError: palette.onAccent,
          outline: palette.cardBorder,
        );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: palette.text,
        displayColor: palette.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: AppColors.navy.withValues(alpha: 0.08),
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
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentText,
          minimumSize: const Size(64, 44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          side: BorderSide(color: palette.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.accentText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: palette.mutedText),
        labelStyle: TextStyle(color: palette.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.accentText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.overdue),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accentText,
        linearTrackColor: palette.cardBorder,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: palette.accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? palette.accentText
                : palette.mutedText,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.accentText
                : palette.mutedText,
          ),
        ),
      ),
      extensions: [palette],
    );
  }
}
