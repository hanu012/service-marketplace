import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../vendor_login_module/vendor_login_view.dart';

/// Vendor dashboard (SPEC section 3.2/3.9) — plan name, quota used/total
/// per resource, days remaining. Shown once GET /api/vendors/me reports an
/// active subscription (task 4.2).
///
/// Leads and reviews live on their own tabs (task 4.8's
/// vendor_leads_module/vendor_reviews_module), not summarized here. No
/// aggregate rating figure on this screen specifically — `rating_avg`/
/// `rating_count` are real and live (task 5.5), just not surfaced on
/// this particular view; see VendorSearchService for where they're used.
/// Fetches its own data on every entry (not just what login handed
/// forward), so returning to the app later still shows live numbers.
class VendorDashboardController extends GetxController {
  VendorMeModel? vendorMe;
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    fetchVendorMeAPI();
  }

  Future<void> fetchVendorMeAPI() async {
    isLoading = true;
    update();

    try {
      final response = await DataSource.instance.vendorMeAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      vendorMe = VendorMeModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('Fetch vendor dashboard error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
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
        print('Vendor logout error $e');
      }
    }

    await Injector.clearUserData();

    Utils.showToast(tr(StringRes.logout));
    Utils.transitionWithOffAll(const VendorLoginView());
  }
}
