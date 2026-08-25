import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_select_services_controller.dart';

/// Vendor self-service, step 2 — categories/subcategories then zones
/// (SPEC section 3.2). Also serves task 4.4's "add more within remaining
/// quota" when constructed with `isAddingMore: true` plus the vendor's
/// existing selections — see the controller's docblock.
class VendorSelectServicesView extends StatelessWidget {
  final int vendorId;
  final PlanModel plan;
  final bool isAddingMore;
  final Set<int> existingCategoryIds;
  final Set<int> existingSubcategoryIds;
  final Set<int> existingZoneIds;

  const VendorSelectServicesView({
    super.key,
    required this.vendorId,
    required this.plan,
    this.isAddingMore = false,
    this.existingCategoryIds = const {},
    this.existingSubcategoryIds = const {},
    this.existingZoneIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorSelectServicesController>(
      init: VendorSelectServicesController(
        vendorId: vendorId,
        plan: plan,
        isAddingMore: isAddingMore,
        existingCategoryIds: existingCategoryIds,
        existingSubcategoryIds: existingSubcategoryIds,
        existingZoneIds: existingZoneIds,
      ),
      dispose: (_) => Get.delete<VendorSelectServicesController>(),
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

  Widget mainBody(VendorSelectServicesController controller) {
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

  Widget categoryBlock(VendorSelectServicesController controller, CategoryModel category) {
    final selected = controller.isCategorySelected(category.id ?? -1);
    final locked = controller.isCategoryLocked(category.id ?? -1);
    final enabled = !locked && (selected || !controller.categoryQuotaReached);

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
    VendorSelectServicesController controller,
    SubcategoryModel subcategory,
    CategoryModel parent,
  ) {
    final selected = controller.isSubcategorySelected(subcategory.id ?? -1);
    final locked = controller.isSubcategoryLocked(subcategory.id ?? -1);
    final enabled = !locked && (selected || !controller.subcategoryQuotaReached);

    return checkboxRow(
      label: subcategory.name ?? '',
      selected: selected,
      enabled: enabled,
      fontWeight: FontWeight.w400,
      onTap: () => controller.toggleSubcategory(subcategory, parent),
    );
  }

  Widget zoneBlock(VendorSelectServicesController controller, ZoneModel zone) {
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

  Widget zoneCheckboxRow(VendorSelectServicesController controller, ZoneModel zone) {
    final selected = controller.isZoneSelected(zone.id ?? -1);
    final locked = controller.isZoneLocked(zone.id ?? -1);
    final enabled = !locked && (selected || !controller.zoneQuotaReached);

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

  Widget getBottomButton(VendorSelectServicesController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.isAddingMore ? controller.addServicesAPI : controller.subscribeAPI,
        buttonText: controller.isAddingMore ? StringRes.addMoreServices : StringRes.confirmSubscribe,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
