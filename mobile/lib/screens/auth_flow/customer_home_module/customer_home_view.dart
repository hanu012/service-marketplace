import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../customer_favorites_module/customer_favorites_view.dart';
import '../customer_login_module/customer_login_view.dart';
import '../customer_subcategories_module/customer_subcategories_view.dart';
import '../delete_account_module/delete_account_view.dart';
import 'customer_home_controller.dart';

/// Customer home (SPEC section 4.2/4, tasks 4.6 and 5.1) — location header
/// plus the category browse grid below it.
class CustomerHomeView extends StatelessWidget {
  const CustomerHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerHomeController>(
      init: CustomerHomeController(),
      dispose: (_) => Get.delete<CustomerHomeController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          appBar: AppBar(
            title: BaseTextDMSans(
              text: StringRes.customerHomeTitle,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ColorRes.secondaryColor,
            ).tr(),
            actions: [
              IconButton(
                onPressed: () => Get.to(() => const CustomerFavoritesView()),
                icon: Icon(Icons.favorite, color: ColorRes.errorColor, size: 22.getSize),
                tooltip: tr(StringRes.favoritesTab),
              ),
              IconButton(
                onPressed: () => Get.to(
                  () => DeleteAccountView(
                    loginViewBuilder: () => const CustomerLoginView(),
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
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.getSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                locationHeader(controller),
                24.heightSpacer,
                BaseTextDMSans(
                  text: StringRes.browseCategoriesTitle,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColorRes.secondaryColor,
                ).tr(),
                12.heightSpacer,
                categoryGrid(controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget categoryGrid(CustomerHomeController controller) {
    if (controller.isLoadingCategories && controller.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.getSize),
        child: Center(
          child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
        ),
      );
    }

    if (controller.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.getSize),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BaseTextDMSans(
                text: StringRes.noCategoriesYet,
                fontSize: 13,
                color: ColorRes.grayColor,
              ).tr(),
              12.heightSpacer,
              TextButton(
                onPressed: controller.fetchCategoriesAPI,
                child: BaseTextDMSans(
                  text: StringRes.retry,
                  fontSize: 13,
                  color: ColorRes.primaryColor,
                ).tr(),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.getSize,
        mainAxisSpacing: 10.getSize,
        childAspectRatio: 1,
      ),
      itemCount: controller.categories.length,
      itemBuilder: (_, index) => categoryCard(controller, controller.categories[index]),
    );
  }

  Widget categoryCard(CustomerHomeController controller, CategoryModel category) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.getSize),
      onTap: () => Get.to(
        () => CustomerSubcategoriesView(
          category: category,
          zoneId: controller.zone?.id,
          latitude: controller.latitude,
          longitude: controller.longitude,
          pincode: controller.pincode,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(12.getSize),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(color: ColorRes.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: category.iconUrl != null
                  ? Image.network(
                      category.iconUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.category, color: ColorRes.grayColor, size: 32.getSize),
                    )
                  : Icon(Icons.category, color: ColorRes.grayColor, size: 32.getSize),
            ),
            8.heightSpacer,
            BaseTextDMSans(
              text: category.name ?? '',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorRes.secondaryColor,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget locationHeader(CustomerHomeController controller) {
    return Container(
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: controller.isDetecting
          ? detectingState()
          : controller.showPincodeFallback
              ? pincodeFallbackState(controller)
              : resolvedState(controller),
    );
  }

  Widget detectingState() {
    return Row(
      children: [
        CupertinoActivityIndicator(color: ColorRes.primaryColor),
        10.widthSpacer,
        BaseTextDMSans(
          text: StringRes.detectingLocation,
          fontSize: 13,
          color: ColorRes.grayColor,
        ).tr(),
      ],
    );
  }

  Widget resolvedState(CustomerHomeController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.location_on, color: ColorRes.primaryColor, size: 20.getSize),
              8.widthSpacer,
              Expanded(
                child: BaseTextDMSans(
                  text: controller.zone?.name ?? '',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ColorRes.secondaryColor,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: controller.detectLocation,
          child: BaseTextDMSans(
            text: StringRes.changeLocation,
            fontSize: 13,
            color: ColorRes.primaryColor,
          ).tr(),
        ),
      ],
    );
  }

  Widget pincodeFallbackState(CustomerHomeController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_off, color: ColorRes.errorColor, size: 20.getSize),
            8.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: StringRes.notInYourAreaYet,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
                textAlign: TextAlign.start,
              ).tr(),
            ),
          ],
        ),
        12.heightSpacer,
        Row(
          children: [
            Expanded(
              child: BaseTextField(
                controller: controller.pincodeController,
                hintText: tr(StringRes.enterPincode),
                isShowBorder: true,
                textInputType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => controller.submitPincodeAPI(),
              ),
            ),
            8.widthSpacer,
            BaseRaisedButton(
              onPressed: controller.submitPincodeAPI,
              buttonText: StringRes.submitPincode,
              buttonColor: ColorRes.primaryColor,
              isExpanded: false,
            ),
          ],
        ),
        8.heightSpacer,
        Center(
          child: TextButton(
            onPressed: controller.detectLocation,
            child: BaseTextDMSans(
              text: StringRes.changeLocation,
              fontSize: 13,
              color: ColorRes.primaryColor,
            ).tr(),
          ),
        ),
      ],
    );
  }
}
