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
  final bool isRenewal;

  const SubscriptionConfirmationView({
    super.key,
    required this.businessName,
    required this.loginEmail,
    required this.temporaryPassword,
    required this.subscription,
    this.isRenewal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SubscriptionConfirmationController>(
      init: SubscriptionConfirmationController(
        businessName: businessName,
        loginEmail: loginEmail,
        temporaryPassword: temporaryPassword,
        subscription: subscription,
        isRenewal: isRenewal,
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
                  // Razorpay on: the sale waits for the vendor to pay the
                  // link, so this is a clock, not a tick.
                  Icon(
                    controller.isAwaitingPayment ? Icons.schedule : Icons.check_circle,
                    color: controller.isAwaitingPayment ? ColorRes.warningColor : ColorRes.primaryColor,
                    size: 64.getSize,
                  ),
                  20.heightSpacer,
                  BaseTextDMSans(
                    text: controller.isAwaitingPayment
                        ? StringRes.paymentPendingTitle
                        : controller.isRenewal
                            ? StringRes.planRenewedTitle
                            : StringRes.subscriptionConfirmedTitle,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.center,
                  ).tr(),
                  8.heightSpacer,
                  BaseTextDMSans(
                    text: businessName,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ColorRes.primaryColor,
                    textAlign: TextAlign.center,
                  ),
                  8.heightSpacer,
                  BaseTextDMSans(
                    text: controller.isAwaitingPayment
                        ? StringRes.paymentLinkSentSalesman
                        : controller.isRenewal
                            ? StringRes.planRenewedDesc
                            : StringRes.subscriptionConfirmedDesc,
                    fontSize: 12,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                  ).tr(),
                  28.heightSpacer,
                  planSummaryCard(controller),
                  if (controller.paymentLinkUrl.isNotEmpty) ...[
                    16.heightSpacer,
                    paymentLinkCard(controller),
                  ],
                  // A renewal keeps the vendor's own password — there are
                  // no login details to hand over.
                  if (!controller.isRenewal) ...[
                    16.heightSpacer,
                    credentialsCard(controller),
                  ],
                  28.heightSpacer,
                  if (controller.hasSomethingToShare)
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
            Utils.rupeesWhole(controller.subscription.pricePaise ?? 0),
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
          fontSize: 12,
          color: ColorRes.grayColor,
        ).tr(),
        BaseTextDMSans(
          text: value,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColorRes.secondaryColor,
        ),
      ],
    );
  }

  /// The Razorpay link the vendor was also sent by SMS — shown so the
  /// salesman can read it out or share it if the SMS does not arrive.
  Widget paymentLinkCard(SubscriptionConfirmationController controller) {
    return Container(
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: ColorRes.warningColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextDMSans(
            text: StringRes.paymentLinkLabel,
            fontSize: 12,
            color: ColorRes.grayColor,
          ).tr(),
          4.heightSpacer,
          SelectableText(
            controller.paymentLinkUrl,
            style: TextStyle(
              fontSize: 14.getFontSize,
              fontWeight: FontWeight.w600,
              fontFamily: FontFamily.poppins,
              color: ColorRes.primaryColor,
            ),
          ),
        ],
      ),
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
          credentialRow(
            StringRes.temporaryPasswordLabel,
            // Empty on a replayed subscribe (a retry after a timeout): the
            // server never stores the password to hand back a second time.
            controller.temporaryPassword.isNotEmpty
                ? controller.temporaryPassword
                : tr(StringRes.temporaryPasswordUnavailable),
          ),
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorRes.secondaryColor,
        ),
      ],
    );
  }
}
