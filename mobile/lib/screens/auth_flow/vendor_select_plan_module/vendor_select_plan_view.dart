import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_select_plan_controller.dart';

/// Vendor self-service, step 1 — plan selection (SPEC section 3.2).
class VendorSelectPlanView extends StatelessWidget {
  const VendorSelectPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorSelectPlanController>(
      init: VendorSelectPlanController(),
      dispose: (_) => Get.delete<VendorSelectPlanController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            toolbarHeight: 44.getSize,
            actions: [
              TextButton(
                onPressed: controller.logoutAPI,
                child: BaseTextDMSans(
                  text: StringRes.signOut,
                  fontSize: 14,
                  color: ColorRes.primaryColor,
                ).tr(),
              ),
            ],
          ),
          bottomNavigationBar: getBottomButton(controller, context),
          body: Utils.authLayout(
            onSkipTap: null,
            title: StringRes.selectPlanTitle,
            desc: StringRes.selectPlanDesc,
            isLogin: false,
            isForCustomer: false,
            skipTap: false,
            contentWidget: mainBody(controller),
          ),
        );
      },
    );
  }

  Widget mainBody(VendorSelectPlanController controller) {
    if (controller.isLoading && controller.plans.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.getSize),
        child: Center(
          child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final plan in controller.plans) ...[
          planCard(controller, plan),
          16.heightSpacer,
        ],
      ],
    );
  }

  Widget planCard(VendorSelectPlanController controller, PlanModel plan) {
    final selected = controller.selectedPlanId == plan.id;

    return InkWell(
      onTap: () => controller.selectPlan(plan.id!),
      borderRadius: BorderRadius.circular(12.getSize),
      child: Container(
        padding: EdgeInsets.all(16.getSize),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(12.getSize),
          border: Border.all(
            color: selected ? ColorRes.primaryColor : ColorRes.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: BaseTextDMSans(
                    text: plan.name ?? '',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.start,
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? ColorRes.primaryColor : ColorRes.grayColor,
                  size: 20.getSize,
                ),
              ],
            ),
            6.heightSpacer,
            BaseTextDMSans(
              text: '₹${plan.priceRupees ?? '0'} '
                  '(${plan.durationDays ?? 0} ${tr(StringRes.perDay)})',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ColorRes.primaryColor,
              textAlign: TextAlign.start,
            ),
            10.heightSpacer,
            Wrap(
              spacing: 8.getSize,
              runSpacing: 8.getSize,
              children: [
                quotaChip('${plan.maxCategories ?? 0} categories'),
                quotaChip('${plan.maxSubcategories ?? 0} subcategories'),
                quotaChip('${plan.maxZones ?? 0} zones'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget quotaChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.getSize, vertical: 4.getSize),
      decoration: BoxDecoration(
        color: ColorRes.backgroundColor,
        borderRadius: BorderRadius.circular(20.getSize),
      ),
      child: BaseTextDMSans(
        text: label,
        fontSize: 11,
        color: ColorRes.grayColor,
      ),
    );
  }

  Widget getBottomButton(VendorSelectPlanController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.continueToServices,
        buttonText: StringRes.continueLabel,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
