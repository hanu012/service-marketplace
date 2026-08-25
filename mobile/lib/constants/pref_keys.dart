/// SharedPreferences keys. Read and written only through [Injector] — screens
/// never touch SharedPreferences directly.
class PrefKeys {
  static const String accessToken = 'accessToken';
  static const String deviceId = 'deviceId';
  static const String deviceName = 'deviceName';
  static const String userData = 'userData';
  static const String isGuestUser = 'guestUser';
  static const String enableNotification = 'enableNotification';
  static const String askBeforeNotification = 'askBeforeNotification';
  static const String skipTap = 'skip';
  static const String language = 'language';

  /// In-progress vendor draft (SPEC 2.2). Kept so a salesman who loses the
  /// connection - or the app - resumes rather than retyping.
  static const String draftVendorId = 'draftVendorId';
}
