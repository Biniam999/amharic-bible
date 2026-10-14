import 'package:flutter/material.dart';

import 'scenic_background.dart';

/// Artwork used across the app. Replace these files with your own photos
/// (same names, any size, JPG) and the app picks them up.
abstract final class AppImages {
  static const homeHero = 'assets/images/home_hero.jpg';
  static const welcome = 'assets/images/welcome.jpg';
  static const cardSunrise = 'assets/images/card_sunrise.jpg';
}

/// A full-bleed picture. If the file is missing or can't be read, a painted
/// landscape is shown instead, so a screen is never empty.
class SceneImage extends StatelessWidget {
  const SceneImage(
    this.asset, {
    super.key,
    this.fallback = SceneVariant.twilight,
    this.alignment = Alignment.center,
  });

  final String asset;
  final SceneVariant fallback;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => ScenicBackground(variant: fallback),
    );
  }
}
