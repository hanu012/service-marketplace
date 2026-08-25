import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../../vendor_flow/add_vendor_module/add_vendor_view.dart';
import '../delete_account_module/delete_account_view.dart';
import '../earnings_module/earnings_view.dart';
import '../my_vendors_module/my_vendors_controller.dart';
import '../my_vendors_module/my_vendors_view.dart';
import '../salesman_login_module/salesman_login_view.dart';
import 'salesman_home_controller.dart';

/// Salesman home: My Vendors and Earnings tabs (SPEC sections 2.3, 2.4).
///
/// Profile (SPEC section 2.5) is not built here — not asked for in this
/// pass. Stays a const no-arg widget: every existing call site
/// (login, change-password, subscription confirmation's "Done", and
/// app.dart's already-logged-in check) constructs it with no arguments, and
/// none of them need to change for the tabs to exist.
class SalesmanHomeView extends StatelessWidget {
  const SalesmanHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SalesmanHomeController>(
      init: SalesmanHomeController(),
      dispose: (_) => Get.delete<SalesmanHomeController>(),
      builder: (controller) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: ColorRes.backgroundColor,
            appBar: AppBar(
              title: BaseTextDMSans(
                text: StringRes.salesmanHomeTitle,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
              ).tr(),
              actions: [
                // The only entry point into the Add Vendor pipeline (tasks
                // 3.2-3.6) — that flow was fully built but unreachable from
                // anywhere in the app until this button existed. Lives in
                // the app bar rather than a tab-specific FAB so it's
                // reachable from both My Vendors and Earnings.
                IconButton(
                  onPressed: () => addVendor(),
                  icon: Icon(Icons.person_add_alt_1, color: ColorRes.primaryColor, size: 22.getSize),
                  tooltip: tr(StringRes.addVendorTitle),
                ),
                IconButton(
                  onPressed: () => Get.to(
                    () => DeleteAccountView(
                      loginViewBuilder: () => const SalesmanLoginView(),
                    ),
                  ),
                  icon: Icon(Icons.person_remove_outlined, color: ColorRes.grayColor, size: 20.getSize),
                  tooltip: tr(StringRes.deleteAccountMenuItem),
                ),
                TextButton(
                  onPressed: controller.logoutAPI,
                  child: BaseTextDMSans(
                    text: StringRes.signOut,
                    fontSize: 14,
                    color: ColorRes.primaryColor,
                  ).tr(),
                ),
              ],
              bottom: TabBar(
                labelColor: ColorRes.primaryColor,
                unselectedLabelColor: ColorRes.grayColor,
                indicatorColor: ColorRes.primaryColor,
                tabs: [
                  Tab(text: tr(StringRes.myVendorsTab)),
                  Tab(text: tr(StringRes.earningsTab)),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                MyVendorsView(),
                EarningsView(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// My Vendors' own controller stays alive for the duration of this
  /// tabbed screen (TabBarView keeps both tabs built), so refreshing it
  /// on return shows the just-added vendor immediately instead of
  /// waiting for the next pull-to-refresh — same
  /// navigate-then-refetch shape `VendorDashboardView.addMoreServices()`
  /// already uses.
  Future<void> addVendor() async {
    await Get.to(() => const AddVendorView());

    if (Get.isRegistered<MyVendorsController>()) {
      Get.find<MyVendorsController>().fetchVendorsAPI();
    }
  }
}
