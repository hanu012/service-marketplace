import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'add_vendor_controller.dart';

/// Add Vendor, step 1 — business info and KYC (SPEC section 2.2).
///
/// Same shape as the ported reference module: StatelessWidget, GetBuilder
/// with init + dispose, state read off the builder argument named
/// `controller`, Base* widgets, StringRes with .tr().
class AddVendorView extends StatelessWidget {
  const AddVendorView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddVendorController>(
      init: AddVendorController(),
      dispose: (_) => Get.delete<AddVendorController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: getBottomButton(controller, context),
          body: mainBody(controller),
        );
      },
    );
  }

  Widget mainBody(AddVendorController controller) {
    return Utils.authLayout(
      onSkipTap: null,
      title: StringRes.addVendorTitle,
      desc: StringRes.addVendorDesc,
      isLogin: false,
      isForCustomer: false,
      skipTap: true,
      contentWidget: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only shown once the draft exists server-side, so it is a
            // statement of fact rather than a promise.
            if (controller.draftVendorId != null) ...[
              draftBanner(),
              20.heightSpacer,
            ],

            fieldLabel(StringRes.businessName),
            8.heightSpacer,
            BaseTextField(
              controller: controller.businessNameController,
              hintText: tr(StringRes.enterBusinessName),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) => controller.validateRequired(
                value,
                StringRes.enterBusinessName,
              ),
            ),
            20.heightSpacer,

            fieldLabel(StringRes.ownerName),
            8.heightSpacer,
            BaseTextField(
              controller: controller.ownerNameController,
              hintText: tr(StringRes.enterOwnerName),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) => controller.validateRequired(
                value,
                StringRes.enterOwnerName,
              ),
            ),
            20.heightSpacer,

            fieldLabel(StringRes.phone),
            8.heightSpacer,
            BaseTextField(
              controller: controller.phoneController,
              hintText: tr(StringRes.enterPhone),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textInputType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: controller.validatePhone,
            ),
            20.heightSpacer,

            fieldLabel(StringRes.email),
            8.heightSpacer,
            BaseTextField(
              controller: controller.emailController,
              hintText: tr(StringRes.enterYourEmail),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              textInputType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: controller.validateEmail,
            ),
            20.heightSpacer,

            fieldLabel(StringRes.address),
            8.heightSpacer,
            BaseTextField(
              controller: controller.addressController,
              hintText: tr(StringRes.enterAddress),
              isShowBorder: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
            ),
            28.heightSpacer,

            fieldLabel(StringRes.shopLocation),
            8.heightSpacer,
            locationTile(controller),
            28.heightSpacer,

            fieldLabel(StringRes.kycSection),
            12.heightSpacer,

            uploadTile(
              label: StringRes.shopPhoto,
              hasFile: controller.hasShopPhoto,
              onTap: controller.pickShopPhoto,
            ),
            16.heightSpacer,

            uploadTile(
              label: StringRes.idProof,
              hasFile: controller.hasIdProof,
              onTap: controller.pickIdProof,
            ),

            // Only asked for once there is a document to label — the server
            // rejects an ID proof without a type, since the verification
            // queue has to show reviewers what they are looking at.
            if (controller.hasIdProof) ...[
              16.heightSpacer,
              fieldLabel(StringRes.idProofTypeLabel),
              8.heightSpacer,
              idProofTypeSelector(controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget draftBanner() {
    return Container(
      padding: EdgeInsets.all(12.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(10.getSize),
        border: Border.all(color: ColorRes.primaryColorDark),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_outlined,
              color: ColorRes.primaryColor, size: 18.getSize),
          8.widthSpacer,
          Expanded(
            child: BaseTextDMSans(
              text: StringRes.draftBanner,
              fontSize: 12,
              color: ColorRes.grayColor,
              textAlign: TextAlign.start,
              maxLines: 2,
            ).tr(),
          ),
        ],
      ),
    );
  }

  Widget fieldLabel(String key) {
    return BaseTextDMSans(
      text: key,
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: ColorRes.secondaryColor,
      textAlign: TextAlign.start,
    ).tr();
  }

  Widget uploadTile({
    required String label,
    required bool hasFile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16.getSize,
          vertical: 14.getSize,
        ),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(
            color: hasFile ? ColorRes.primaryColor : ColorRes.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle_outline : Icons.upload_outlined,
              color: hasFile ? ColorRes.primaryColor : ColorRes.grayColor,
              size: 20.getSize,
            ),
            12.widthSpacer,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BaseTextDMSans(
                    text: label,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ColorRes.secondaryColor,
                    textAlign: TextAlign.start,
                  ).tr(),
                  4.heightSpacer,
                  BaseTextDMSans(
                    text: hasFile ? StringRes.replaceImage : StringRes.tapToUpload,
                    fontSize: 12,
                    color: ColorRes.grayColor,
                    textAlign: TextAlign.start,
                  ).tr(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget locationTile(AddVendorController controller) {
    final hasLocation = controller.hasLocation;

    return InkWell(
      onTap: controller.isCapturingLocation ? null : controller.captureLocation,
      borderRadius: BorderRadius.circular(10.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16.getSize,
          vertical: 14.getSize,
        ),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(
            color: hasLocation ? ColorRes.primaryColor : ColorRes.borderColor,
          ),
        ),
        child: Row(
          children: [
            controller.isCapturingLocation
                ? SizedBox(
                    width: 20.getSize,
                    height: 20.getSize,
                    child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
                  )
                : Icon(
                    hasLocation ? Icons.check_circle_outline : Icons.my_location_outlined,
                    color: hasLocation ? ColorRes.primaryColor : ColorRes.grayColor,
                    size: 20.getSize,
                  ),
            12.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: hasLocation
                    ? '${tr(StringRes.locationCaptured)} (${controller.latitude!.toStringAsFixed(5)}, ${controller.longitude!.toStringAsFixed(5)})'
                    : tr(StringRes.captureLocation),
                fontSize: 13,
                color: hasLocation ? ColorRes.secondaryColor : ColorRes.grayColor,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget idProofTypeSelector(AddVendorController controller) {
    return Row(
      children: [
        Expanded(
          child: typeChip(
            label: StringRes.aadhaar,
            value: 'aadhaar',
            controller: controller,
          ),
        ),
        12.widthSpacer,
        Expanded(
          child: typeChip(
            label: StringRes.pan,
            value: 'pan',
            controller: controller,
          ),
        ),
      ],
    );
  }

  Widget typeChip({
    required String label,
    required String value,
    required AddVendorController controller,
  }) {
    final selected = controller.idProofType == value;

    return InkWell(
      onTap: () => controller.setIdProofType(value),
      borderRadius: BorderRadius.circular(10.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.getSize),
        decoration: BoxDecoration(
          color: selected
              ? ColorRes.primaryColor.withValues(alpha: 0.15)
              : ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(10.getSize),
          border: Border.all(
            color: selected ? ColorRes.primaryColor : ColorRes.borderColor,
          ),
        ),
        child: BaseTextDMSans(
          text: label,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? ColorRes.primaryColor : ColorRes.grayColor,
        ).tr(),
      ),
    );
  }

  Widget getBottomButton(AddVendorController controller, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24.getSize,
        right: 24.getSize,
        top: 10.getSize,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.getSize,
      ),
      child: BaseRaisedButton(
        onPressed: controller.saveDraftAPI,
        buttonText: StringRes.saveDraft,
        buttonColor: ColorRes.primaryColor,
      ),
    );
  }
}
