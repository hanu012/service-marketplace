import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'customer_address_form_controller.dart';

/// Confirm-and-save one address — see [CustomerAddressFormController].
///
/// Layout follows the patient app's select-location screen: a map card to
/// place the pin, the resolved address, house/flat and building fields,
/// Home / Office / Other chips, a default checkbox, and Continue.
class CustomerAddressFormView extends StatelessWidget {
  const CustomerAddressFormView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.editing,
    this.searchedAddress,
  });

  final double latitude;
  final double longitude;
  final CustomerAddressModel? editing;
  final String? searchedAddress;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerAddressFormController>(
      init: CustomerAddressFormController(
        latitude: latitude,
        longitude: longitude,
        editing: editing,
        searchedAddress: searchedAddress,
      ),
      dispose: (_) => Get.delete<CustomerAddressFormController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              header(),
              Expanded(child: body(controller)),
            ],
          ),
        );
      },
    );
  }

  Widget header() {
    return CustomerHero(
      bottomPadding: 18.getSize,
      child: Row(
        children: [
          CustomerIconButton(icon: Icons.chevron_left, onTap: Get.back),
          Expanded(
            child: Column(
              children: [
                BaseTextDMSans(
                  text: tr(StringRes.confirmAddress),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                4.heightSpacer,
                BaseTextDMSans(
                  text: tr(StringRes.confirmAddressDesc),
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.82),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          // Balances the back chip so the title sits truly centred.
          SizedBox(width: 42.getSize),
        ],
      ),
    );
  }

  Widget body(CustomerAddressFormController controller) {
    return Form(
      key: controller.formKey,
      autovalidateMode: controller.autoValidateMode,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.getSize, 16.getSize, 16.getSize, 28.getSize),
        children: [
          mapCard(controller),
          18.heightSpacer,
          fieldLabel(StringRes.addressDetails),
          BaseTextField(
            controller: controller.streetController,
            hintText: tr(StringRes.addressFromMapHint),
            readOnly: true,
            isShowBorder: true,
            fillColor: ServiceTokens.card2,
            borderColor: ServiceTokens.stroke,
            maxLines: 3,
            minLines: 1,
            prefixIcon: Icon(Icons.location_on_outlined, color: ServiceTokens.accent, size: 20.getSize),
            suffixIcon: controller.isResolving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CupertinoActivityIndicator(color: ServiceTokens.accent),
                  )
                : null,
          ),
          16.heightSpacer,
          fieldLabel(StringRes.houseNumberLabel),
          BaseTextField(
            controller: controller.apartmentController,
            hintText: tr(StringRes.houseNumberHint),
            isShowBorder: true,
            fillColor: ServiceTokens.card,
            borderColor: ServiceTokens.stroke,
            validator: controller.validateApartment,
            textInputAction: TextInputAction.next,
          ),
          16.heightSpacer,
          fieldLabel(StringRes.buildingNameLabel),
          BaseTextField(
            controller: controller.buildingController,
            hintText: tr(StringRes.buildingNameHint),
            isShowBorder: true,
            fillColor: ServiceTokens.card,
            borderColor: ServiceTokens.stroke,
            validator: controller.validateBuilding,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
          18.heightSpacer,
          fieldLabel(StringRes.saveAddressAs),
          labelChips(controller),
          if (controller.label == 'other') ...[
            12.heightSpacer,
            BaseTextField(
              controller: controller.otherNameController,
              hintText: tr(StringRes.otherNameHint),
              isShowBorder: true,
              fillColor: ServiceTokens.card,
              borderColor: ServiceTokens.stroke,
              validator: controller.validateOtherName,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
            ),
          ],
          10.heightSpacer,
          defaultCheckbox(controller),
          18.heightSpacer,
          CustomerPrimaryButton(
            label: tr(StringRes.continueLabel),
            enabled: !controller.isSaving,
            onTap: controller.saveAddressAPI,
          ),
          16.heightSpacer,
          safeNote(),
        ],
      ),
    );
  }

  /// A short map, not a full-screen one: the form is the point of this
  /// screen. The pin is a fixed overlay at the centre — moving the map
  /// moves the place under it, the same as the old map screen.
  Widget mapCard(CustomerAddressFormController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.getSize),
      child: SizedBox(
        height: 200.getSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: controller.centre, zoom: 16),
                onMapCreated: controller.onMapCreated,
                onCameraMove: controller.onCameraMove,
                onCameraIdle: controller.onCameraIdle,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                // Inside a scrolling list, the list would otherwise win
                // every vertical drag and the map could never be panned.
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Padding(
                    // Lifts the pin so its point, not its middle, marks
                    // the centre.
                    padding: EdgeInsets.only(bottom: 34.getSize),
                    child: Icon(Icons.location_on, color: ColorRes.errorColor, size: 38.getSize),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10.getSize,
              bottom: 10.getSize,
              child: Material(
                color: ServiceTokens.card,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: controller.goToMyLocation,
                  child: Padding(
                    padding: EdgeInsets.all(9.getSize),
                    child: Icon(Icons.my_location, color: ServiceTokens.accent, size: 20.getSize),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget fieldLabel(String key) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.getSize),
      child: BaseTextDMSans(
        text: tr(key),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ServiceTokens.text,
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget labelChips(CustomerAddressFormController controller) {
    Widget chip(String value, String key) {
      final selected = controller.label == value;

      return Padding(
        padding: EdgeInsets.only(right: 10.getSize),
        child: InkWell(
          onTap: () => controller.selectLabel(value),
          borderRadius: BorderRadius.circular(22.getSize),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.getSize, vertical: 9.getSize),
            decoration: BoxDecoration(
              color: selected ? ServiceTokens.accent : ServiceTokens.card,
              borderRadius: BorderRadius.circular(22.getSize),
              border: Border.all(color: selected ? ServiceTokens.accent : ServiceTokens.stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  customerAddressIcon(value),
                  size: 16.getSize,
                  // White only on the filled teal-700 chip.
                  color: selected ? ColorRes.whiteColor : ServiceTokens.muted,
                ),
                6.widthSpacer,
                BaseTextDMSans(
                  text: tr(key),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? ColorRes.whiteColor : ServiceTokens.text,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('home', StringRes.addressHome),
        chip('office', StringRes.addressOffice),
        chip('other', StringRes.addressOther),
      ],
    );
  }

  Widget defaultCheckbox(CustomerAddressFormController controller) {
    return InkWell(
      onTap: () => controller.toggleDefault(!controller.isDefault),
      borderRadius: BorderRadius.circular(8.getSize),
      child: Row(
        children: [
          Checkbox(
            value: controller.isDefault,
            onChanged: controller.toggleDefault,
            activeColor: ServiceTokens.accent,
          ),
          Expanded(
            child: BaseTextDMSans(
              text: tr(StringRes.makeDefaultAddress),
              fontSize: 14,
              color: ServiceTokens.text,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget safeNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14.getSize, color: ServiceTokens.muted2),
        6.widthSpacer,
        Flexible(
          child: BaseTextDMSans(
            text: tr(StringRes.addressSafeNote),
            fontSize: 10,
            color: ServiceTokens.muted,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
