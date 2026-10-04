import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/flavor_config.dart';
import '../customer_home_module/customer_home_view.dart';
import '../customer_login_module/customer_login_view.dart';
import '../salesman_home_module/salesman_home_view.dart';
import '../salesman_login_module/salesman_login_view.dart';
import '../vendor_landing_module/vendor_landing_view.dart';
import '../vendor_login_module/vendor_login_view.dart';

/// "Your account is in verification" — the only screen an unapproved
/// account can reach, in all three flavours (SPEC section 3.1).
///
/// Admin approval replaced email verification as the single gate, so this
/// is where every self-registration lands and where any sign-in lands while
/// the account is still pending or has been rejected. Home is never built
/// underneath: the API refuses every endpoint it would call, so a home
/// screen here would be a wall of failed requests.
///
/// Two actions only, matching what the server still allows an unapproved
/// token to do: re-check the decision, and sign out.
class AccountVerificationController extends GetxController {
  bool isChecking = false;

  /// Mirrors Injector so the view can redraw after a check without the
  /// whole screen depending on static state.
  String status = Injector.userData?.approvalStatus ?? 'pending';
  String? note = Injector.userData?.approvalNote;

  bool get isRejected => status == 'rejected';

  /// Re-reads the profile to see whether an admin has decided yet.
  ///
  /// GET /user is deliberately one of the few routes left open to an
  /// unapproved token — without it this screen would have no way out except
  /// signing out and back in.
  Future<void> checkStatusAPI() async {
    isChecking = true;
    update();

    try {
      final response = await DataSource.instance.userAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final userModel = UserModel.fromJson(response.data as Map<String, dynamic>);

      // isFromEditProfile: this response carries no token, and letting it
      // through would blank the one we are signed in with.
      await Injector.setUserData(userModel, isFromEditProfile: true);

      status = userModel.approvalStatus ?? 'pending';
      note = userModel.approvalNote;

      if (userModel.isApproved) {
        Utils.showToast(tr(StringRes.accountApproved));
        Utils.transitionWithOffAll(_homeForFlavor());
        return;
      }

      Utils.showToast(
        isRejected ? tr(StringRes.accountRejectedTitle) : tr(StringRes.accountStillPending),
        isError: isRejected,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Account verification check error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isChecking = false;
      update();
    }
  }

  /// The one way off this screen that always works. Mirrors the profile
  /// screens' sign-out: the local session is cleared even if the server
  /// call fails, because leaving someone stuck here on a bad connection is
  /// the worse outcome.
  Future<void> logoutAPI() async {
    try {
      Utils.showCircularProgressLottie(true);
      await DataSource.instance.logoutAPI();
      Utils.showCircularProgressLottie(false);
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Account verification logout error $e');
      }
    }

    await Injector.clearUserData();

    Utils.showToast(tr(StringRes.logout));
    Utils.transitionWithOffAll(_loginForFlavor());
  }

  Widget _homeForFlavor() {
    switch (FlavorConfig.current.flavor) {
      case Flavor.salesman:
        return const SalesmanHomeView();
      case Flavor.vendor:
        return const VendorLandingView();
      case Flavor.customer:
        return const CustomerHomeView();
    }
  }

  Widget _loginForFlavor() {
    switch (FlavorConfig.current.flavor) {
      case Flavor.salesman:
        return const SalesmanLoginView();
      case Flavor.vendor:
        return const VendorLoginView();
      case Flavor.customer:
        return const CustomerLoginView();
    }
  }
}
