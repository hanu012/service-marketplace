import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// "Forgot password?" for all three flavours.
///
/// There is no emailed reset — the platform sends no mail. This files a
/// request that appears in the admin panel (Users → Reset requests); the
/// admin issues a temporary password and shares it by call or WhatsApp, and
/// the user is made to choose their own on next sign-in.
///
/// Opened with Get.to over the login screen, so finishing is Get.back(): the
/// login screen is still mounted underneath.
class ForgotPasswordController extends GetxController {
  ForgotPasswordController({String initialEmail = ''}) {
    emailController.text = initialEmail;
  }

  TextEditingController emailController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  Future<void> sendResetRequestAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    try {
      final body = {'email': emailController.text.trim()};

      Utils.showCircularProgressLottie(true);
      CommonResponse? commonResponse =
          await DataSource.instance.passwordResetRequestAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (commonResponse == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      if (!commonResponse.isSuccess) {
        // Validation or rate-limit message from the server.
        Utils.showToast(
          commonResponse.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      // Same message whether or not the email has an account — the server
      // deliberately does not say which.
      Utils.showToast(tr(StringRes.resetRequestSent));
      Get.back();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Password reset request error $e');
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

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
