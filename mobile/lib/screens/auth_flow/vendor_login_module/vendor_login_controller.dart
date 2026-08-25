import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../change_password_module/change_password_view.dart';
import '../email_verification_pending_module/email_verification_pending_view.dart';
import '../vendor_landing_module/vendor_landing_view.dart';

/// Vendor sign-in (SPEC section 3.1) — same shape as
/// SalesmanLoginController, but vendors can self-register (see
/// VendorRegisterController), and an unverified vendor is redirected to a
/// concrete next action rather than just a toast.
class VendorLoginController extends GetxController {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  bool obscurePassword = true;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    update();
  }

  Future<void> loginAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    try {
      final email = emailController.text.trim();
      final body = {
        'email': email,
        'password': passwordController.text,
        'device_name': await Injector.deviceName(),
      };

      Utils.showCircularProgressLottie(true);
      CommonResponse? commonResponse = await DataSource.instance.loginAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (commonResponse == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      if (!commonResponse.isSuccess || commonResponse.data == null) {
        // SPEC section 3.1/7: an unverified vendor gets a concrete next
        // action, not just a toast — they came here specifically to sign
        // in and now need to go confirm their email instead.
        if (commonResponse.errorCode == 'EMAIL_NOT_VERIFIED') {
          Get.to(() => EmailVerificationPendingView(email: email));
          return;
        }

        Utils.showToast(
          commonResponse.message ?? tr(StringRes.invalidCredentials),
          isError: true,
        );
        return;
      }

      UserModel userModel = UserModel.fromJson(commonResponse.data);
      await Injector.setUserData(userModel);

      if (userModel.mustChangePassword) {
        Utils.transitionWithOffAll(const ChangePasswordView());
        return;
      }

      // SPEC section 3.2: has_active_subscription decides dashboard vs
      // plan-selection — VendorLandingController makes that check.
      Utils.transitionWithOffAll(const VendorLandingView());
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Vendor login error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  String? validateEmail(String? value) {
    final email = (value ?? '').trim();

    if (email.isEmpty) {
      return tr(StringRes.enterYourEmail);
    }

    if (!GetUtils.isEmail(email)) {
      return tr(StringRes.invalidEmail);
    }

    return null;
  }

  String? validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return tr(StringRes.enterYourPassword);
    }

    return null;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
