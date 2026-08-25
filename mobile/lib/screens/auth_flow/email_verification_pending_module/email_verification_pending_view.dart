import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'email_verification_pending_controller.dart';

/// "Check your email" (SPEC section 3.1/7).
class EmailVerificationPendingView extends StatelessWidget {
  final String email;

  const EmailVerificationPendingView({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EmailVerificationPendingController>(
      init: EmailVerificationPendingController(email: email),
      dispose: (_) => Get.delete<EmailVerificationPendingController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.getSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  60.heightSpacer,
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: ColorRes.primaryColor,
                    size: 64.getSize,
                  ),
                  20.heightSpacer,
                  BaseTextDMSans(
                    text: StringRes.verificationPendingTitle,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.center,
                  ).tr(),
                  8.heightSpacer,
                  BaseTextDMSans(
                    text: StringRes.verificationPendingDesc,
                    fontSize: 13,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ).tr(),
                  6.heightSpacer,
                  BaseTextDMSans(
                    text: email,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorRes.primaryColor,
                    textAlign: TextAlign.center,
                  ),
                  32.heightSpacer,
                  BaseRaisedButton(
                    onPressed: controller.isResending ? null : controller.resendVerificationAPI,
                    buttonText: StringRes.resendVerification,
                    buttonColor: ColorRes.primaryColor,
                  ),
                  12.heightSpacer,
                  TextButton(
                    onPressed: controller.backToLogin,
                    child: BaseTextDMSans(
                      text: StringRes.backToLogin,
                      color: ColorRes.grayColor,
                      fontWeight: FontWeight.w500,
                    ).tr(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
