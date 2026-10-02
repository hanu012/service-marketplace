import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/app.export.dart';
import '../vendor_dashboard_module/vendor_dashboard_view.dart';

/// Vendor self-service, step 2 — categories/subcategories then zones,
/// capped by the plan chosen on the previous screen (SPEC section 3.2).
///
/// UX GUIDANCE ONLY, same as the salesman-flow SelectServicesController —
/// the real enforcer is the server-side subscribe endpoint. Fresh module
/// rather than a reuse of that controller: no payment-mode dialog here
/// (self-service is always payment_mode=online per SPEC section 3.2 — a
/// vendor cannot hand themselves cash, and a free trial is a
/// salesman-granted concept), and success lands on the dashboard, not a
/// WhatsApp confirmation screen.
///
/// EXTENDED IN PLACE for task 4.4's "add more within remaining quota"
/// rather than duplicated into a new module — the toggle/cascade/quota-cap
/// logic below is identical either way, it just starts from a pre-seeded
/// selection instead of an empty one. `isAddingMore: true` plus the three
/// `existing*Ids` sets is what the vendor dashboard's Services tab passes;
/// the initial-subscribe call site (vendor_select_plan_module) is
/// unchanged and never sets them.
class VendorSelectServicesController extends GetxController {
  final int vendorId;
  final PlanModel plan;
  final bool isAddingMore;
  final Set<int> existingCategoryIds;
  final Set<int> existingSubcategoryIds;
  final Set<int> existingZoneIds;

  VendorSelectServicesController({
    required this.vendorId,
    required this.plan,
    this.isAddingMore = false,
    Set<int>? existingCategoryIds,
    Set<int>? existingSubcategoryIds,
    Set<int>? existingZoneIds,
  })  : existingCategoryIds = existingCategoryIds ?? const {},
        existingSubcategoryIds = existingSubcategoryIds ?? const {},
        existingZoneIds = existingZoneIds ?? const {} {
    // Pre-seeding is synchronous set manipulation, not a network fetch — it
    // happens here rather than in onInit() so a test can exercise it
    // without also triggering fetchMasterDataAPI(), same as how the
    // initial-subscribe tests already construct this controller directly
    // without going through GetX's lifecycle at all.
    selectedCategoryIds.addAll(this.existingCategoryIds);
    selectedSubcategoryIds.addAll(this.existingSubcategoryIds);
    selectedZoneIds.addAll(this.existingZoneIds);
    // So "add more" mode opens showing what's already there, not collapsed
    // behind a tap.
    expandedCategoryIds.addAll(this.existingCategoryIds);
  }

  List<CategoryModel> categories = [];
  List<ZoneModel> zones = [];
  bool isLoading = false;
  bool isSubmitting = false;

  final Set<int> selectedCategoryIds = {};
  final Set<int> selectedSubcategoryIds = {};
  final Set<int> selectedZoneIds = {};

  // Display-only state (search/filter/expand) — none of this affects what
  // gets selected or submitted, only what's visible while picking.
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  int? activeCategoryFilterId;
  final Set<int> expandedCategoryIds = {};

  int get maxCategories => plan.maxCategories ?? 0;
  int get maxSubcategories => plan.maxSubcategories ?? 0;
  int get maxZones => plan.maxZones ?? 0;

  @override
  void onInit() {
    super.onInit();
    fetchMasterDataAPI();
  }

  @override
  void onClose() {
    searchController.dispose();
    zoneSearchController.dispose();
    super.onClose();
  }

  void onSearchChanged(String value) {
    searchQuery = value.trim().toLowerCase();
    update();
  }

  /// null = "All" chip. Re-tapping the active chip clears the filter.
  void selectCategoryFilter(int? categoryId) {
    activeCategoryFilterId = activeCategoryFilterId == categoryId ? null : categoryId;
    update();
  }

  void toggleCategoryExpanded(int categoryId) {
    if (expandedCategoryIds.contains(categoryId)) {
      expandedCategoryIds.remove(categoryId);
    } else {
      expandedCategoryIds.add(categoryId);
    }
    update();
  }

  /// A search in progress force-expands every match — no point hiding a
  /// result the search itself just surfaced.
  bool isCategoryExpanded(int categoryId) =>
      searchQuery.isNotEmpty || expandedCategoryIds.contains(categoryId);

  /// Categories left standing after the chip filter and the search box —
  /// a category survives the search if its own name matches, or any of its
  /// subcategories' names do.
  List<CategoryModel> get filteredCategories {
    var list = categories;

    if (activeCategoryFilterId != null) {
      list = list.where((c) => c.id == activeCategoryFilterId).toList();
    }

    if (searchQuery.isEmpty) {
      return list;
    }

    return list.where((c) {
      final nameMatch = (c.name ?? '').toLowerCase().contains(searchQuery);
      final subMatch = c.subcategories.any(
        (s) => (s.name ?? '').toLowerCase().contains(searchQuery),
      );
      return nameMatch || subMatch;
    }).toList();
  }

  List<SubcategoryModel> visibleSubcategories(CategoryModel category) {
    if (searchQuery.isEmpty) {
      return category.subcategories;
    }
    return category.subcategories
        .where((s) => (s.name ?? '').toLowerCase().contains(searchQuery))
        .toList();
  }

  /// The zones step runs its own search box, independent of the services one.
  final TextEditingController zoneSearchController = TextEditingController();
  String zoneSearchQuery = '';

  void onZoneSearchChanged(String value) {
    zoneSearchQuery = value.trim().toLowerCase();
    update();
  }

  List<ZoneModel> get filteredZoneCities {
    if (zoneSearchQuery.isEmpty) {
      return zoneCities;
    }
    return zoneCities.where((city) => visibleZonesIn(city).isNotEmpty).toList();
  }

  List<ZoneModel> visibleZonesIn(ZoneModel city) {
    if (zoneSearchQuery.isEmpty) {
      return city.children;
    }
    return city.children
        .where((zone) => (zone.name ?? '').toLowerCase().contains(zoneSearchQuery))
        .toList();
  }

  List<ZoneModel> get visibleStandaloneZones {
    if (zoneSearchQuery.isEmpty) {
      return standaloneZones;
    }
    return standaloneZones
        .where((zone) => (zone.name ?? '').toLowerCase().contains(zoneSearchQuery))
        .toList();
  }

  bool isCategoryLocked(int categoryId) => existingCategoryIds.contains(categoryId);

  bool isSubcategoryLocked(int subcategoryId) =>
      existingSubcategoryIds.contains(subcategoryId);

  bool isZoneLocked(int zoneId) => existingZoneIds.contains(zoneId);

  Future<void> fetchMasterDataAPI() async {
    isLoading = true;
    update();

    try {
      final responses = await Future.wait([
        DataSource.instance.categoriesAPI(),
        DataSource.instance.zonesAPI(),
      ]);

      final categoriesResponse = responses[0];
      final zonesResponse = responses[1];

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

  /// Headroom left under each cap, floored at 0.
  int get subcategoriesRemaining =>
      (maxSubcategories - selectedSubcategoryIds.length).clamp(0, maxSubcategories);

  int get zonesRemaining => (maxZones - selectedZoneIds.length).clamp(0, maxZones);

  int selectedCountIn(CategoryModel category) => category.subcategories
      .where((sub) => selectedSubcategoryIds.contains(sub.id))
      .length;

  int selectedCountInCity(ZoneModel city) =>
      city.children.where((zone) => selectedZoneIds.contains(zone.id)).length;

  /// A zone with children is a city grouping; a childless top-level zone is
  /// itself a leaf and directly selectable.
  List<ZoneModel> get zoneCities => zones.where((zone) => !zone.isLeaf).toList();

  List<ZoneModel> get standaloneZones => zones.where((zone) => zone.isLeaf).toList();

  bool get categoryQuotaReached => selectedCategoryIds.length >= maxCategories;

  bool get subcategoryQuotaReached => selectedSubcategoryIds.length >= maxSubcategories;

  bool get zoneQuotaReached => selectedZoneIds.length >= maxZones;

  void toggleCategory(CategoryModel category) {
    final id = category.id;
    if (id == null) {
      return;
    }

    if (selectedCategoryIds.contains(id)) {
      // Locked (task 4.4's add-more mode): an existing selection can be
      // added TO, never removed here — no code path drops one.
      if (isCategoryLocked(id)) {
        return;
      }

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
    expandedCategoryIds.add(id);

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
      if (isSubcategoryLocked(id)) {
        return;
      }

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
      expandedCategoryIds.add(parentId);
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
      if (isZoneLocked(id)) {
        return;
      }

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

  /// Selects every subcategory in one category that still fits under the
  /// plan's cap. Stops at the cap rather than refusing outright.
  void selectAllIn(CategoryModel category) {
    final id = category.id;
    if (id == null) {
      return;
    }

    if (!selectedCategoryIds.contains(id)) {
      if (categoryQuotaReached) {
        Utils.showToast(tr(StringRes.categoryQuotaReached), isError: true);
        return;
      }
      selectedCategoryIds.add(id);
    }

    expandedCategoryIds.add(id);

    var hitCap = false;
    for (final sub in category.subcategories) {
      if (sub.id == null || selectedSubcategoryIds.contains(sub.id)) {
        continue;
      }
      if (subcategoryQuotaReached) {
        hitCap = true;
        break;
      }
      selectedSubcategoryIds.add(sub.id!);
    }

    if (hitCap) {
      Utils.showToast(tr(StringRes.subcategoryQuotaReached), isError: true);
    }

    update();
  }

  void selectAllZonesIn(ZoneModel city) {
    var hitCap = false;
    for (final zone in city.children) {
      if (zone.id == null || selectedZoneIds.contains(zone.id)) {
        continue;
      }
      if (zoneQuotaReached) {
        hitCap = true;
        break;
      }
      selectedZoneIds.add(zone.id!);
    }

    if (hitCap) {
      Utils.showToast(tr(StringRes.zoneQuotaReached), isError: true);
    }

    update();
  }

  /// Gate for leaving the services step. Zones are not checked here — they
  /// are picked on the next screen, so blocking on them would be a dead end.
  bool validateServices() {
    if (selectedCategoryIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectACategory), isError: true);
      return false;
    }

    if (selectedSubcategoryIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectASubcategory), isError: true);
      return false;
    }

    return true;
  }

  bool validateSelections() {
    if (!validateServices()) {
      return false;
    }

    if (selectedZoneIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectAZone), isError: true);
      return false;
    }

    return true;
  }

  /// Subscribes the vendor to themselves (SPEC section 3.2) —
  /// payment_mode is always 'online', never a choice on this screen. The
  /// server re-validates everything checked client-side, and independently
  /// enforces that this vendor_id can only be the caller's own.
  Future<void> subscribeAPI() async {
    if (!validateSelections()) {
      return;
    }

    isSubmitting = true;
    update();

    try {
      final body = {
        'vendor_id': vendorId,
        'plan_id': plan.id,
        'category_ids': selectedCategoryIds.toList(),
        'subcategory_ids': selectedSubcategoryIds.toList(),
        'zone_ids': selectedZoneIds.toList(),
        'payment_mode': 'online',
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
            response?.fieldError('payment_mode');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.subscribeFailed),
          isError: true,
        );
        return;
      }

      Utils.transitionWithOffAll(const VendorDashboardView());
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

  /// Adds within remaining quota on the vendor's OWN already-active
  /// subscription (SPEC section 3.3, task 4.4) — no vendor_id, no plan_id,
  /// no payment_mode: everything resolves server-side from the caller's
  /// own current subscription. Only genuinely new ids are ever sent; the
  /// server computes the same diff independently and never removes an
  /// existing selection either way.
  Future<void> addServicesAPI() async {
    if (!validateSelections()) {
      return;
    }

    final newCategoryIds = selectedCategoryIds.difference(existingCategoryIds);
    final newSubcategoryIds = selectedSubcategoryIds.difference(existingSubcategoryIds);
    final newZoneIds = selectedZoneIds.difference(existingZoneIds);

    if (newCategoryIds.isEmpty && newSubcategoryIds.isEmpty && newZoneIds.isEmpty) {
      Utils.showToast(tr(StringRes.selectAtLeastOneNewService), isError: true);
      return;
    }

    isSubmitting = true;
    update();

    try {
      final body = {
        'category_ids': newCategoryIds.toList(),
        'subcategory_ids': newSubcategoryIds.toList(),
        'zone_ids': newZoneIds.toList(),
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.addServicesAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        final fieldError = response?.fieldError('category_ids') ??
            response?.fieldError('subcategory_ids') ??
            response?.fieldError('zone_ids') ??
            response?.fieldError('subscription');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.subscribeFailed),
          isError: true,
        );
        return;
      }

      Utils.showToast(tr(StringRes.servicesAdded));
      Get.back(result: true);
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Add services error $e');
      }
      Utils.showToast(tr(StringRes.subscribeFailed), isError: true);
    } finally {
      isSubmitting = false;
      update();
    }
  }
}
