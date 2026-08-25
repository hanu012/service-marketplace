import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../salesman_login_module/salesman_login_view.dart';

/// PLACEHOLDER controller for the stub home screen. Phase 3 replaces this
/// module entirely with My Vendors / Earnings / Profile (SPEC sections 2.3
/// to 2.5).
///
/// Sign-out is real, though: it is the only way to exercise the full loop
/// while the rest is a stub.
class SalesmanHomeController extends GetxController {
  Future<void> logoutAPI() async {
    try {
      Utils.showCircularProgressLottie(true);
      await DataSource.instance.logoutAPI();
      Utils.showCircularProgressLottie(false);
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Logout error $e');
      }
    }

    // Cleared regardless of the API result. If the call failed the token may
    // still be live server-side, but leaving it on the device would strand
    // the user in a session they cannot leave — and re-signing in replaces
    // that device's token anyway.
    await Injector.clearUserData();

    Utils.showToast(tr(StringRes.logout));
    Utils.transitionWithOffAll(const SalesmanLoginView());
  }
}
