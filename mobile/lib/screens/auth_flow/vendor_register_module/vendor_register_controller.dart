import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/flavor_config.dart';
import '../email_verification_pending_module/email_verification_pending_view.dart';
import '../vendor_landing_module/vendor_landing_view.dart';

/// Vendor self-registration (SPEC section 3.1) — built fresh, not adapted
/// from the ported create_account_module (that screen only ever collects a
/// display name and posts to a different, unrelated endpoint; it is not a
/// real registration flow for any role).
///
/// `role` is not a form field — the vendor app only ever registers
/// vendors, so it is read from FlavorConfig.current.role instead of asked
/// for. business_name/phone are required here because the backend Vendor
/// row created alongside the User row (task 4.1) has NOT NULL columns for
/// both — owner_name is not a separate field, it mirrors `name`, same as
/// the salesman-led draft flow already treats the two as one value.
class VendorRegisterController extends GetxController {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController businessNameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
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
      final email = emailController.text.trim();
      final body = {
        'name': nameController.text.trim(),
        'email': email,
        'password': passwordController.text,
        'password_confirmation': confirmPasswordController.text,
        'business_name': businessNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': FlavorConfig.current.role,
        'device_name': await Injector.deviceName(),
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.registerAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        final fieldError = response?.fieldError('email') ??
            response?.fieldError('phone') ??
            response?.fieldError('business_name') ??
            response?.fieldError('password');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final userModel = UserModel.fromJson(data);

      // A vendor is not handed a token until the email is verified (server
      // enforces this — see AuthController::register()) — this is the
      // expected path for every fresh vendor registration, not a failure.
      if (userModel.authentication?.accessToken == null) {
        // Keeps the email locally so the "check your email" screen can
        // show it and resend against it, without signing the account in.
        await Injector.setUserData(userModel);
        Get.off(() => EmailVerificationPendingView(email: email));
        return;
      }

      await Injector.setUserData(userModel);
      Utils.transitionWithOffAll(const VendorLandingView());
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Vendor register error $e');
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

  String? validatePhone(String? value) {
    final phone = (value ?? '').trim();

    if (phone.isEmpty) {
      return tr(StringRes.enterPhone);
    }

    if (!GetUtils.isPhoneNumber(phone)) {
      return tr(StringRes.invalidPhone);
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
    businessNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
