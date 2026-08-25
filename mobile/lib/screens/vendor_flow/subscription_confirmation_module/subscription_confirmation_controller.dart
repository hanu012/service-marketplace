import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app.export.dart';
import '../../auth_flow/salesman_home_module/salesman_home_view.dart';

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

  void done() {
    Utils.transitionWithOffAll(const SalesmanHomeView());
  }
}
