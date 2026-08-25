import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// Salesman home, My Vendors tab (SPEC section 2.3): vendor name, plan,
/// days to expiry. No leads column — Phase 5's leads table doesn't exist
/// yet, and the backend deliberately omits the field rather than sending a
/// fake zero (see SalesmanVendorResource on the backend).
class MyVendorsController extends GetxController {
  List<SalesmanVendorModel> vendors = [];
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    fetchVendorsAPI();
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
