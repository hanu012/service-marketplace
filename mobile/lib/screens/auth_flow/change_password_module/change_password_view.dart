import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'change_password_controller.dart';

/// Forced password change on first login (SPEC section 2.1).
class ChangePasswordView extends StatelessWidget {
  const ChangePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChangePasswordController>(
      init: ChangePasswordController(),
      dispose: (_) => Get.delete<ChangePasswordController>(),
      builder: (controller) {
        // canPop: false — there is nowhere to go back to. The server blocks
        // every other endpoint until this is done, so an escape hatch would
        // only lead to an app that looks signed in and fails on its first
        // real request.
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: ColorRes.backgroundColor,
            resizeToAvoidBottomInset: true,
            bottomNavigationBar: getBottomButton(controller, context),
            body: mainBody(controller),
          ),
        );
      },
    );
  }

  Widget mainBody(ChangePasswordController controller) {
    return Utils.authLayout(
      onSkipTap: null,
      title: StringRes.changePasswordTitle,
      desc: StringRes.changePasswordDesc,
      isLogin: false,
      isForCustomer: false,
      skipTap: false,
      contentWidget: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel(StringRes.currentPassword),
            8.heightSpacer,
            BaseTextField(
              controller: controller.currentPasswordController,
              hintText: tr(StringRes.enterCurrentPassword),
              isShowBorder: true,
              isSecure: controller.obscureCurrent,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.next,
              validator: controller.validateCurrent,
              suffixIcon: visibilityToggle(
                obscured: controller.obscureCurrent,
                onPressed: controller.toggleCurrentVisibility,
              ),
            ),
            20.heightSpacer,
            fieldLabel(StringRes.newPassword),
            8.heightSpacer,
            BaseTextField(
              controller: controller.newPasswordController,
              hintText: tr(StringRes.enterNewPassword),
              isShowBorder: true,
              isSecure: controller.obscureNew,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.next,
              validator: controller.validateNew,
              suffixIcon: visibilityToggle(
                obscured: controller.obscureNew,
                onPressed: controller.toggleNewVisibility,
              ),
            ),
            20.heightSpacer,
            fieldLabel(StringRes.confirmNewPassword),
            8.heightSpacer,
            BaseTextField(
              controller: controller.confirmPasswordController,
              hintText: tr(StringRes.confirmNewPassword),
              isShowBorder: true,
              isSecure: controller.obscureNew,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.done,
              validator: controller.validateConfirm,
              onFieldSubmitted: (_) => controller.changePasswordAPI(),
            ),
          ],
        ),
      ),
    );
  }

  Widget fieldLabel(String key) {
    return BaseTextDMSans(
      text: key,
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: ColorRes.secondaryColor,
      textAlign: TextAlign.start,
    ).tr();
  }

  Widget visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: ColorRes.grayColor,
        size: 20.getSize,
      ),
    );
  }

  Widget getBottomButton(
      ChangePasswordController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.changePasswordAPI,
        buttonText: StringRes.resetPassword,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
