import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../utils/location_capture.dart';
import '../customer_login_module/customer_login_view.dart';

/// Customer home (SPEC section 4.2, task 4.6) — header shows detected
/// location. GPS first, via the same LocationCapture flow the salesman
/// Add Vendor screen uses (task 3.2); falls back to pincode entry when
/// GPS is denied OR the detected point matches no defined zone.
class CustomerHomeController extends GetxController {
  TextEditingController pincodeController = TextEditingController();

  bool isDetecting = false;
  bool showPincodeFallback = false;
  ResolvedZoneModel? zone;

  /// The point/pincode that produced [zone] — threaded through to vendor
  /// search (task 5.3) and vendor detail (task 5.4), both of which take
  /// location as an explicit param rather than re-resolving it
  /// server-side from the stored customer record.
  double? latitude;
  double? longitude;
  String? pincode;

  List<CategoryModel> categories = [];
  bool isLoadingCategories = false;

  @override
  void onInit() {
    super.onInit();
    // Independent data, fired concurrently — neither blocks the other.
    detectLocation();
    fetchCategoriesAPI();
  }

  /// Category browse grid (SPEC section 4 items 3-4, task 5.1). The
  /// subcategory tap that follows navigates into vendor search — see
  /// CustomerSubcategoriesController.selectSubcategory() (task 5.3).
  Future<void> fetchCategoriesAPI() async {
    isLoadingCategories = true;
    update();

    try {
      final response = await DataSource.instance.categoriesAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      categories = (response.data as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Fetch categories error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoadingCategories = false;
      update();
    }
  }

  /// Also what "Change location" re-runs — a previously denied user gets
  /// another chance to grant permission, and a fresh fix is tried even if
  /// one already resolved.
  Future<void> detectLocation() async {
    isDetecting = true;
    showPincodeFallback = false;
    update();

    final position = await LocationCapture.detect();

    if (position == null) {
      // GPS denied/unavailable — SPEC section 4.2's first fallback trigger.
      isDetecting = false;
      showPincodeFallback = true;
      update();
      return;
    }

    await _reportLocation(latitude: position.latitude, longitude: position.longitude);
  }

  Future<void> submitPincodeAPI() async {
    final pincode = pincodeController.text.trim();

    if (pincode.isEmpty) {
      Utils.showToast(tr(StringRes.invalidPincode), isError: true);
      return;
    }

    await _reportLocation(pincode: pincode);
  }

  Future<void> _reportLocation({double? latitude, double? longitude, String? pincode}) async {
    isDetecting = true;
    update();

    try {
      final response = await DataSource.instance.updateCustomerLocationAPI(
        latitude: latitude,
        longitude: longitude,
        pincode: pincode,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        // Falls back to pincode entry either way — SPEC section 4.2's
        // second trigger: GPS succeeded but nothing usable came back.
        showPincodeFallback = true;
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final resolvedZone = data['zone'];

      zone = resolvedZone is Map<String, dynamic>
          ? ResolvedZoneModel.fromJson(resolvedZone)
          : null;

      // Kept alongside `zone` regardless of match outcome — vendor
      // search (task 5.3) re-resolves the zone itself from these, so an
      // unmatched point/pincode is still worth threading through.
      this.latitude = latitude;
      this.longitude = longitude;
      this.pincode = pincode;

      // SPEC section 4.2's second fallback trigger: the point/pincode
      // matched no defined zone.
      showPincodeFallback = zone == null;
    } catch (e) {
      if (kDebugMode) {
        print('Report location error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
      showPincodeFallback = true;
    } finally {
      isDetecting = false;
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
        print('Customer logout error $e');
      }
    }

    await Injector.clearUserData();

    Utils.showToast(tr(StringRes.logout));
    Utils.transitionWithOffAll(const CustomerLoginView());
  }

  @override
  void onClose() {
    pincodeController.dispose();
    super.onClose();
  }
}
