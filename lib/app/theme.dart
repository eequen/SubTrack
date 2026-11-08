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
    light: Color(0xFF3B4BDB),
    darkFill: Color(0xFF3B4BDB),
    darkText: Color(0xFF8E99FF),
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
  AccentOption(
    key: 'pink',
    light: Color(0xFFC2185B),
    darkFill: Color(0xFFC2185B),
    darkText: Color(0xFFFF8FB1),
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
      background: const Color(0xFFF4F6FB),
      card: const Color(0xFFFFFFFF),
      cardBorder: const Color(0xFFE1E5F0),
      text: const Color(0xFF14182B),
      mutedText: const Color(0xFF5B6280),
      accent: accent.light,
      accentText: accent.light,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFF9A5B00),
      deadlineBg: const Color(0xFFFFF1D6),
      overdue: const Color(0xFFB42318),
      draftText: const Color(0xFF444B66),
      draftBg: const Color(0xFFECEEF5),
      inProgressText: const Color(0xFF2D3AB5),
      inProgressBg: const Color(0xFFE8EAFD),
      finalText: const Color(0xFF0B6B5F),
      finalBg: const Color(0xFFDDF5F0),
      submittedText: const Color(0xFF2F6B16),
      submittedBg: const Color(0xFFE4F4DC),
    );
  }

  static AppPalette dark(String accentKey) {
    final accent = accentByKey(accentKey);
    return AppPalette(
      background: const Color(0xFF0F1220),
      card: const Color(0xFF1A1F33),
      cardBorder: const Color(0xFF2A3050),
      text: const Color(0xFFEDEFF8),
      mutedText: const Color(0xFFA3AACB),
      accent: accent.darkFill,
      accentText: accent.darkText,
      onAccent: const Color(0xFFFFFFFF),
      deadlineText: const Color(0xFFF2C879),
      // The light amber at 20% over the dark background.
      deadlineBg: const Color(0x33FFF1D6),
      overdue: const Color(0xFFFF8A7A),
      draftText: const Color(0xFFC3C9DD),
      draftBg: const Color(0x33444B66),
      inProgressText: const Color(0xFF9FA8FF),
      inProgressBg: const Color(0x332D3AB5),
      finalText: const Color(0xFF57C9B7),
      finalBg: const Color(0x330B6B5F),
      submittedText: const Color(0xFF8ED46C),
      submittedBg: const Color(0x332F6B16),
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

abstract final class AppTheme {
  static const double screenPadding = 20;
  static const double cardRadius = 14;
  static const double buttonRadius = 12;

  static ThemeData light(String accentKey) =>
      _build(AppPalette.light(accentKey), Brightness.light);

  static ThemeData dark(String accentKey) =>
      _build(AppPalette.dark(accentKey), Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accentText,
      brightness: brightness,
      primary: palette.accentText,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: base.textTheme.apply(
        bodyColor: palette.text,
        displayColor: palette.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(backgroundColor: palette.card),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentText,
          minimumSize: const Size(64, 44),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accentText,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
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
