import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app.export.dart';

/// Add Vendor, final step — the vendor is now Active. Shows the temp
/// credentials Subscribe just generated (shown once, per SPEC section 2.2)
/// and hands them to the salesman to share.
class SubscriptionConfirmationController extends GetxController {
  final String businessName;
  final String loginEmail;
  final String temporaryPassword;
  final SubscriptionModel subscription;

  SubscriptionConfirmationController({
    required this.businessName,
    required this.loginEmail,
    required this.temporaryPassword,
    required this.subscription,
  });

  /// Plain string interpolation rather than a StringRes template — this is
  /// the message content handed to WhatsApp, not app UI chrome, and
  /// easy_localization named-args aren't used anywhere else in this app.
  String get shareMessage => 'Welcome to ${tr(StringRes.appName)}, $businessName!\n\n'
      'Your vendor account is ready. Log in with:\n'
      'Email: $loginEmail\n'
      'Temporary password: $temporaryPassword\n\n'
      'You will be asked to set your own password on first login.';

  Future<void> shareCredentials() async {
    try {
      await Share.share(shareMessage);
    } catch (e) {
      if (kDebugMode) {
        print('Share credentials error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  /// Unwinds the Add Vendor flow back to the home screen it started from.
  ///
  /// Deliberately NOT Get.offAll(SalesmanHomeView()): home is still mounted
  /// at the root of this stack, and replacing it builds a SECOND one while
  /// the first is alive. The new MyVendorsView's GetBuilder then reuses the
  /// already-registered MyVendorsController rather than creating its own,
  /// and tearing the old route down disposes that shared controller —
  /// taking the search field's TextEditingController with it, under a
  /// screen that is now rendering it ("A TextEditingController was used
  /// after being disposed").
  ///
  /// Popping to the root keeps the original home, and its controllers,
  /// exactly as they were. MyVendorsController.resumeDraftAPI and
  /// SalesmanHomeView.addVendor both refresh the list when the flow
  /// returns, so the newly-sold vendor still appears.
  void done() {
    Get.until((route) => route.isFirst);
  }
}
