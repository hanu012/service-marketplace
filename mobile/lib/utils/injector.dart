import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common_model/user_model.dart';
import '../constants/constant.dart';
import '../constants/pref_keys.dart';

/// Static holder for anything that must survive across screens — access token,
/// user profile, preferences.
///
/// Per CLAUDE.md, this is the only shared-state layer: screens do not stand up
/// their own stores, and nothing else touches SharedPreferences directly.
class Injector {
  static SharedPreferences? prefs;

  static UserModel? userData;
  static String accessToken = '';
  static String language = Constants.english;
  static bool isGuestUser = true;
  static bool skipTap = false;
  static bool enableNotification = true;

  /// Call once from main() before runApp.
  static Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();

    accessToken = prefs?.getString(PrefKeys.accessToken) ?? '';
    language = prefs?.getString(PrefKeys.language) ?? Constants.english;
    isGuestUser = prefs?.getBool(PrefKeys.isGuestUser) ?? true;
    skipTap = prefs?.getBool(PrefKeys.skipTap) ?? false;
    enableNotification = prefs?.getBool(PrefKeys.enableNotification) ?? true;

    final stored = prefs?.getString(PrefKeys.userData);
    if (stored != null && stored.isNotEmpty) {
      try {
        userData = UserModel.fromJson(jsonDecode(stored) as Map<String, dynamic>);
      } catch (_) {
        // A payload written by an older build is not worth crashing over.
        await prefs?.remove(PrefKeys.userData);
      }
    }
  }

  /// Persists the user.
  ///
  /// [isFromEditProfile] leaves the stored token alone, because a profile
  /// update response carries no token and would otherwise blank it.
  static Future<void> setUserData(
    UserModel userModel, {
    bool isFromEditProfile = false,
  }) async {
    userData = userModel;

    if (!isFromEditProfile) {
      final token = userModel.authentication?.accessToken;
      if (token != null && token.isNotEmpty) {
        await setAccessToken(token);
      }
    }

    isGuestUser = false;
    await prefs?.setBool(PrefKeys.isGuestUser, false);
    await prefs?.setString(PrefKeys.userData, jsonEncode(userModel.toJson()));
  }

  static Future<void> setAccessToken(String token) async {
    accessToken = token;
    await prefs?.setString(PrefKeys.accessToken, token);
  }

  static Future<void> setLanguage(String value) async {
    language = value;
    await prefs?.setString(PrefKeys.language, value);
  }

  /// Wipes everything tied to the signed-in user. Called on sign-out and on a
  /// 401 from the API.
  static Future<void> clearUserData() async {
    userData = null;
    accessToken = '';
    isGuestUser = true;

    await prefs?.remove(PrefKeys.accessToken);
    await prefs?.remove(PrefKeys.userData);
    await prefs?.setBool(PrefKeys.isGuestUser, true);
  }

  static bool get isLoggedIn => accessToken.isNotEmpty;

  /// Stable per-install device label sent with every login.
  ///
  /// CLAUDE.md: one personal access token per device. The server keys on this
  /// name and deletes that device's previous token when it issues a new one,
  /// so the value has to survive across sessions — a fresh name each sign-in
  /// would leave an orphaned live token behind every time.
  static Future<String> deviceName() async {
    final existing = prefs?.getString(PrefKeys.deviceName);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        '${defaultTargetPlatform.name}-${DateTime.now().millisecondsSinceEpoch}';

    await prefs?.setString(PrefKeys.deviceName, generated);

    return generated;
  }
}
