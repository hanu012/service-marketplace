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

  /// Whether the salesman app shows anything about money it has earned:
  /// the Earnings stat tile and tab on the home screen, the Earnings stat
  /// on the profile, the Performance group (Earnings & Payouts, Targets),
  /// and the commission rate on Personal details.
  ///
  /// Switched off for now at the client's request. Deliberately ONE flag
  /// rather than five edits, because these are a single decision and have
  /// to come back together — flipping this to true is the whole revert.
  /// The screens, models and endpoints behind them are all left intact.
  static const bool showSalesmanEarnings = false;

  /// Whether the vendor app offers an upgrade anywhere: the "Need more
  /// room?" card on Overview and the "Upgrade to Platinum" row on the
  /// profile.
  ///
  /// Switched off for now at the client's request. One flag rather than
  /// two edits because they are a single decision — an app that pitches
  /// an upgrade in one place and not the other reads as a bug. The
  /// upsell widgets and the upgradePlan lookup behind them are left
  /// intact, so flipping this to true is the whole revert.
  static const bool showVendorUpsell = false;
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
