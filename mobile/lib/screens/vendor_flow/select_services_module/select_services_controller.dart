import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/app.export.dart';
import '../subscription_confirmation_module/subscription_confirmation_view.dart';

/// Add Vendor, step 2b — categories/subcategories then zones, capped by the
/// plan chosen on the previous screen (SPEC section 2.2).
///
/// UX GUIDANCE ONLY. The counters here just stop an obviously-over-quota
/// submission before it's attempted — the real enforcer is the server-side
/// subscribe endpoint (SPEC section 6).
///
/// Selection model (confirmed, not inferred from SPEC): checking a
/// subcategory auto-selects its parent category; checking a category
/// cascades to select its subcategories up to the remaining subcategory
/// quota; unchecking a category cascades to deselect all its subcategories;
/// unchecking a subcategory leaves the category selected.
class SelectServicesController extends GetxController {
  final int vendorId;
  final PlanModel plan;
  final String businessName;
  final String loginEmail;

  SelectServicesController({
    required this.vendorId,
    required this.plan,
    required this.businessName,
    required this.loginEmail,
  });

  List<CategoryModel> categories = [];
  List<ZoneModel> zones = [];
  bool isLoading = false;
  bool isSubmitting = false;

  final Set<int> selectedCategoryIds = {};
  final Set<int> selectedSubcategoryIds = {};
  final Set<int> selectedZoneIds = {};

  /// 'cash', 'online', or 'free' — SPEC 2.2's third paid option, Cheque, has
  /// no backing enum value server-side (payments.mode is cash|online|free).
  String selectedPaymentMode = 'cash';

  /// Fallback matching the server's own default-if-unseeded value
  /// (Setting::get('free_trial_max_days', 15)) — used only in the unlikely
  /// case the dialog opens before fetchMasterDataAPI's settings call
  /// resolves.
  int freeTrialMaxDays = 15;

  /// Defaults to a modest 7, not the max: defaulting to the cap would make
  /// "grant the longest allowed trial" the path of least resistance instead
  /// of a deliberate choice.
  int freeTrialDays = 7;

  int get maxCategories => plan.maxCategories ?? 0;
  int get maxSubcategories => plan.maxSubcategories ?? 0;
  int get maxZones => plan.maxZones ?? 0;

  @override
  void onInit() {
    super.onInit();
    fetchMasterDataAPI();
  }

  Future<void> fetchMasterDataAPI() async {
    isLoading = true;
    update();

    try {
      final responses = await Future.wait([
        DataSource.instance.categoriesAPI(),
        DataSource.instance.zonesAPI(),
        DataSource.instance.settingsAPI(),
      ]);

      final categoriesResponse = responses[0];
      final zonesResponse = responses[1];
      final settingsResponse = responses[2];

      if (categoriesResponse == null ||
          !categoriesResponse.isSuccess ||
          categoriesResponse.data == null ||
          zonesResponse == null ||
          !zonesResponse.isSuccess ||
          zonesResponse.data == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      categories = (categoriesResponse.data as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      zones = (zonesResponse.data as List<dynamic>)
          .map((e) => ZoneModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Best-effort: a failed settings fetch keeps the safe 15-day fallback
      // rather than blocking the whole screen over a non-essential value.
      if (settingsResponse != null && settingsResponse.isSuccess && settingsResponse.data != null) {
        final settingsData = settingsResponse.data as Map<String, dynamic>;
        final fetchedMax = settingsData['free_trial_max_days'];
        if (fetchedMax is int) {
          freeTrialMaxDays = fetchedMax;
          freeTrialDays = freeTrialDays.clamp(1, freeTrialMaxDays).toInt();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch services master data error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  bool isCategorySelected(int categoryId) => selectedCategoryIds.contains(categoryId);

  bool isSubcategorySelected(int subcategoryId) =>
      selectedSubcategoryIds.contains(subcategoryId);

  bool isZoneSelected(int zoneId) => selectedZoneIds.contains(zoneId);

  bool get categoryQuotaReached => selectedCategoryIds.length >= maxCategories;

  bool get subcategoryQuotaReached => selectedSubcategoryIds.length >= maxSubcategories;

  bool get zoneQuotaReached => selectedZoneIds.length >= maxZones;

  void toggleCategory(CategoryModel category) {
    final id = category.id;
    if (id == null) {
      return;
    }

    if (selectedCategoryIds.contains(id)) {
      selectedCategoryIds.remove(id);
      for (final sub in category.subcategories) {
        if (sub.id != null) {
          selectedSubcategoryIds.remove(sub.id);
        }
      }
      update();
      return;
    }

    if (categoryQuotaReached) {
      Utils.showToast(tr(StringRes.categoryQuotaReached), isError: true);
      return;
    }

    selectedCategoryIds.add(id);

    // Cascade-select subcategories up to the remaining quota. Any left over
    // stay unselected and read as quota-disabled in the UI — the same
    // general "checkbox disables once the counter is maxed" rule already
    // covers them, nothing extra to compute here.
    for (final sub in category.subcategories) {
      if (subcategoryQuotaReached) {
        break;
      }
      if (sub.id != null) {
        selectedSubcategoryIds.add(sub.id!);
      }
    }

    update();
  }

  void toggleSubcategory(SubcategoryModel subcategory, CategoryModel parent) {
    final id = subcategory.id;
    if (id == null) {
      return;
    }

    if (selectedSubcategoryIds.contains(id)) {
      selectedSubcategoryIds.remove(id);
      update();
      return;
    }

    if (subcategoryQuotaReached) {
      Utils.showToast(tr(StringRes.subcategoryQuotaReached), isError: true);
      return;
    }

    final parentId = parent.id;
    if (parentId != null && !selectedCategoryIds.contains(parentId)) {
      if (categoryQuotaReached) {
        Utils.showToast(tr(StringRes.categoryQuotaReached), isError: true);
        return;
      }
      selectedCategoryIds.add(parentId);
    }

    selectedSubcategoryIds.add(id);
    update();
  }

  void toggleZone(ZoneModel zone) {
    final id = zone.id;
    if (id == null) {
      return;
    }

    if (selectedZoneIds.contains(id)) {
      selectedZoneIds.remove(id);
      update();
      return;
    }

    if (zoneQuotaReached) {
      Utils.showToast(tr(StringRes.zoneQuotaReached), isError: true);
      return;
    }

    selectedZoneIds.add(id);
    update();
  }

  void selectPaymentMode(String mode) {
    selectedPaymentMode = mode;
    update();
  }

  void setFreeTrialDays(int days) {
    freeTrialDays = days.clamp(1, freeTrialMaxDays).toInt();
    update();
  }

  /// Checked before the payment-mode dialog opens, so a doomed submission
  /// never gets that far.
  bool validateSelections() {
    if (selectedCategoryIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectACategory), isError: true);
      return false;
    }

    if (selectedSubcategoryIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectASubcategory), isError: true);
      return false;
    }

    if (selectedZoneIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectAZone), isError: true);
      return false;
    }

    return true;
  }

  /// Subscribes the vendor (SPEC section 6) — salesman-led only, straight
  /// to Active. The server re-validates everything checked client-side
  /// (quota, leaf-only zones, subcategory/category consistency) against
  /// current state, so a rejection here is possible even after passing
  /// validateSelections() (e.g. master data changed, or a stale screen).
  Future<void> subscribeAPI() async {
    isSubmitting = true;
    update();

    try {
      final body = {
        'vendor_id': vendorId,
        'plan_id': plan.id,
        'category_ids': selectedCategoryIds.toList(),
        'subcategory_ids': selectedSubcategoryIds.toList(),
        'zone_ids': selectedZoneIds.toList(),
        'payment_mode': selectedPaymentMode,
        if (selectedPaymentMode == 'free') 'free_trial_days': freeTrialDays,
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.subscribeAPI(
        body: body,
        idempotencyKey: const Uuid().v4(),
      );
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        final fieldError = response?.fieldError('vendor_id') ??
            response?.fieldError('category_ids') ??
            response?.fieldError('subcategory_ids') ??
            response?.fieldError('zone_ids') ??
            response?.fieldError('free_trial_days');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.subscribeFailed),
          isError: true,
        );
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final subscription = SubscriptionModel.fromJson(
        data['subscription'] as Map<String, dynamic>,
      );
      final temporaryPassword = data['temporary_password'] as String?;

      // The draft is done — nothing left to resume.
      await Injector.prefs?.remove(PrefKeys.draftVendorId);

      Get.to(() => SubscriptionConfirmationView(
            businessName: businessName,
            loginEmail: loginEmail,
            temporaryPassword: temporaryPassword ?? '',
            subscription: subscription,
          ));
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Subscribe error $e');
      }
      Utils.showToast(tr(StringRes.subscribeFailed), isError: true);
    } finally {
      isSubmitting = false;
      update();
    }
  }
}
