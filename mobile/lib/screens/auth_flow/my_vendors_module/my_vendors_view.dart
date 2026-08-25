import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../../vendor_flow/add_vendor_module/add_vendor_view.dart';
import 'my_vendors_controller.dart';

/// Salesman home, My Vendors tab (SPEC section 2.3).
class MyVendorsView extends StatelessWidget {
  const MyVendorsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyVendorsController>(
      init: MyVendorsController(),
      dispose: (_) => Get.delete<MyVendorsController>(),
      builder: (controller) {
        if (controller.isLoading && controller.vendors.isEmpty) {
          return Center(
            child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
          );
        }

        if (controller.vendors.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.getSize),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BaseTextDMSans(
                    text: StringRes.noVendorsYet,
                    fontSize: 14,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.center,
                  ).tr(),
                  16.heightSpacer,
                  BaseRaisedButton(
                    onPressed: () async {
                      await Get.to(() => const AddVendorView());
                      controller.fetchVendorsAPI();
                    },
                    buttonText: StringRes.addVendorTitle,
                    buttonColor: ColorRes.primaryColor,
                    isExpanded: false,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchVendorsAPI,
          color: ColorRes.primaryColor,
          child: ListView.separated(
            padding: EdgeInsets.all(16.getSize),
            itemCount: controller.vendors.length,
            separatorBuilder: (_, _) => 12.heightSpacer,
            itemBuilder: (_, index) => vendorRow(controller.vendors[index]),
          ),
        );
      },
    );
  }

  Widget vendorRow(SalesmanVendorModel vendor) {
    return Container(
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextDMSans(
            text: vendor.businessName ?? '',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorRes.secondaryColor,
            textAlign: TextAlign.start,
          ),
          6.heightSpacer,
          Row(
            children: [
              BaseTextDMSans(
                text: vendor.planName ?? tr(StringRes.notSubscribed),
                fontSize: 13,
                color: vendor.planName == null ? ColorRes.grayColor : ColorRes.primaryColor,
              ),
              if (vendor.daysToExpiry != null) ...[
                8.widthSpacer,
                BaseTextDMSans(
                  text: expiryText(vendor.daysToExpiry!),
                  fontSize: 13,
                  color: vendor.daysToExpiry! < 0 ? ColorRes.errorColor : ColorRes.grayColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String expiryText(int daysToExpiry) {
    if (daysToExpiry < 0) {
      return '${tr(StringRes.expiredDaysAgo)} ${-daysToExpiry} ${tr(StringRes.daysAgoSuffix)}';
    }

    return '$daysToExpiry ${tr(StringRes.daysLeft)}';
  }
}
