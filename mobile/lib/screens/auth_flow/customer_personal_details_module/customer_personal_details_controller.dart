import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../customer_profile_module/customer_profile_controller.dart';

/// Customer Personal Details — name and phone are editable, email is
/// shown read-only because it is the login identity.
class CustomerPersonalDetailsController extends GetxController {
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  @override
  void onInit() {
    super.onInit();
    // Prefill from the cached user so the screen is never blank while the
    // fresh copy loads.
    nameController.text = Injector.userData?.name ?? '';
    emailController.text = Injector.userData?.email ?? '';
    customerMeAPI();
  }

  Future<void> customerMeAPI() async {
    try {
      CommonResponse? commonResponse = await DataSource.instance.customerMeAPI();

      if (commonResponse == null || !commonResponse.isSuccess) {
        return;
      }

      applyCustomer(commonResponse.data['customer']);
    } catch (e) {
      if (kDebugMode) {
        print('Customer me error $e');
      }
    }
  }

  Future<void> saveDetailsAPI() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      autoValidateMode = AutovalidateMode.onUserInteraction;
      update();
      return;
    }

    try {
      final body = {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
      };

      Utils.showCircularProgressLottie(true);
      CommonResponse? commonResponse =
          await DataSource.instance.updateCustomerProfileAPI(body: body);
      Utils.showCircularProgressLottie(false);

      if (commonResponse == null) {
        Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      if (!commonResponse.isSuccess) {
        Utils.showToast(
          commonResponse.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      applyCustomer(commonResponse.data['customer']);

      // The profile hero reads the name off the cached user, so keep it
      // in step rather than showing the old name until next login.
      final user = Injector.userData;
      if (user != null) {
        user.name = nameController.text;
        await Injector.setUserData(user, isFromEditProfile: true);
      }
      if (Get.isRegistered<CustomerProfileController>()) {
        Get.find<CustomerProfileController>().update();
      }

      Utils.showToast(tr(StringRes.profileUpdated));
      // The profile screen is still mounted underneath — pop back to it.
      Get.back();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Update customer profile error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  void applyCustomer(dynamic customer) {
    if (customer is! Map) {
      return;
    }

    nameController.text = (customer['name'] ?? '').toString();
    emailController.text = (customer['email'] ?? emailController.text).toString();
    phoneController.text = (customer['phone'] ?? '').toString();
    update();
  }

  String? validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return tr(StringRes.enterYourName);
    }

    return null;
  }

  /// Phone is optional for customers — only a non-empty value is checked.
  String? validatePhone(String? value) {
    final phone = (value ?? '').trim();

    if (phone.isNotEmpty && !GetUtils.isPhoneNumber(phone)) {
      return tr(StringRes.invalidPhone);
    }

    return null;
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.onClose();
  }
}
