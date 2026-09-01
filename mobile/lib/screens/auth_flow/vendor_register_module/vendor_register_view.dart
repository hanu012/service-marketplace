import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../vendor_login_module/vendor_login_view.dart';
import 'vendor_register_controller.dart';

/// Vendor self-registration (SPEC section 3.1).
///
/// Six fields rather than the login screens' two — which is exactly why the
/// shared [AuthScaffold] scrolls its whole column rather than pinning a button
/// to the bottom: this screen is taller than a small phone's viewport before
/// the keyboard even opens.
class VendorRegisterView extends StatelessWidget {
  const VendorRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorRegisterController>(
      init: VendorRegisterController(),
      dispose: (_) => Get.delete<VendorRegisterController>(),
      builder: (controller) {
        return AuthScaffold(
          title: StringRes.vendorRegisterTitle,
          subtitle: StringRes.vendorRegisterDesc,
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
              label: StringRes.businessName,
              hint: tr(StringRes.enterBusinessName),
              controller: controller.businessNameController,
              icon: Icons.storefront_outlined,
              validateMode: controller.autoValidateMode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  controller.validateRequired(value, StringRes.enterBusinessName),
            ),
            AuthTextField(
              label: StringRes.phone,
              hint: tr(StringRes.enterPhone),
              controller: controller.phoneController,
              icon: Icons.phone_outlined,
              validateMode: controller.autoValidateMode,
              textInputType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: controller.validatePhone,
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
            onTap: () => Get.off(() => const VendorLoginView()),
          ),
        );
      },
    );
  }
}
