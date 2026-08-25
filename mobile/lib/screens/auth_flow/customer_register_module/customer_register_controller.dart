import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/flavor_config.dart';
import '../customer_home_module/customer_home_view.dart';

/// Customer self-registration (SPEC section 4.1) — same shape as
/// VendorRegisterController, trimmed to what RegisterRequest actually
/// needs for role=customer: name/email/password only, no business_name/
/// phone (vendor-only requirements). No email-verification-pending
/// detour either — a customer registration always returns a token
/// immediately (AuthController::register()), so success lands straight
/// on the home screen.
class CustomerRegisterController extends GetxController {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    update();
  }

  void toggleConfirmPasswordVisibility() {
    obscureConfirmPassword = !obscureConfirmPassword;
    update();
  }

  Future<void> registerAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    try {
      final body = {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'password_confirmation': confirmPasswordController.text,
        'role': FlavorConfig.current.role,
        'device_name': await Injector.deviceName(),
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.registerAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        final fieldError = response?.fieldError('email') ?? response?.fieldError('password');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final userModel = UserModel.fromJson(response.data as Map<String, dynamic>);
      await Injector.setUserData(userModel);

      Utils.transitionWithOffAll(const CustomerHomeView());
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Customer register error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  String? validateRequired(String? value, String messageKey) {
    if ((value ?? '').trim().isEmpty) {
      return tr(messageKey);
    }

    return null;
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
    if ((value ?? '').length < 8) {
      return tr(StringRes.passwordTooShort);
    }

    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value != passwordController.text) {
      return tr(StringRes.passwordsDoNotMatch);
    }

    return null;
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
