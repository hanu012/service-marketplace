import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_business_details_controller.dart';

/// The vendor editing their own business profile (SPEC section 3.2).
///
/// Contact lives here too rather than on a second screen — see the
/// controller for why.
class VendorBusinessDetailsView extends StatelessWidget {
  const VendorBusinessDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorBusinessDetailsController>(
      init: VendorBusinessDetailsController(),
      dispose: (_) => Get.delete<VendorBusinessDetailsController>(),
      builder: (controller) {
        if (controller.isLoading && controller.vendorMe == null) {
          return const Scaffold(
            backgroundColor: ServiceTokens.bg,
            body: Center(
              child: CupertinoActivityIndicator(color: ServiceTokens.accentBright),
            ),
          );
        }

        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          resizeToAvoidBottomInset: true,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              hero(controller),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16.getSize,
                  20.getSize,
                  16.getSize,
                  28.getSize,
                ),
                child: form(controller),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget hero(VendorBusinessDetailsController controller) {
    return VendorHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              VendorIconButton(
                icon: Icons.chevron_left,
                onTap: Get.back,
                tooltip: tr(StringRes.backToLogin),
              ),
              Expanded(
                child: BaseTextDMSans(
                  text: tr(StringRes.vendorBusinessDetailsTitle),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),
              ),
              // Balances the back chip so the title sits truly centred.
              SizedBox(width: 42.getSize),
            ],
          ),
          20.heightSpacer,
          Row(
            children: [
              VendorAvatarTile(
                initials: controller.initials,
                size: 62,
                fontSize: 21,
              ),
              14.widthSpacer,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BaseTextDMSans(
                      text: controller.businessNameController.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    6.heightSpacer,
                    // Shown but inert: there is no logo upload endpoint
                    // yet, and a control that silently does nothing is
                    // worse than one that says so.
                    GestureDetector(
                      onTap: () => Utils.showToast(
                        tr(StringRes.comingSoon),
                      ),
                      child: BaseTextDMSans(
                        text: tr(StringRes.vendorChangeLogo),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        textDecoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget form(VendorBusinessDetailsController controller) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(StringRes.businessName),
          8.heightSpacer,
          BaseTextField(
            controller: controller.businessNameController,
            hintText: tr(StringRes.enterBusinessName),
            isShowBorder: true,
            validateMode: controller.autoValidateMode,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                controller.validateRequired(v, StringRes.enterBusinessName),
            // Redraws the hero's name and initials as it is typed.
            onChanged: (_) => controller.update(),
          ),
          18.heightSpacer,

          label(StringRes.ownerName),
          8.heightSpacer,
          BaseTextField(
            controller: controller.ownerNameController,
            hintText: tr(StringRes.enterOwnerName),
            isShowBorder: true,
            validateMode: controller.autoValidateMode,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                controller.validateRequired(v, StringRes.enterOwnerName),
          ),
          18.heightSpacer,

          label(StringRes.address),
          8.heightSpacer,
          BaseTextField(
            controller: controller.addressController,
            hintText: tr(StringRes.vendorAddressHint),
            isShowBorder: true,
            textInputAction: TextInputAction.next,
          ),
          18.heightSpacer,

          label(StringRes.vendorCityLabel),
          8.heightSpacer,
          BaseTextField(
            controller: controller.cityController,
            hintText: tr(StringRes.vendorCityHint),
            isShowBorder: true,
            textInputAction: TextInputAction.next,
          ),
          18.heightSpacer,

          label(StringRes.vendorAboutLabel),
          8.heightSpacer,
          BaseTextField(
            controller: controller.aboutController,
            hintText: tr(StringRes.vendorAboutHint),
            isShowBorder: true,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
          ),
          24.heightSpacer,

          // Contact, folded into this screen rather than given one of
          // its own.
          sectionLabel(tr(StringRes.vendorContactSection)),
          14.heightSpacer,

          label(StringRes.phone),
          8.heightSpacer,
          BaseTextField(
            controller: controller.phoneController,
            hintText: tr(StringRes.enterPhone),
            isShowBorder: true,
            textInputType: TextInputType.phone,
            validateMode: controller.autoValidateMode,
            textInputAction: TextInputAction.done,
            validator: controller.validatePhone,
          ),
          18.heightSpacer,

          label(StringRes.vendorEmailReadOnly),
          8.heightSpacer,
          readOnlyEmail(controller),
          8.heightSpacer,
          BaseTextDMSans(
            text: tr(StringRes.vendorEmailReadOnlyNote),
            fontSize: 12,
            color: ServiceTokens.muted2,
            textAlign: TextAlign.start,
            maxLines: 2,
          ),
          28.heightSpacer,

          VendorPrimaryButton(
            label: tr(StringRes.vendorSaveChanges),
            enabled: !controller.isSaving,
            onTap: controller.saveAPI,
          ),
        ],
      ),
    );
  }

  /// The sign-in address, rendered as a field-shaped read-only row so it
  /// reads as information rather than as an input that refuses to focus.
  Widget readOnlyEmail(VendorBusinessDetailsController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16.getSize,
        vertical: 17.getSize,
      ),
      decoration: BoxDecoration(
        color: ServiceTokens.bg,
        borderRadius: BorderRadius.circular(14.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16.getSize, color: ServiceTokens.muted2),
          10.widthSpacer,
          Expanded(
            child: BaseTextDMSans(
              text: controller.vendorMe?.email ?? '—',
              fontSize: 14,
              color: ServiceTokens.muted,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget label(String key) {
    return BaseTextDMSans(
      text: key,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: ServiceTokens.text,
      textAlign: TextAlign.start,
    ).tr();
  }

  Widget sectionLabel(String text) {
    return BaseTextDMSans(
      text: text.toUpperCase(),
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      color: ServiceTokens.muted2,
      textAlign: TextAlign.start,
    );
  }
}
