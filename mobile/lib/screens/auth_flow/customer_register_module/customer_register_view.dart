import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
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
        return AuthScaffold(
          title: StringRes.customerRegisterTitle,
          subtitle: StringRes.customerRegisterDesc,
          formKey: controller.formKey,
          showBack: true,
          fields: [
            AuthTextField(
              label: StringRes.fullName,
              hint: tr(StringRes.enterYourFullName),
              controller: controller.nameController,
              icon: Icons.person_outline_rounded,
              validateMode: controller.autoValidateMode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  controller.validateRequired(value, StringRes.enterYourFullName),
            ),
            AuthTextField(
              label: StringRes.email,
              hint: tr(StringRes.enterYourEmail),
              controller: controller.emailController,
              icon: Icons.mail_outline_rounded,
              validateMode: controller.autoValidateMode,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: controller.validateEmail,
            ),
            AuthTextField(
              label: StringRes.password,
              hint: tr(StringRes.enterYourPassword),
              controller: controller.passwordController,
              icon: Icons.lock_outline_rounded,
              isSecure: controller.obscurePassword,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.next,
              validator: controller.validatePassword,
              suffixIcon: AuthVisibilityToggle(
                isObscured: controller.obscurePassword,
                onPressed: controller.togglePasswordVisibility,
              ),
            ),
            AuthTextField(
              label: StringRes.confirmPassword,
              hint: tr(StringRes.confirmPassword),
              controller: controller.confirmPasswordController,
              icon: Icons.lock_outline_rounded,
              isSecure: controller.obscureConfirmPassword,
              validateMode: controller.autoValidateMode,
              textInputAction: TextInputAction.done,
              validator: controller.validateConfirmPassword,
              onFieldSubmitted: (_) => controller.registerAPI(),
              isLast: true,
              suffixIcon: AuthVisibilityToggle(
                isObscured: controller.obscureConfirmPassword,
                onPressed: controller.toggleConfirmPasswordVisibility,
              ),
            ),
          ],
          primaryAction: AuthPrimaryButton(
            label: StringRes.registerButton,
            onPressed: controller.registerAPI,
          ),
          footer: AuthFooterLink(
            promptKey: StringRes.alreadyHaveAccount,
            actionKey: StringRes.signIn,
            onTap: () => Get.off(() => const CustomerLoginView()),
          ),
        );
      },
    );
  }
}
