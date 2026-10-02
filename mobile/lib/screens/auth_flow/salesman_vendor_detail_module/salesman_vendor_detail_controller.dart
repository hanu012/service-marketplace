import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// One of the salesman's own vendors, in full (SPEC section 2.3) — what
/// they sold them and how much of it is used.
///
/// Backed by `GET /api/vendors/{id}`, which returns the same
/// `{vendor, active_subscription}` shape as `GET /vendors/me`, so
/// [VendorMeModel] parses it unchanged rather than needing a second model
/// that could drift from it. `active_subscription` is null for a draft or
/// lapsed vendor, which is the "Not subscribed" state the list already
/// shows — not an error.
class SalesmanVendorDetailController extends GetxController {
  final int vendorId;

  SalesmanVendorDetailController({required this.vendorId});

  VendorMeModel? vendor;
  bool isLoading = false;
  bool hasError = false;

  @override
  void onInit() {
    super.onInit();
    fetchVendorAPI();
  }

  Future<void> fetchVendorAPI() async {
    isLoading = true;
    hasError = false;
    update();

    try {
      final response = await DataSource.instance.vendorShowAPI(vendorId: vendorId);

      if (response == null || !response.isSuccess || response.data == null) {
        hasError = true;
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      vendor = VendorMeModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('Fetch vendor detail error $e');
      }
      hasError = true;
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }
}
