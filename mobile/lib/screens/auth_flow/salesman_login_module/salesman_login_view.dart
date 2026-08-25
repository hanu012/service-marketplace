import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'salesman_login_controller.dart';

/// Salesman sign-in. Login only — no registration link anywhere, because
/// salesmen never self-register (SPEC section 1).
///
/// Same shape as the ported create_account_module: StatelessWidget, build()
/// returns a GetBuilder with init + dispose, state read off the builder
/// argument named `controller` (never `_`, which Dart 3.7+ treats as a
/// non-binding wildcard).
class SalesmanLoginView extends StatelessWidget {
  const SalesmanLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SalesmanLoginController>(
      init: SalesmanLoginController(),
      dispose: (_) => Get.delete<SalesmanLoginController>(),
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

  Widget mainBody(SalesmanLoginController controller) {
    return Utils.authLayout(
      onSkipTap: null,
      title: StringRes.salesmanLoginTitle,
      desc: StringRes.salesmanLoginDesc,
      isLogin: true,
      isForCustomer: false,
      // No back arrow: this is the first screen of the flavour, there is
      // nothing behind it to return to.
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
          ],
        ),
      ),
    );
  }

  Widget getBottomButton(
      SalesmanLoginController controller, BuildContext context) {
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
