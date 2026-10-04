import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// The vendor editing their own business profile (SPEC section 3.2).
///
/// Contact details are part of THIS screen rather than a second one: a
/// vendor thinks of "how customers find me" as one thing, and splitting a
/// six-field form across two screens only adds a hop. The old profile row
/// for them is gone.
///
/// The sign-in email is shown but not editable. It is the account's
/// identity, lives on `users` under a unique index, and changing it is an
/// auth operation — PATCH /vendors/me deliberately has no email field.
class VendorBusinessDetailsController extends GetxController {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  VendorMeModel? vendorMe;
  bool isLoading = false;
  bool isSaving = false;

  @override
  void onInit() {
    super.onInit();
    fetchVendorMeAPI();
  }

  /// Fetches rather than taking the dashboard's copy: this screen is
  /// pushed and outlives individual tab switches, and editing a stale
  /// profile is how you overwrite a change made on another device.
  Future<void> fetchVendorMeAPI() async {
    isLoading = true;
    update();

    try {
      final response = await DataSource.instance.vendorMeAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      _fill(VendorMeModel.fromJson(response.data as Map<String, dynamic>));
    } catch (e) {
      if (kDebugMode) {
        print('Fetch business details error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  void _fill(VendorMeModel model) {
    vendorMe = model;
    businessNameController.text = model.businessName ?? '';
    ownerNameController.text = model.ownerName ?? '';
    phoneController.text = model.phone ?? '';
    addressController.text = model.address ?? '';
    cityController.text = model.city ?? '';
    aboutController.text = model.about ?? '';
  }

  /// Two letters for the avatar tile.
  String get initials {
    final parts = (businessNameController.text.isEmpty
            ? (vendorMe?.businessName ?? '')
            : businessNameController.text)
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      final one = parts.first;

      return (one.length >= 2 ? one.substring(0, 2) : one).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> saveAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    isSaving = true;
    update();

    try {
      final body = {
        'business_name': businessNameController.text.trim(),
        'owner_name': ownerNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'about': aboutController.text.trim(),
      };

      Utils.showCircularProgressLottie(true);
      final response = await DataSource.instance.updateVendorMeAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        // The server reports a duplicate phone per-field, so mark that
        // rather than showing one generic banner.
        final fieldError = response?.fieldError('phone') ??
            response?.fieldError('business_name') ??
            response?.fieldError('owner_name');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      // Refilled from the response, not from what was typed: the server is
      // the authority on what was actually stored (trimming, casing).
      _fill(VendorMeModel.fromJson(response.data as Map<String, dynamic>));

      Utils.showToast(tr(StringRes.vendorProfileSaved));
      Get.back();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Save business details error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isSaving = false;
      update();
    }
  }

  String? validateRequired(String? value, String messageKey) {
    if ((value ?? '').trim().isEmpty) {
      return tr(messageKey);
    }

    return null;
  }

  String? validatePhone(String? value) {
    final phone = (value ?? '').trim();

    if (phone.isEmpty) {
      return tr(StringRes.enterPhone);
    }

    if (phone.length < 10) {
      return tr(StringRes.invalidPhone);
    }

    return null;
  }

  @override
  void onClose() {
    businessNameController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    aboutController.dispose();
    super.onClose();
  }
}
