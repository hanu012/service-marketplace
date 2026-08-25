import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../customer_register_module/customer_register_view.dart';
import 'customer_login_controller.dart';

/// Customer sign-in (SPEC section 4.1).
class CustomerLoginView extends StatelessWidget {
  const CustomerLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerLoginController>(
      init: CustomerLoginController(),
      dispose: (_) => Get.delete<CustomerLoginController>(),
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

  Widget mainBody(CustomerLoginController controller) {
    return Utils.authLayout(
      onSkipTap: null,
      title: StringRes.customerLoginTitle,
      desc: StringRes.customerLoginDesc,
      isLogin: true,
      isForCustomer: true,
      skipTap: false,
      contentWidget: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseTextDMSans(
              text: StringRes.email,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: ColorRes.secondaryColor,
              textAlign: TextAlign.start,
            ).tr(),
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
            BaseTextDMSans(
              text: StringRes.password,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: ColorRes.secondaryColor,
              textAlign: TextAlign.start,
            ).tr(),
            8.heightSpacer,
            BaseTextField(
              controller: controller.passwordController,
              hintText: tr(StringRes.enterYourPassword),
              isShowBorder: true,
              isSecure: controller.obscurePassword,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.done,
              validator: controller.validatePassword,
              onFieldSubmitted: (_) => controller.loginAPI(),
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
            24.heightSpacer,
            Center(
              child: InkWell(
                onTap: () => Get.off(() => const CustomerRegisterView()),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${tr(StringRes.dontHaveAccount)} ',
                        style: TextStyle(color: ColorRes.grayColor, fontSize: 13),
                      ),
                      TextSpan(
                        text: tr(StringRes.registerButton),
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

  Widget getBottomButton(CustomerLoginController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.loginAPI,
        buttonText: StringRes.signIn,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
