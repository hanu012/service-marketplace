import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'select_services_controller.dart';

/// Add Vendor, step 2b — categories/subcategories then zones (SPEC 2.2).
class SelectServicesView extends StatelessWidget {
  final int vendorId;
  final PlanModel plan;
  final String businessName;
  final String loginEmail;

  const SelectServicesView({
    super.key,
    required this.vendorId,
    required this.plan,
    required this.businessName,
    required this.loginEmail,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SelectServicesController>(
      init: SelectServicesController(
        vendorId: vendorId,
        plan: plan,
        businessName: businessName,
        loginEmail: loginEmail,
      ),
      dispose: (_) => Get.delete<SelectServicesController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          bottomNavigationBar: getBottomButton(controller, context),
          body: Utils.authLayout(
            onSkipTap: null,
            title: StringRes.selectServicesTitle,
            desc: StringRes.selectServicesDesc,
            isLogin: false,
            isForCustomer: false,
            skipTap: true,
            contentWidget: mainBody(controller),
          ),
        );
      },
    );
  }

  Widget mainBody(SelectServicesController controller) {
    if (controller.isLoading && controller.categories.isEmpty && controller.zones.isEmpty) {
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
        sectionHeader(
          StringRes.categoriesSection,
          controller.selectedCategoryIds.length,
          controller.maxCategories,
        ),
        4.heightSpacer,
        sectionHeader(
          StringRes.subcategoriesCounted,
          controller.selectedSubcategoryIds.length,
          controller.maxSubcategories,
        ),
        12.heightSpacer,
        for (final category in controller.categories) categoryBlock(controller, category),
        24.heightSpacer,
        sectionHeader(
          StringRes.zonesSection,
          controller.selectedZoneIds.length,
          controller.maxZones,
        ),
        12.heightSpacer,
        for (final zone in controller.zones) zoneBlock(controller, zone),
      ],
    );
  }

  Widget sectionHeader(String labelKey, int selected, int max) {
    return Row(
      children: [
        BaseTextDMSans(
          text: labelKey,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: ColorRes.secondaryColor,
        ).tr(),
        8.widthSpacer,
        BaseTextDMSans(
          text: '$selected ${tr(StringRes.of)} $max',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected >= max && max > 0 ? ColorRes.errorColor : ColorRes.primaryColor,
        ),
      ],
    );
  }

  Widget categoryBlock(SelectServicesController controller, CategoryModel category) {
    final selected = controller.isCategorySelected(category.id ?? -1);
    final enabled = selected || !controller.categoryQuotaReached;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 6.getSize),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(
            color: selected ? ColorRes.primaryColor : ColorRes.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkboxRow(
              label: category.name ?? '',
              selected: selected,
              enabled: enabled,
              fontWeight: FontWeight.w600,
              onTap: () => controller.toggleCategory(category),
            ),
            for (final sub in category.subcategories)
              Padding(
                padding: EdgeInsets.only(left: 20.getSize),
                child: subcategoryRow(controller, sub, category),
              ),
          ],
        ),
      ),
    );
  }

  Widget subcategoryRow(
    SelectServicesController controller,
    SubcategoryModel subcategory,
    CategoryModel parent,
  ) {
    final selected = controller.isSubcategorySelected(subcategory.id ?? -1);
    final enabled = selected || !controller.subcategoryQuotaReached;

    return checkboxRow(
      label: subcategory.name ?? '',
      selected: selected,
      enabled: enabled,
      fontWeight: FontWeight.w400,
      onTap: () => controller.toggleSubcategory(subcategory, parent),
    );
  }

  Widget zoneBlock(SelectServicesController controller, ZoneModel zone) {
    // A standalone top-level zone with no sub-zones is itself a leaf and
    // directly selectable (SPEC section 8). Only a zone with children is a
    // non-selectable group header.
    if (zone.isLeaf) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8.getSize),
        child: zoneCheckboxRow(controller, zone),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 8.getSize),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(color: ColorRes.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseTextDMSans(
              text: zone.name ?? '',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: ColorRes.grayColor,
              textAlign: TextAlign.start,
            ),
            6.heightSpacer,
            for (final child in zone.children)
              Padding(
                padding: EdgeInsets.only(left: 8.getSize, bottom: 4.getSize),
                child: zoneCheckboxRow(controller, child),
              ),
          ],
        ),
      ),
    );
  }

  Widget zoneCheckboxRow(SelectServicesController controller, ZoneModel zone) {
    final selected = controller.isZoneSelected(zone.id ?? -1);
    final enabled = selected || !controller.zoneQuotaReached;

    return checkboxRow(
      label: zone.name ?? '',
      selected: selected,
      enabled: enabled,
      fontWeight: FontWeight.w400,
      onTap: () => controller.toggleZone(zone),
    );
  }

  Widget checkboxRow({
    required String label,
    required bool selected,
    required bool enabled,
    required FontWeight fontWeight,
    required VoidCallback onTap,
  }) {
    final color = !enabled
        ? ColorRes.grayColor.withValues(alpha: 0.4)
        : (selected ? ColorRes.secondaryColor : ColorRes.grayColor);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.getSize),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18.getSize,
              color: !enabled
                  ? ColorRes.grayColor.withValues(alpha: 0.4)
                  : (selected ? ColorRes.primaryColor : ColorRes.grayColor),
            ),
            8.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: label,
                fontSize: 13,
                fontWeight: fontWeight,
                color: color,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getBottomButton(SelectServicesController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: () => onContinueTap(controller),
        buttonText: StringRes.continueLabel,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }

  void onContinueTap(SelectServicesController controller) {
    if (!controller.validateSelections()) {
      return;
    }

    Get.dialog(paymentModeDialog(controller));
  }

  /// SPEC section 2.2: "choose payment mode -> confirmation dialog -> single
  /// API call." Wrapped in its own GetBuilder so a tap updates the radio
  /// selection live without closing the dialog.
  Widget paymentModeDialog(SelectServicesController controller) {
    return GetBuilder<SelectServicesController>(
      builder: (controller) {
        return AlertDialog(
          backgroundColor: ColorRes.surfaceColor,
          title: BaseTextDMSans(
            text: StringRes.choosePaymentMode,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColorRes.secondaryColor,
          ).tr(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              paymentModeOption(controller, 'cash', StringRes.paymentModeCash),
              paymentModeOption(controller, 'online', StringRes.paymentModeOnline),
              paymentModeOption(controller, 'free', StringRes.paymentModeFree),
              if (controller.selectedPaymentMode == 'free') ...[
                8.heightSpacer,
                freeTrialDurationPicker(controller),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: BaseTextDMSans(
                text: StringRes.cancel,
                color: ColorRes.grayColor,
              ).tr(),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                controller.subscribeAPI();
              },
              child: BaseTextDMSans(
                text: StringRes.confirmSubscribe,
                color: ColorRes.primaryColor,
                fontWeight: FontWeight.w600,
              ).tr(),
            ),
          ],
        );
      },
    );
  }

  Widget freeTrialDurationPicker(SelectServicesController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 8.getSize),
      decoration: BoxDecoration(
        color: ColorRes.backgroundColor,
        borderRadius: BorderRadius.circular(10.getSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextDMSans(
            text: StringRes.freeTrialDurationLabel,
            fontSize: 12,
            color: ColorRes.grayColor,
          ).tr(),
          6.heightSpacer,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: controller.freeTrialDays > 1
                    ? () => controller.setFreeTrialDays(controller.freeTrialDays - 1)
                    : null,
                icon: Icon(Icons.remove_circle_outline, color: ColorRes.primaryColor),
              ),
              BaseTextDMSans(
                text: '${controller.freeTrialDays} ${tr(StringRes.daysUnit)}',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
              ),
              IconButton(
                onPressed: controller.freeTrialDays < controller.freeTrialMaxDays
                    ? () => controller.setFreeTrialDays(controller.freeTrialDays + 1)
                    : null,
                icon: Icon(Icons.add_circle_outline, color: ColorRes.primaryColor),
              ),
            ],
          ),
          BaseTextDMSans(
            text: '${tr(StringRes.freeTrialCappedAt)} ${controller.freeTrialMaxDays} ${tr(StringRes.daysUnit)}',
            fontSize: 11,
            color: ColorRes.grayColor,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget paymentModeOption(SelectServicesController controller, String mode, String labelKey) {
    final selected = controller.selectedPaymentMode == mode;

    return InkWell(
      onTap: () => controller.selectPaymentMode(mode),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.getSize),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20.getSize,
              color: selected ? ColorRes.primaryColor : ColorRes.grayColor,
            ),
            10.widthSpacer,
            BaseTextDMSans(
              text: labelKey,
              fontSize: 14,
              color: ColorRes.secondaryColor,
            ).tr(),
          ],
        ),
      ),
    );
  }
}
