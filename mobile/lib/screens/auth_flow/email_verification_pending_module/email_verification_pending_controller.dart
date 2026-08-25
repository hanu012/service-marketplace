import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../vendor_login_module/vendor_login_view.dart';

/// "Check your email" — lands here after registering unverified, or after
/// a login rejected with EMAIL_NOT_VERIFIED (SPEC section 3.1/7). Wires the
/// existing resendVerificationAPI()/StringRes keys, both defined earlier but
/// never consumed by any screen until now.
class EmailVerificationPendingController extends GetxController {
  final String email;

  EmailVerificationPendingController({required this.email});

  bool isResending = false;

  Future<void> resendVerificationAPI() async {
    isResending = true;
    update();

    try {
      final response = await DataSource.instance.resendVerificationAPI(
        body: {'email': email},
      );

      if (response == null || !response.isSuccess) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      Utils.showToast(tr(StringRes.verificationLinkSent));
    } catch (e) {
      if (kDebugMode) {
        print('Resend verification error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isResending = false;
      update();
    }
  }

  void backToLogin() {
    Utils.transitionWithOffAll(const VendorLoginView());
  }
}
