import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// Salesman home, My Vendors tab (SPEC section 2.3): vendor name, plan,
/// days to expiry. No leads column — Phase 5's leads table doesn't exist
/// yet, and the backend deliberately omits the field rather than sending a
/// fake zero (see SalesmanVendorResource on the backend).
class MyVendorsController extends GetxController {
  List<SalesmanVendorModel> vendors = [];
  bool isLoading = false;

  /// Display-only narrowing. Client-side, like the services screen's
  /// search: this endpoint returns a salesman's whole (bounded) vendor
  /// list in one call, so filtering locally is instant and needs no
  /// debounce or round trip.
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  /// Off shows everyone; on narrows to vendors with no live subscription —
  /// the salesman's actual work queue.
  bool unsubscribedOnly = false;

  @override
  void onInit() {
    super.onInit();
    fetchVendorsAPI();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void onSearchChanged(String value) {
    searchQuery = value.trim().toLowerCase();
    update();
  }

  void toggleUnsubscribedOnly() {
    unsubscribedOnly = !unsubscribedOnly;
    update();
  }

  void clearFilters() {
    searchController.clear();
    searchQuery = '';
    unsubscribedOnly = false;
    update();
  }

  bool get hasActiveFilter => searchQuery.isNotEmpty || unsubscribedOnly;

  List<SalesmanVendorModel> get filteredVendors {
    var list = vendors;

    if (unsubscribedOnly) {
      list = list.where((v) => !v.isSubscribed).toList();
    }

    if (searchQuery.isEmpty) {
      return list;
    }

    // Owner name too, not just the business: a salesman often remembers
    // the person before the shop.
    return list.where((v) {
      final business = (v.businessName ?? '').toLowerCase();
      final owner = (v.ownerName ?? '').toLowerCase();
      return business.contains(searchQuery) || owner.contains(searchQuery);
    }).toList();
  }

  Future<void> fetchVendorsAPI() async {
    isLoading = true;
    update();

    try {
      final response = await DataSource.instance.salesmanVendorsAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      vendors = (response.data as List<dynamic>)
          .map((e) => SalesmanVendorModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Fetch my vendors error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }
}
