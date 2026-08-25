import '../../../constants/app.export.dart';
import '../vendor_search_module/vendor_search_view.dart';

/// Subcategory list for a tapped category (SPEC section 4 items 3-4, task
/// 5.1). No fetch here — the category tree already arrived fully loaded
/// from GET /api/categories on the home screen, so the tapped
/// CategoryModel (subcategories included) is threaded straight through
/// the constructor.
class CustomerSubcategoriesController extends GetxController {
  final CategoryModel category;
  final int? zoneId;
  final double? latitude;
  final double? longitude;
  final String? pincode;

  CustomerSubcategoriesController({
    required this.category,
    required this.zoneId,
    required this.latitude,
    required this.longitude,
    required this.pincode,
  });

  List<SubcategoryModel> get subcategories => category.subcategories;

  /// Vendor search entry point (SPEC section 4 item 4, task 5.3/5.4).
  /// `latitude`/`longitude`/`pincode` are the point/pincode task 4.6's
  /// location detection resolved on the home screen — GET
  /// /vendors/search re-resolves the authoritative zone from these
  /// itself, so nothing here needs to re-derive or re-validate it.
  void selectSubcategory(SubcategoryModel subcategory) {
    Get.to(() => VendorSearchView(
          subcategoryId: subcategory.id!,
          subcategoryName: subcategory.name,
          latitude: latitude,
          longitude: longitude,
          pincode: pincode,
        ));
  }
}
