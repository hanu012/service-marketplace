import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_portfolio_controller.dart';

/// Vendor dashboard, Portfolio tab (SPEC section 3 item 5, task 4.5).
class VendorPortfolioView extends StatelessWidget {
  const VendorPortfolioView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPortfolioController>(
      init: VendorPortfolioController(),
      dispose: (_) => Get.delete<VendorPortfolioController>(),
      builder: (controller) {
        if (controller.isLoading && controller.media.isEmpty) {
          return Center(
            child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchPortfolioAPI,
          color: ColorRes.primaryColor,
          child: ListView(
            padding: EdgeInsets.all(16.getSize),
            children: [
              quotaRow(controller),
              16.heightSpacer,
              subcategoryPicker(controller),
              16.heightSpacer,
              uploadButtons(controller),
              24.heightSpacer,
              BaseTextDMSans(
                text: '${tr(StringRes.portfolioTab)} (${controller.media.length})',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
              ),
              12.heightSpacer,
              if (controller.media.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.getSize),
                  child: Center(
                    child: BaseTextDMSans(
                      text: StringRes.noPortfolioYet,
                      fontSize: 13,
                      color: ColorRes.grayColor,
                    ).tr(),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10.getSize,
                    mainAxisSpacing: 10.getSize,
                    childAspectRatio: 1,
                  ),
                  itemCount: controller.media.length,
                  itemBuilder: (_, index) => mediaCard(controller.media[index]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget quotaRow(VendorPortfolioController controller) {
    return Row(
      children: [
        Expanded(child: quotaChip(StringRes.addPhoto, controller.photosQuota)),
        8.widthSpacer,
        Expanded(child: quotaChip(StringRes.addVideo, controller.videosQuota)),
      ],
    );
  }

  Widget quotaChip(String labelKey, QuotaResourceModel? quota) {
    final used = quota?.used ?? 0;
    final max = quota?.max ?? 0;

    return Container(
      padding: EdgeInsets.all(10.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10.getSize),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseTextDMSans(
            text: labelKey,
            fontSize: 12,
            color: ColorRes.grayColor,
          ).tr(),
          4.heightSpacer,
          BaseTextDMSans(
            text: '$used ${tr(StringRes.of)} $max',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorRes.secondaryColor,
          ),
        ],
      ),
    );
  }

  Widget subcategoryPicker(VendorPortfolioController controller) {
    if (controller.subcategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8.getSize,
      runSpacing: 8.getSize,
      children: [
        for (final subcategory in controller.subcategories)
          subcategoryChip(controller, subcategory),
      ],
    );
  }

  Widget subcategoryChip(VendorPortfolioController controller, SelectedServiceItemModel subcategory) {
    final selected = controller.selectedSubcategoryId == subcategory.id;

    return InkWell(
      onTap: subcategory.id == null ? null : () => controller.selectSubcategory(subcategory.id!),
      borderRadius: BorderRadius.circular(20.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 8.getSize),
        decoration: BoxDecoration(
          color: selected ? ColorRes.primaryColor : ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(20.getSize),
          border: Border.all(
            color: selected ? ColorRes.primaryColor : ColorRes.borderColor,
          ),
        ),
        child: BaseTextDMSans(
          text: subcategory.name ?? '',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? ColorRes.backgroundColor : ColorRes.secondaryColor,
        ),
      ),
    );
  }

  Widget uploadButtons(VendorPortfolioController controller) {
    return Row(
      children: [
        Expanded(
          child: BaseRaisedButton(
            onPressed: controller.isUploading ? null : controller.pickAndUploadPhoto,
            buttonText: StringRes.addPhoto,
            buttonColor: ColorRes.primaryColor,
          ),
        ),
        8.widthSpacer,
        Expanded(
          child: BaseRaisedButton(
            onPressed: controller.isUploading ? null : controller.pickAndUploadVideo,
            buttonText: StringRes.addVideo,
            buttonColor: ColorRes.surfaceElevatedColor,
            textColor: ColorRes.secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget mediaCard(PortfolioMediaModel item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.getSize),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: ColorRes.surfaceElevatedColor),
          if (item.type == 'video')
            Center(
              child: Icon(Icons.play_circle_outline, color: ColorRes.grayColor, size: 40.getSize),
            )
          else if (item.url != null)
            Image.network(
              item.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.broken_image, color: ColorRes.grayColor),
            ),
          Positioned(
            left: 6.getSize,
            bottom: 6.getSize,
            right: 6.getSize,
            child: statusBadge(item.moderationStatus),
          ),
        ],
      ),
    );
  }

  Widget statusBadge(String? status) {
    final labelKey = switch (status) {
      'approved' => StringRes.moderationApproved,
      'rejected' => StringRes.moderationRejected,
      _ => StringRes.moderationPending,
    };

    final color = switch (status) {
      'approved' => ColorRes.primaryColor,
      'rejected' => ColorRes.errorColor,
      _ => ColorRes.grayColor,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.getSize, vertical: 4.getSize),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6.getSize),
      ),
      child: BaseTextDMSans(
        text: labelKey,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: ColorRes.backgroundColor,
      ).tr(),
    );
  }
}
