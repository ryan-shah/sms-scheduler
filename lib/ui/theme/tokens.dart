import 'package:flutter/material.dart';

/// The single brand seed colour; every other colour derives from it.
const Color kSeedColor = Color(0xFF2F6FED);

abstract final class Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

abstract final class Radii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

abstract final class IconSizes {
  static const double emptyState = 64.0;
}
