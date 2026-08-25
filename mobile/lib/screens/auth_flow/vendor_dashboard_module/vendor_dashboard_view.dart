import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../delete_account_module/delete_account_view.dart';
import '../vendor_leads_module/vendor_leads_view.dart';
import '../vendor_login_module/vendor_login_view.dart';
import '../vendor_portfolio_module/vendor_portfolio_view.dart';
import '../vendor_reviews_module/vendor_reviews_view.dart';
import '../vendor_select_plan_module/vendor_select_plan_view.dart';
import '../vendor_select_services_module/vendor_select_services_view.dart';
import 'vendor_dashboard_controller.dart';

/// Vendor dashboard (SPEC section 3.2/3.9) — Overview, Services (task 4.4),
/// Portfolio (task 4.5), Leads and Reviews (task 4.8, closing Phase 4)
/// tabs, same `DefaultTabController`/`TabBar`/`TabBarView` shape
/// `salesman_home_view.dart` already uses.
///
/// Overview and Services stay on the SAME controller/single fetch — both
/// are views over the exact same GET /api/vendors/me response (quota bars
/// vs. the actual item list), so splitting them would mean two independent
/// fetches of the same data, able to disagree with each other mid-session.
/// Portfolio, Leads and Reviews are each genuinely independent data (their
/// own list, their own endpoint), so each gets its own module/controller —
/// matching the salesman_home_module -> my_vendors_module/earnings_module
/// split instead.
class VendorDashboardView extends StatelessWidget {
  const VendorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorDashboardController>(
      init: VendorDashboardController(),
      dispose: (_) => Get.delete<VendorDashboardController>(),
      builder: (controller) {
        final subscription = controller.vendorMe?.activeSubscription;
        final hasSubscription = !controller.isLoading && subscription != null;

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: ColorRes.backgroundColor,
            appBar: AppBar(
              title: BaseTextDMSans(
                text: StringRes.vendorHomeTitle,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
              ).tr(),
              actions: [
                IconButton(
                  onPressed: () => Get.to(
                    () => DeleteAccountView(
                      loginViewBuilder: () => const VendorLoginView(),
                    ),
                  ),
                  icon: Icon(Icons.person_remove_outlined, color: ColorRes.grayColor, size: 20.getSize),
                  tooltip: tr(StringRes.deleteAccountMenuItem),
                ),
                TextButton(
                  onPressed: controller.logoutAPI,
                  child: BaseTextDMSans(
                    text: StringRes.signOut,
                    fontSize: 14,
                    color: ColorRes.primaryColor,
                  ).tr(),
                ),
              ],
              bottom: hasSubscription
                  ? TabBar(
                      isScrollable: true,
                      labelColor: ColorRes.primaryColor,
                      unselectedLabelColor: ColorRes.grayColor,
                      indicatorColor: ColorRes.primaryColor,
                      tabs: [
                        Tab(text: tr(StringRes.overviewTab)),
                        Tab(text: tr(StringRes.servicesTab)),
                        Tab(text: tr(StringRes.portfolioTab)),
                        Tab(text: tr(StringRes.leadsTab)),
                        Tab(text: tr(StringRes.reviewsTab)),
                      ],
                    )
                  : null,
            ),
            body: mainBody(controller, hasSubscription),
          ),
        );
      },
    );
  }

  Widget mainBody(VendorDashboardController controller, bool hasSubscription) {
    if (controller.isLoading && controller.vendorMe == null) {
      return Center(
        child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
      );
    }

    if (!hasSubscription) {
      return noActiveSubscriptionState(controller);
    }

    return TabBarView(
      children: [
        overviewTab(controller),
        servicesTab(controller),
        const VendorPortfolioView(),
        const VendorLeadsView(),
        const VendorReviewsView(),
      ],
    );
  }

  Widget overviewTab(VendorDashboardController controller) {
    final subscription = controller.vendorMe!.activeSubscription!;

    return RefreshIndicator(
      onRefresh: controller.fetchVendorMeAPI,
      color: ColorRes.primaryColor,
      child: ListView(
        padding: EdgeInsets.all(16.getSize),
        children: [
          BaseTextDMSans(
            text: controller.vendorMe?.businessName ?? '',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ColorRes.secondaryColor,
          ),
          20.heightSpacer,
          planSummaryCard(subscription),
          20.heightSpacer,
          BaseTextDMSans(
            text: StringRes.quotaSectionTitle,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorRes.secondaryColor,
          ).tr(),
          12.heightSpacer,
          quotaBar(StringRes.categoriesSection, subscription.categories),
          10.heightSpacer,
          quotaBar(StringRes.subcategoriesCounted, subscription.subcategories),
          10.heightSpacer,
          quotaBar(StringRes.zonesSection, subscription.zones),
        ],
      ),
    );
  }

  Widget servicesTab(VendorDashboardController controller) {
    final subscription = controller.vendorMe!.activeSubscription!;

    return RefreshIndicator(
      onRefresh: controller.fetchVendorMeAPI,
      color: ColorRes.primaryColor,
      child: ListView(
        padding: EdgeInsets.all(16.getSize),
        children: [
          serviceSection(
            StringRes.categoriesSection,
            subscription.categories,
            subscription.selectedCategories,
          ),
          16.heightSpacer,
          serviceSection(
            StringRes.subcategoriesCounted,
            subscription.subcategories,
            subscription.selectedSubcategories,
          ),
          16.heightSpacer,
          serviceSection(
            StringRes.zonesSection,
            subscription.zones,
            subscription.selectedZones,
          ),
          24.heightSpacer,
          BaseRaisedButton(
            onPressed: () => addMoreServices(controller),
            buttonText: StringRes.addMoreServices,
            buttonColor: ColorRes.primaryColor,
          ),
        ],
      ),
    );
  }

  Future<void> addMoreServices(VendorDashboardController controller) async {
    final subscription = controller.vendorMe!.activeSubscription!;

    await Get.to(
      () => VendorSelectServicesView(
        // Unused by addServicesAPI (task 4.4 resolves the vendor from the
        // auth token server-side) — kept only because the picker screen is
        // shared with the initial-subscribe flow, which does need it.
        vendorId: controller.vendorMe?.id ?? 0,
        plan: PlanModel(
          maxCategories: subscription.categories?.max,
          maxSubcategories: subscription.subcategories?.max,
          maxZones: subscription.zones?.max,
        ),
        isAddingMore: true,
        existingCategoryIds: subscription.selectedCategories
            .map((e) => e.id)
            .whereType<int>()
            .toSet(),
        existingSubcategoryIds: subscription.selectedSubcategories
            .map((e) => e.id)
            .whereType<int>()
            .toSet(),
        existingZoneIds:
            subscription.selectedZones.map((e) => e.id).whereType<int>().toSet(),
      ),
    );

    controller.fetchVendorMeAPI();
  }

  Widget serviceSection(
    String labelKey,
    QuotaResourceModel? quota,
    List<SelectedServiceItemModel> items,
  ) {
    final used = quota?.used ?? 0;
    final max = quota?.max ?? 0;
    final remaining = (max - used) < 0 ? 0 : (max - used);

    return Container(
      padding: EdgeInsets.all(12.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10.getSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BaseTextDMSans(
                text: labelKey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
              ).tr(),
              BaseTextDMSans(
                text: '$used ${tr(StringRes.of)} $max ($remaining ${tr(StringRes.remainingLabel)})',
                fontSize: 12,
                color: ColorRes.grayColor,
              ),
            ],
          ),
          10.heightSpacer,
          if (items.isEmpty)
            BaseTextDMSans(
              text: StringRes.noServicesSelected,
              fontSize: 12,
              color: ColorRes.grayColor,
            ).tr()
          else
            Wrap(
              spacing: 8.getSize,
              runSpacing: 8.getSize,
              children: [for (final item in items) serviceChip(item.name ?? '')],
            ),
        ],
      ),
    );
  }

  Widget serviceChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.getSize, vertical: 6.getSize),
      decoration: BoxDecoration(
        color: ColorRes.backgroundColor,
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: BaseTextDMSans(
        text: label,
        fontSize: 12,
        color: ColorRes.secondaryColor,
      ),
    );
  }

  Widget planSummaryCard(ActiveSubscriptionModel subscription) {
    final daysRemaining = subscription.daysRemaining ?? 0;

    return Container(
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: ColorRes.primaryColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseTextDMSans(
                text: StringRes.planLabel,
                fontSize: 12,
                color: ColorRes.grayColor,
              ).tr(),
              4.heightSpacer,
              BaseTextDMSans(
                text: subscription.planName ?? '',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorRes.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BaseTextDMSans(
                text: StringRes.daysLeft,
                fontSize: 12,
                color: ColorRes.grayColor,
              ).tr(),
              4.heightSpacer,
              BaseTextDMSans(
                text: daysRemaining < 0 ? '0' : '$daysRemaining',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: daysRemaining <= 7 ? ColorRes.errorColor : ColorRes.secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget quotaBar(String labelKey, QuotaResourceModel? resource) {
    final used = resource?.used ?? 0;
    final max = resource?.max ?? 0;
    final fraction = max > 0 ? (used / max).clamp(0, 1).toDouble() : 0.0;

    return Container(
      padding: EdgeInsets.all(12.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10.getSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BaseTextDMSans(
                text: labelKey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ColorRes.secondaryColor,
              ).tr(),
              BaseTextDMSans(
                text: '$used ${tr(StringRes.of)} $max',
                fontSize: 12,
                color: ColorRes.grayColor,
              ),
            ],
          ),
          8.heightSpacer,
          ClipRRect(
            borderRadius: BorderRadius.circular(4.getSize),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6.getSize,
              backgroundColor: ColorRes.backgroundColor,
              valueColor: AlwaysStoppedAnimation(ColorRes.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget noActiveSubscriptionState(VendorDashboardController controller) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.getSize),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BaseTextDMSans(
              text: StringRes.noActiveSubscription,
              fontSize: 14,
              color: ColorRes.grayColor,
              textAlign: TextAlign.center,
            ).tr(),
            16.heightSpacer,
            BaseRaisedButton(
              onPressed: () => Get.off(() => const VendorSelectPlanView()),
              buttonText: StringRes.subscribeNow,
              buttonColor: ColorRes.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
