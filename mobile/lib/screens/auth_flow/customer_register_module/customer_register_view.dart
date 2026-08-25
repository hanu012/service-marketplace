import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../customer_login_module/customer_login_view.dart';
import 'customer_register_controller.dart';

/// Customer self-registration (SPEC section 4.1).
class CustomerRegisterView extends StatelessWidget {
  const CustomerRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerRegisterController>(
      init: CustomerRegisterController(),
      dispose: (_) => Get.delete<CustomerRegisterController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: getBottomButton(controller, context),
          body: mainBody(controller),
        );
      },
    );
  }

  Widget mainBody(CustomerRegisterController controller) {
    return Utils.authLayout(
      onSkipTap: null,
      title: StringRes.customerRegisterTitle,
      desc: StringRes.customerRegisterDesc,
      isLogin: false,
      isForCustomer: true,
      skipTap: true,
      contentWidget: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel(StringRes.fullName),
            8.heightSpacer,
            BaseTextField(
              controller: controller.nameController,
              hintText: tr(StringRes.enterYourFullName),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  controller.validateRequired(value, StringRes.enterYourFullName),
            ),
            20.heightSpacer,
            fieldLabel(StringRes.email),
            8.heightSpacer,
            BaseTextField(
              controller: controller.emailController,
              hintText: tr(StringRes.enterYourEmail),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: controller.validateEmail,
            ),
            20.heightSpacer,
            fieldLabel(StringRes.password),
            8.heightSpacer,
            BaseTextField(
              controller: controller.passwordController,
              hintText: tr(StringRes.enterYourPassword),
              isShowBorder: true,
              isSecure: controller.obscurePassword,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.next,
              validator: controller.validatePassword,
              suffixIcon: IconButton(
                onPressed: controller.togglePasswordVisibility,
                icon: Icon(
                  controller.obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: ColorRes.grayColor,
                  size: 20.getSize,
                ),
              ),
            ),
            20.heightSpacer,
            fieldLabel(StringRes.confirmPassword),
            8.heightSpacer,
            BaseTextField(
              controller: controller.confirmPasswordController,
              hintText: tr(StringRes.confirmPassword),
              isShowBorder: true,
              isSecure: controller.obscureConfirmPassword,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.done,
              validator: controller.validateConfirmPassword,
              onFieldSubmitted: (_) => controller.registerAPI(),
              suffixIcon: IconButton(
                onPressed: controller.toggleConfirmPasswordVisibility,
                icon: Icon(
                  controller.obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: ColorRes.grayColor,
                  size: 20.getSize,
                ),
              ),
            ),
            24.heightSpacer,
            Center(
              child: InkWell(
                onTap: () => Get.off(() => const CustomerLoginView()),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${tr(StringRes.alreadyHaveAccount)} ',
                        style: TextStyle(color: ColorRes.grayColor, fontSize: 13),
                      ),
                      TextSpan(
                        text: tr(StringRes.signIn),
                        style: TextStyle(
                          color: ColorRes.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

  Widget getBottomButton(CustomerRegisterController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.registerAPI,
        buttonText: StringRes.registerButton,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
