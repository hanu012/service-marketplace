import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../customer_home_module/customer_home_view.dart';

/// Customer sign-in (SPEC section 4.1) — same shape as
/// VendorLoginController, minus the unverified-email detour: customers
/// aren't email-verification gated (AuthController::register()), so
/// login always either succeeds or fails outright.
class CustomerLoginController extends GetxController {
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
      final body = {
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'device_name': await Injector.deviceName(),
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.loginAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      if (!response.isSuccess || response.data == null) {
        Utils.showToast(
          response.message ?? tr(StringRes.invalidCredentials),
          isError: true,
        );
        return;
      }

      final userModel = UserModel.fromJson(response.data);
      await Injector.setUserData(userModel);

      Utils.transitionWithOffAll(const CustomerHomeView());
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Customer login error $e');
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
