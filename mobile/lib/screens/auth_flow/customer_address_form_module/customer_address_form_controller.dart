import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../constants/app.export.dart';
import '../../../utils/location_capture.dart';
import '../../../utils/place_service.dart';

/// Confirm-and-save for one address (new location flow — see
/// Constants.useNewLocationFlow): a map card to place the pin, the address
/// it resolves to, and the details the geocoder cannot know (house/flat,
/// building, a label).
///
/// Returns the saved [CustomerAddressModel] through `Get.back(result:)`;
/// the caller decides whether that also becomes the current location.
class CustomerAddressFormController extends GetxController {
  CustomerAddressFormController({
    required double latitude,
    required double longitude,
    this.editing,
    this.searchedAddress,
  }) : centre = LatLng(latitude, longitude);

  /// The address being edited; null when adding.
  final CustomerAddressModel? editing;

  /// The place the customer picked in search. Kept as the street line, as
  /// the patient app does — it is what they typed and recognised — rather
  /// than replaced by whatever the reverse geocoder calls that point.
  final String? searchedAddress;

  bool get isEditing => editing != null;

  GoogleMapController? mapController;
  LatLng centre;

  final TextEditingController streetController = TextEditingController();
  final TextEditingController apartmentController = TextEditingController();
  final TextEditingController buildingController = TextEditingController();
  final TextEditingController otherNameController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  /// home | office | other
  String label = 'home';

  /// New addresses default to true, so the place just chosen is the one
  /// used — the same default the patient app uses.
  bool isDefault = true;

  bool isResolving = false;
  bool isSaving = false;

  AddressParts? _parts;

  /// The map fires a camera-idle when it first settles. For an edit or a
  /// searched place that would overwrite the address the customer already
  /// has with a reverse-geocoded guess, so the first one is ignored; only
  /// moving the map changes it.
  bool _ignoreNextIdle = false;

  Timer? _debounce;
  int _requestId = 0;

  @override
  void onInit() {
    super.onInit();

    final address = editing;

    if (address != null) {
      label = address.label ?? 'home';
      otherNameController.text = address.otherLabel ?? '';
      apartmentController.text = address.apartmentNumber ?? '';
      buildingController.text = address.buildingName ?? '';
      streetController.text = address.streetAddress ?? '';
      isDefault = address.isDefault;
      _parts = AddressParts(
        streetAddress: address.streetAddress ?? '',
        area: address.area,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
      );
      _ignoreNextIdle = true;
      return;
    }

    if (searchedAddress != null && searchedAddress!.isNotEmpty) {
      streetController.text = searchedAddress!;
      _ignoreNextIdle = true;
      // Still look up area/city/pincode for the point, without touching
      // the street line the customer chose.
      _resolveCentre(keepStreet: true);
      return;
    }

    _resolveCentre();
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void onCameraMove(CameraPosition position) {
    centre = position.target;
  }

  void onCameraIdle() {
    if (_ignoreNextIdle) {
      _ignoreNextIdle = false;
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _resolveCentre);
  }

  Future<void> _resolveCentre({bool keepStreet = false}) async {
    final id = ++_requestId;

    isResolving = true;
    update();

    final parts = await PlaceService.instance.addressPartsAt(
      centre.latitude,
      centre.longitude,
    );

    // A newer pin position has been resolved since — this one is stale.
    if (id != _requestId) {
      return;
    }

    _parts = parts;

    if (!keepStreet && parts != null) {
      streetController.text = parts.streetAddress;
    }

    isResolving = false;
    update();
  }

  Future<void> goToMyLocation() async {
    final position = await LocationCapture.detect();

    if (position == null) {
      return;
    }

    centre = LatLng(position.latitude, position.longitude);
    await mapController?.animateCamera(CameraUpdate.newLatLngZoom(centre, 16));

    // An animation that ends where it started fires no idle event.
    _resolveCentre();
  }

  void selectLabel(String value) {
    label = value;
    update();
  }

  void toggleDefault(bool? value) {
    isDefault = value ?? false;
    update();
  }

  String? validateApartment(String? value) =>
      (value ?? '').trim().isEmpty ? tr(StringRes.enterHouseNumber) : null;

  String? validateBuilding(String? value) =>
      (value ?? '').trim().isEmpty ? tr(StringRes.enterBuildingName) : null;

  /// Letters and spaces, two words at most — matches the server rule.
  String? validateOtherName(String? value) {
    if (label != 'other') {
      return null;
    }

    final name = (value ?? '').trim();

    if (name.length < 2 || !RegExp(r'^\p{L}+(?: \p{L}+)?$', unicode: true).hasMatch(name)) {
      return tr(StringRes.enterOtherName);
    }

    return null;
  }

  Future<void> saveAddressAPI() async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    if (streetController.text.trim().isEmpty) {
      Utils.showToast(tr(StringRes.pinAddressMissing), isError: true);
      return;
    }

    final body = {
      'label': label,
      'other_label': label == 'other' ? otherNameController.text.trim() : null,
      'apartment_number': apartmentController.text.trim(),
      'building_name': buildingController.text.trim(),
      'street_address': streetController.text.trim(),
      'area': _parts?.area,
      'city': _parts?.city,
      'state': _parts?.state,
      'pincode': _parts?.pincode,
      'latitude': centre.latitude,
      'longitude': centre.longitude,
      'is_default': isDefault,
    };

    isSaving = true;
    update();

    try {
      Utils.showCircularProgressLottie(true);
      final response = isEditing
          ? await DataSource.instance.updateCustomerAddressAPI(
              addressId: editing!.id!,
              body: body,
            )
          : await DataSource.instance.addCustomerAddressAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final saved = CustomerAddressModel.fromJson(response.data as Map<String, dynamic>);
      Utils.showToast(tr(StringRes.addressSaved));
      Get.back(result: saved);
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Save address error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isSaving = false;
      update();
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    mapController?.dispose();
    streetController.dispose();
    apartmentController.dispose();
    buildingController.dispose();
    otherNameController.dispose();
    super.onClose();
  }
}
