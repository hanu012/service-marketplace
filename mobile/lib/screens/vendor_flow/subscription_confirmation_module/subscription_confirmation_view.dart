import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'subscription_confirmation_controller.dart';

/// Add Vendor, final step — shows the vendor's one-time temp credentials
/// and hands them to the salesman to share (SPEC section 2.2).
class SubscriptionConfirmationView extends StatelessWidget {
  final String businessName;
  final String loginEmail;
  final String temporaryPassword;
  final SubscriptionModel subscription;

  const SubscriptionConfirmationView({
    super.key,
    required this.businessName,
    required this.loginEmail,
    required this.temporaryPassword,
    required this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SubscriptionConfirmationController>(
      init: SubscriptionConfirmationController(
        businessName: businessName,
        loginEmail: loginEmail,
        temporaryPassword: temporaryPassword,
        subscription: subscription,
      ),
      dispose: (_) => Get.delete<SubscriptionConfirmationController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.getSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  40.heightSpacer,
                  Icon(
                    Icons.check_circle,
                    color: ColorRes.primaryColor,
                    size: 64.getSize,
                  ),
                  20.heightSpacer,
                  BaseTextDMSans(
                    text: StringRes.subscriptionConfirmedTitle,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.center,
                  ).tr(),
                  8.heightSpacer,
                  BaseTextDMSans(
                    text: businessName,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ColorRes.primaryColor,
                    textAlign: TextAlign.center,
                  ),
                  8.heightSpacer,
                  BaseTextDMSans(
                    text: StringRes.subscriptionConfirmedDesc,
                    fontSize: 13,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ).tr(),
                  28.heightSpacer,
                  planSummaryCard(controller),
                  16.heightSpacer,
                  credentialsCard(controller),
                  28.heightSpacer,
                  BaseRaisedButton(
                    onPressed: controller.shareCredentials,
                    buttonText: StringRes.shareViaWhatsapp,
                    buttonColor: ColorRes.primaryColor,
                  ),
                  12.heightSpacer,
                  TextButton(
                    onPressed: controller.done,
                    child: BaseTextDMSans(
                      text: StringRes.done,
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

  Widget planSummaryCard(SubscriptionConfirmationController controller) {
    return Container(
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: Column(
        children: [
          summaryRow(StringRes.planLabel, controller.subscription.planName ?? '-'),
          8.heightSpacer,
          summaryRow(
            StringRes.priceLabel,
            '₹${((controller.subscription.pricePaise ?? 0) / 100).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget summaryRow(String labelKey, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BaseTextDMSans(
          text: labelKey,
          fontSize: 13,
          color: ColorRes.grayColor,
        ).tr(),
        BaseTextDMSans(
          text: value,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ColorRes.secondaryColor,
        ),
      ],
    );
  }

  Widget credentialsCard(SubscriptionConfirmationController controller) {
    return Container(
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: ColorRes.primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          credentialRow(StringRes.loginEmailLabel, controller.loginEmail),
          12.heightSpacer,
          credentialRow(StringRes.temporaryPasswordLabel, controller.temporaryPassword),
        ],
      ),
    );
  }

  Widget credentialRow(String labelKey, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BaseTextDMSans(
          text: labelKey,
          fontSize: 12,
          color: ColorRes.grayColor,
        ).tr(),
        4.heightSpacer,
        BaseTextDMSans(
          text: value,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ColorRes.secondaryColor,
        ),
      ],
    );
  }
}
