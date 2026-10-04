import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../change_password_module/change_password_view.dart';
import '../customer_favorites_module/customer_favorites_view.dart';
import '../customer_login_module/customer_login_view.dart';
import '../delete_account_module/delete_account_view.dart';
import 'customer_profile_controller.dart';

/// Customer profile (SPEC section 4) — avatar and location over the
/// account, preference and session actions.
///
/// Hosted inside the home shell's bottom bar, so it has no bottom nav
/// or Scaffold chrome of its own.
class CustomerProfileView extends StatelessWidget {
  const CustomerProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerProfileController>(
      init: CustomerProfileController(),
      dispose: (_) => Get.delete<CustomerProfileController>(),
      builder: (controller) {
        return Container(
          color: ServiceTokens.bg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              hero(controller),
              Transform.translate(
                // Lifts the two cards so they straddle the hero's edge.
                offset: Offset(0, -34.getSize),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.getSize, 0, 16.getSize, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shortcutCards(),
                      22.heightSpacer,
                      CustomerGroupLabel(text: tr(StringRes.accountSection)),
                      12.heightSpacer,
                      accountGroup(controller),
                      22.heightSpacer,
                      CustomerGroupLabel(text: tr(StringRes.preferencesSection)),
                      12.heightSpacer,
                      preferencesGroup(controller),
                      26.heightSpacer,
                      CustomerSecondaryButton(
                        label: tr(StringRes.logOutRow),
                        icon: Icons.logout,
                        onTap: controller.logoutAPI,
                      ),
                      12.heightSpacer,
                      CustomerSecondaryButton(
                        label: tr(StringRes.deleteAccountRow),
                        icon: Icons.delete_outline,
                        danger: true,
                        onTap: () => Get.to(
                          () => DeleteAccountView(
                            loginViewBuilder: () => const CustomerLoginView(),
                          ),
                        ),
                      ),
                      28.heightSpacer,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget hero(CustomerProfileController controller) {
    return CustomerHero(
      bottomPadding: 56.getSize,
      child: Column(
        children: [
          BaseTextDMSans(
            text: tr(StringRes.profileScreenTitle),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            textAlign: TextAlign.center,
          ),
          20.heightSpacer,
          avatar(controller),
          14.heightSpacer,
          BaseTextDMSans(
            text: controller.displayName,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          12.heightSpacer,
          locationPill(controller),
        ],
      ),
    );
  }

  Widget avatar(CustomerProfileController controller) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 86.getSize,
          width: 86.getSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26.getSize),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.person_outline,
            size: 44.getSize,
            color: ServiceTokens.accent,
          ),
        ),
        Positioned(
          right: -4.getSize,
          bottom: -4.getSize,
          child: GestureDetector(
            // Shown but inert: there is no avatar-upload endpoint, and a
            // control that silently does nothing is worse than one that
            // says so.
            onTap: () => Utils.showToast(tr(StringRes.comingSoon)),
            child: Container(
              height: 32.getSize,
              width: 32.getSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ServiceTokens.accentBright,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.photo_camera,
                size: 15.getSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget locationPill(CustomerProfileController controller) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20.getSize),
      child: InkWell(
        onTap: controller.changeLocation,
        borderRadius: BorderRadius.circular(20.getSize),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14.getSize,
            vertical: 8.getSize,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15.getSize,
                color: Colors.white,
              ),
              7.widthSpacer,
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 220.getSize),
                child: BaseTextDMSans(
                  text: controller.locationLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget shortcutCards() {
    // IntrinsicHeight, because the two cards should match heights even
    // when one title wraps — and a bare `stretch` Row inside a scroll
    // view has no bounded height to stretch to.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: shortcutCard(
              icon: Icons.favorite_border,
              title: tr(StringRes.favoritesTab),
              subtitle: tr(StringRes.favouritesCardDesc),
              onTap: () => Get.to(() => const CustomerFavoritesView()),
            ),
          ),
          12.widthSpacer,
          Expanded(
            child: shortcutCard(
              icon: Icons.star_border,
              title: tr(StringRes.myReviewsTitle),
              subtitle: tr(StringRes.myReviewsCardDesc),
              // No endpoint lists a customer's own reviews yet — the
              // card is in the design, so it is here, saying so rather
              // than opening an empty screen.
              onTap: () => Utils.showToast(tr(StringRes.comingSoon)),
            ),
          ),
        ],
      ),
    );
  }

  Widget shortcutCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ServiceTokens.card,
      borderRadius: BorderRadius.circular(18.getSize),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.getSize),
        child: Container(
          padding: EdgeInsets.all(14.getSize),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.getSize),
            border: Border.all(color: ServiceTokens.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomerIconTile(icon: icon, size: 38),
              14.heightSpacer,
              BaseTextDMSans(
                text: title,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ServiceTokens.text,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              5.heightSpacer,
              BaseTextDMSans(
                text: subtitle,
                fontSize: 12,
                color: ServiceTokens.muted,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget accountGroup(CustomerProfileController controller) {
    return CustomerGroup(
      children: [
        CustomerRow(
          icon: Icons.person_outline,
          title: tr(StringRes.personalDetails),
          subtitle: tr(StringRes.personalDetailsDesc),
          // No customer self-update endpoint exists yet; the vendor one
          // (PATCH /vendors/me) has no customer counterpart.
          onTap: () => Utils.showToast(tr(StringRes.comingSoon)),
        ),
        CustomerRow(
          icon: Icons.location_on_outlined,
          title: tr(StringRes.savedLocationRow),
          subtitle: controller.locationLabel,
          onTap: controller.changeLocation,
        ),
        CustomerRow(
          icon: Icons.lock_outline,
          title: tr(StringRes.changePasswordRow),
          onTap: () => Get.to(() => const ChangePasswordView()),
        ),
      ],
    );
  }

  Widget preferencesGroup(CustomerProfileController controller) {
    return CustomerGroup(
      children: [
        CustomerRow(
          icon: Icons.notifications_none,
          title: tr(StringRes.notificationsRow),
          trailing: Switch(
            value: controller.notificationsEnabled,
            onChanged: controller.toggleNotifications,
            activeThumbColor: Colors.white,
            activeTrackColor: ServiceTokens.accent,
            inactiveTrackColor: ServiceTokens.stroke2,
          ),
        ),
        CustomerRow(
          icon: Icons.language,
          title: tr(StringRes.languageRow),
          value: 'English',
          // Only one locale ships today (assets/translations/en.json),
          // so a picker would be a list of one.
          onTap: () => Utils.showToast(tr(StringRes.comingSoon)),
        ),
        CustomerRow(
          icon: Icons.help_outline,
          title: tr(StringRes.helpSupportRow),
          onTap: () => Utils.showToast(tr(StringRes.comingSoon)),
        ),
      ],
    );
  }
}
