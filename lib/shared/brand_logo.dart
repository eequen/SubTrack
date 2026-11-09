import 'package:flutter/material.dart';

enum BrandLogoVariant { icon, wordmark, full }

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    required this.variant,
    this.height,
    this.width,
    this.alignment = Alignment.center,
    super.key,
  });

  const BrandLogo.icon({
    this.height = 64,
    this.width,
    this.alignment = Alignment.center,
    super.key,
  }) : variant = BrandLogoVariant.icon;

  const BrandLogo.wordmark({
    this.height = 28,
    this.width,
    this.alignment = Alignment.center,
    super.key,
  }) : variant = BrandLogoVariant.wordmark;

  const BrandLogo.full({
    this.height = 96,
    this.width,
    this.alignment = Alignment.center,
    super.key,
  }) : variant = BrandLogoVariant.full;

  final BrandLogoVariant variant;
  final double? height;
  final double? width;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = switch (variant) {
      BrandLogoVariant.icon =>
        isDark ? 'assets/brand/mark-light.png' : 'assets/brand/mark.png',
      BrandLogoVariant.wordmark =>
        isDark
            ? 'assets/brand/wordmark-light.png'
            : 'assets/brand/textlogoblue.png',
      BrandLogoVariant.full =>
        isDark ? 'assets/brand/bluebg.png' : 'assets/brand/whitebg.png',
    };

    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      semanticLabel: 'SubTrack',
    );
  }
}
