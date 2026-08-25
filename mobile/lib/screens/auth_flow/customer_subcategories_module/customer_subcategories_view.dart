import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'customer_subcategories_controller.dart';

/// Subcategory list for a tapped category (SPEC section 4 items 3-4, task
/// 5.1). Same grid layout as the category browse grid one level up.
class CustomerSubcategoriesView extends StatelessWidget {
  final CategoryModel category;
  final int? zoneId;
  final double? latitude;
  final double? longitude;
  final String? pincode;

  const CustomerSubcategoriesView({
    super.key,
    required this.category,
    required this.zoneId,
    required this.latitude,
    required this.longitude,
    required this.pincode,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerSubcategoriesController>(
      init: CustomerSubcategoriesController(
        category: category,
        zoneId: zoneId,
        latitude: latitude,
        longitude: longitude,
        pincode: pincode,
      ),
      dispose: (_) => Get.delete<CustomerSubcategoriesController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          appBar: AppBar(
            title: BaseTextDMSans(
              text: category.name ?? '',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ColorRes.secondaryColor,
            ),
          ),
          body: Padding(
            padding: EdgeInsets.all(16.getSize),
            child: subcategoryGrid(controller),
          ),
        );
      },
    );
  }

  Widget subcategoryGrid(CustomerSubcategoriesController controller) {
    if (controller.subcategories.isEmpty) {
      return Center(
        child: BaseTextDMSans(
          text: StringRes.noSubcategoriesYet,
          fontSize: 13,
          color: ColorRes.grayColor,
        ).tr(),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.getSize,
        mainAxisSpacing: 10.getSize,
        childAspectRatio: 1,
      ),
      itemCount: controller.subcategories.length,
      itemBuilder: (_, index) => subcategoryCard(controller, controller.subcategories[index]),
    );
  }

  Widget subcategoryCard(CustomerSubcategoriesController controller, SubcategoryModel subcategory) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.getSize),
      onTap: () => controller.selectSubcategory(subcategory),
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
              child: subcategory.iconUrl != null
                  ? Image.network(
                      subcategory.iconUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.build, color: ColorRes.grayColor, size: 32.getSize),
                    )
                  : Icon(Icons.build, color: ColorRes.grayColor, size: 32.getSize),
            ),
            8.heightSpacer,
            BaseTextDMSans(
              text: subcategory.name ?? '',
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
}
