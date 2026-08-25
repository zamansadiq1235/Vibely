import 'package:flutter/material.dart';

/// Centralized typography so screens never hardcode ad-hoc TextStyles.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle statCount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
