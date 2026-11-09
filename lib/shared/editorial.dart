import 'package:flutter/material.dart';
import 'package:subtrack/app/theme.dart';

/// Small monospaced overline used above a page title or section.
///
/// The little rule is the visual equivalent of a margin note in a printed
/// workbook, and it keeps the accent colour restrained.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    this.trailing,
    this.showRule = true,
    super.key,
  });

  final String text;
  final Widget? trailing;
  final bool showRule;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: palette.mutedText),
    );
    return Row(
      children: [
        if (showRule) ...[
          Container(width: 18, height: 1.5, color: palette.accentText),
          const SizedBox(width: 8),
        ],
        Expanded(child: label),
        ?trailing,
      ],
    );
  }
}

/// Serif page title with an optional overline, supporting copy, and trailing
/// action. Used by the revamped key screens.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eyebrow != null) ...[
          SectionLabel(eyebrow!),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    titleStyle ??
                    textTheme.headlineLarge?.copyWith(color: palette.text),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
          ),
        ],
      ],
    );
  }
}

/// A one-pixel rule that visually separates editorial blocks.
class EditorialRule extends StatelessWidget {
  const EditorialRule({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(height: 1, color: context.palette.cardBorder),
    );
  }
}

/// Square, numbered stamp used to give lists a ledger-like feel.
class IndexStamp extends StatelessWidget {
  const IndexStamp(
    this.value, {
    this.color,
    this.size = 30,
    this.filled = false,
    super.key,
  });

  final String value;
  final Color? color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = color ?? palette.accentText;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? ink : Colors.transparent,
        border: Border.all(color: ink.withValues(alpha: filled ? 1 : 0.55)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: filled ? palette.onAccent : ink,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// The SubTrack mark without the wordmark. Used as a hero graphic when the
/// wordmark is already set in type (for example, the login masthead).
class SubTrackMark extends StatelessWidget {
  const SubTrackMark({
    this.height = 96,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/mark-light.png' : 'assets/images/mark.png',
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Full SubTrack lockup (mark + wordmark) from the supplied logo.
class SubTrackLockup extends StatelessWidget {
  const SubTrackLockup({
    this.height = 128,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/lockup-light.png' : 'assets/images/lockup.png',
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Wordmark only, cropped from the supplied logo for headers and auth screens.
class SubTrackWordmark extends StatelessWidget {
  const SubTrackWordmark({
    this.height = 28,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/wordmark-light.png' : 'assets/images/wordmark.png',
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
    );
  }
}
