import 'package:flutter/material.dart';

import '../utils/utils.dart';

/// Non-UI constants and the sizing extensions every screen depends on.
///
/// This file was not in the original port list but the reference screens use
/// `.getSize` and `.heightSpacer` on nearly every line, so the foundation does
/// not compile without it.
class Constants {
  static const String english = 'en';

  // Roles, mirroring the UserRole enum on the backend (SPEC section 1).
  static const String admin = 'admin';
  static const String salesman = 'salesman';
  static const String vendor = 'vendor';
  static const String customer = 'customer';
}

/// Font families. No font assets are bundled yet, so Flutter falls back to the
/// platform default until DM Sans is added to pubspec.yaml.
class FontFamily {
  static const String dmSans = 'DM Sans';
}

extension IntExtension on int? {
  Widget get heightSpacer => SizedBox(height: Utils.getSize((this ?? 0).toDouble()));

  Widget get widthSpacer => SizedBox(width: Utils.getSize((this ?? 0).toDouble()));

  double get getSize => Utils.getSize((this ?? 0).toDouble());

  double get getFontSize => Utils.getFontSize((this ?? 0).toDouble());
}

extension DoubleExtension on double? {
  double get getFontSize => Utils.getFontSize((this ?? 0).toDouble());

  double get getSize => Utils.getSize((this ?? 0).toDouble());
}
