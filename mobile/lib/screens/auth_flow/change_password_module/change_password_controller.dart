import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../salesman_home_module/salesman_home_view.dart';

/// Forced password change on first login (SPEC section 2.1).
///
/// There is deliberately no way past this screen without completing it: no
/// skip action, and the system back button is trapped by the view. That is
/// not just UI politeness — the server returns PASSWORD_CHANGE_REQUIRED for
/// every other endpoint until the change is done, so skipping would produce
/// an app that appears to work and fails on the first real request.
class ChangePasswordController extends GetxController {
  TextEditingController currentPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  bool obscureCurrent = true;
  bool obscureNew = true;

  void toggleCurrentVisibility() {
    obscureCurrent = !obscureCurrent;
    update();
  }

  void toggleNewVisibility() {
    obscureNew = !obscureNew;
    update();
  }

  Future<void> changePasswordAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    try {
      final body = {
        'current_password': currentPasswordController.text,
        'password': newPasswordController.text,
        'password_confirmation': confirmPasswordController.text,
      };

      Utils.showCircularProgressLottie(true);
      CommonResponse? commonResponse =
          await DataSource.instance.changePasswordAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (commonResponse == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      if (!commonResponse.isSuccess) {
        // The server separates a wrong current password from reusing the same
        // one; both are actionable, so show its message rather than a generic
        // failure.
        Utils.showToast(
          commonResponse.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      // The response carries the updated user with the flag cleared. Storing
      // it keeps the local copy honest — otherwise a later screen reading
      // Injector.userData would still think a change is pending.
      if (commonResponse.data != null) {
        UserModel userModel = UserModel.fromJson(commonResponse.data);
        await Injector.setUserData(userModel, isFromEditProfile: true);
      }

      Utils.showToast(tr(StringRes.passwordChanged));
      Utils.transitionWithOffAll(const SalesmanHomeView());
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Change password error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  String? validateCurrent(String? value) {
    if ((value ?? '').isEmpty) {
      return tr(StringRes.enterCurrentPassword);
    }

    return null;
  }

  String? validateNew(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return tr(StringRes.enterNewPassword);
    }

    // Mirrors Laravel's Password::defaults() minimum, so the obvious failure
    // is caught here rather than costing a round trip.
    if (password.length < 8) {
      return tr(StringRes.passwordTooShort);
    }

    return null;
  }

  String? validateConfirm(String? value) {
    if (value != newPasswordController.text) {
      return tr(StringRes.passwordsDoNotMatch);
    }

    return null;
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
