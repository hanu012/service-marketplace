import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'customer_personal_details_controller.dart';

/// Customer Personal Details — edit name and phone; email is shown but
/// not editable.
class CustomerPersonalDetailsView extends StatelessWidget {
  const CustomerPersonalDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerPersonalDetailsController>(
      init: CustomerPersonalDetailsController(),
      dispose: (_) => Get.delete<CustomerPersonalDetailsController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          appBar: AppBar(
            backgroundColor: ServiceTokens.bg,
            foregroundColor: ServiceTokens.text,
            elevation: 0,
            title: BaseTextDMSans(
              text: StringRes.personalDetails,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ServiceTokens.text,
            ).tr(),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16.getSize,
              8.getSize,
              16.getSize,
              30.getSize,
            ),
            children: [form(controller)],
          ),
        );
      },
    );
  }

  Widget form(CustomerPersonalDetailsController controller) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(StringRes.nameLabel),
          8.heightSpacer,
          BaseTextField(
            controller: controller.nameController,
            hintText: tr(StringRes.enterYourName),
            isShowBorder: true,
            validateMode: controller.autoValidateMode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: controller.validateName,
          ),
          20.heightSpacer,

          fieldLabel(StringRes.email),
          8.heightSpacer,
          // Login identity — shown for reference, changed only by an admin.
          BaseTextField(
            controller: controller.emailController,
            isShowBorder: true,
            readOnly: true,
            textColor: ServiceTokens.muted,
          ),
          20.heightSpacer,

          fieldLabel(StringRes.phone),
          8.heightSpacer,
          BaseTextField(
            controller: controller.phoneController,
            hintText: tr(StringRes.enterPhone),
            isShowBorder: true,
            validateMode: controller.autoValidateMode,
            textInputType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: controller.validatePhone,
            onFieldSubmitted: (_) => controller.saveDetailsAPI(),
          ),
          28.heightSpacer,

          AuthPrimaryButton(
            label: StringRes.saveAction,
            onPressed: controller.saveDetailsAPI,
          ),
        ],
      ),
    );
  }

  Widget fieldLabel(String key) {
    return BaseTextDMSans(
      text: key,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: ServiceTokens.text,
      textAlign: TextAlign.start,
    ).tr();
  }
}
