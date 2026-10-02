import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../salesman_login_module/salesman_login_view.dart';

/// The salesman's own profile (SPEC section 2.5).
///
/// Backed by `GET /api/salesmen/me`, which bundles identity, preferences
/// and headline stats in one call — the screen renders all three at once,
/// so splitting them would mean three round trips to draw it.
class SalesmanProfileController extends GetxController {
  SalesmanProfileModel? profile;
  bool isLoading = false;
  bool hasError = false;

  /// Guards the notification switch while its PATCH is in flight, so a
  /// double tap cannot fire two conflicting writes.
  bool isSavingPreference = false;

  @override
  void onInit() {
    super.onInit();
    fetchProfileAPI();
  }

  Future<void> fetchProfileAPI() async {
    isLoading = true;
    hasError = false;
    update();

    try {
      final response = await DataSource.instance.salesmanMeAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        hasError = true;
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      profile = SalesmanProfileModel.fromJson(response.data as Map<String, dynamic>);

      // Keep the device copy in step with the server's, so the rest of the
      // app (which reads Injector) does not disagree with this screen.
      Injector.enableNotification = profile!.enableNotification;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch salesman profile error $e');
      }
      hasError = true;
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  /// Optimistic: the switch flips immediately and rolls back if the server
  /// refuses, because a toggle that lags a round trip feels broken.
  Future<void> setNotifications(bool enabled) async {
    if (isSavingPreference || profile == null) {
      return;
    }

    final previous = profile!.enableNotification;

    isSavingPreference = true;
    profile!.enableNotification = enabled;
    update();

    try {
      final response = await DataSource.instance.updatePreferencesAPI(
        body: {'enable_notification': enabled},
      );

      if (response == null || !response.isSuccess) {
        profile!.enableNotification = previous;
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      Injector.enableNotification = enabled;
      await Injector.prefs?.setBool(PrefKeys.enableNotification, enabled);
    } catch (e) {
      profile!.enableNotification = previous;
      if (kDebugMode) {
        print('Update preference error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isSavingPreference = false;
      update();
    }
  }

  Future<void> logoutAPI() async {
    try {
      Utils.showCircularProgressLottie(true);
      await DataSource.instance.logoutAPI();
      Utils.showCircularProgressLottie(false);
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Salesman logout error $e');
      }
    }

    await Injector.clearUserData();

    Utils.showToast(tr(StringRes.logout));
    Utils.transitionWithOffAll(const SalesmanLoginView());
  }
}
