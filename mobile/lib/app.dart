import 'package:easy_localization/easy_localization.dart';

import 'constants/app.export.dart';
import 'constants/constant.dart';
import 'constants/flavor_config.dart';
import 'screens/auth_flow/account_verification_module/account_verification_view.dart';
import 'screens/auth_flow/change_password_module/change_password_view.dart';
import 'screens/auth_flow/customer_home_module/customer_home_view.dart';
import 'screens/auth_flow/customer_login_module/customer_login_view.dart';
import 'screens/auth_flow/salesman_home_module/salesman_home_view.dart';
import 'screens/auth_flow/salesman_login_module/salesman_login_view.dart';
import 'screens/auth_flow/vendor_landing_module/vendor_landing_view.dart';
import 'screens/auth_flow/vendor_login_module/vendor_login_view.dart';

/// Shared bootstrap for all three flavours.
///
/// Each `main_*.dart` resolves its [FlavorConfig] and calls this; everything
/// after that point is identical, so flavour drift is impossible by
/// construction.
Future<void> bootstrap(FlavorConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlavorConfig.initialize(config);

  await EasyLocalization.ensureInitialized();
  await Injector.initialize();

  if (kDebugMode) {
    print('Booting flavour: ${config.flavor.name} (${config.appName})');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ServiceMarketplaceApp(),
    ),
  );
}

class ServiceMarketplaceApp extends StatelessWidget {
  const ServiceMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = FlavorConfig.current;

    return GetMaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,

      // Utils.key backs Utils.getSize, which needs a mounted navigator to
      // read the screen width.
      navigatorKey: Utils.key,

      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // Dark only, matching CLAUDE.md's Theme section and the admin panel.
      themeMode: ThemeMode.dark,
      theme: _theme,
      darkTheme: _theme,

      // A corner ribbon naming the running flavour — the three apps look
      // alike on a dev device otherwise. Debug builds only; never shipped.
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();

        if (!kDebugMode) return content;

        // The phone bezel/notch/frame around this (when running on web)
        // lives OUTSIDE the app now — a wrapper HTML page embeds the
        // dev-server build in a real phone-dimensioned iframe. That gives
        // GetX's Get.width/Get.height (which `.getSize` etc. scale off,
        // and which read the actual rendering surface, not any in-app
        // MediaQuery override — see mobile/device_preview/README.md) the
        // real phone width to scale against, instead of faking a frame
        // in-app and fighting that scaling. See mobile/device_preview/.
        return Banner(
          message: config.flavor.name.toUpperCase(),
          location: BannerLocation.topStart,
          color: ColorRes.primaryColor,
          textStyle: TextStyle(
            color: ColorRes.backgroundColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          child: content,
        );
      },

      home: _firstScreen(config),
    );
  }

  /// Each flavour's entry screen — all three now check login state and
  /// land on their real screens (task 4.6 replaced customer's ported
  /// create_account_module placeholder, the last one still stubbed).
  ///
  /// Both gates are re-checked here, not just at login: the stored session
  /// outlives the app, so a user who was approved yesterday and rejected
  /// overnight must not be dropped onto a home screen the server will
  /// refuse to serve.
  Widget _firstScreen(FlavorConfig config) {
    switch (config.flavor) {
      case Flavor.salesman:
        // Already signed in: skip login, but honour a pending forced change
        // (SPEC section 2.1) — the server blocks every other endpoint until
        // it is done, so landing on the home screen would fail on its first
        // request.
        if (Injector.isLoggedIn) {
          return _gatedOr(const SalesmanHomeView());
        }

        return const SalesmanLoginView();
      case Flavor.vendor:
        // Same forced-change rule — SPEC section 2.1 is platform-wide, not
        // salesman-specific, so an admin-created vendor account still needs
        // it. A self-registered vendor never has this set.
        if (Injector.isLoggedIn) {
          return _gatedOr(const VendorLandingView());
        }

        return const VendorLoginView();
      case Flavor.customer:
        // Customers have no forced-change branch of their own — a customer
        // registration never sets a temporary password (SPEC section 4.1)
        // — but they are subject to the approval gate like every other
        // role, so they go through the same helper.
        if (Injector.isLoggedIn) {
          return _gatedOr(const CustomerHomeView());
        }

        return const CustomerLoginView();
    }
  }

  /// [home] unless the stored session is blocked by one of the two
  /// platform-wide gates, in the same order the server applies them:
  /// RequirePasswordChange before RequireApprovedAccount. Sending a user
  /// who needs both to the pending screen first would strand them, since
  /// the password gate refuses that screen's own calls.
  Widget _gatedOr(Widget home) {
    final user = Injector.userData;

    if (user?.mustChangePassword ?? false) {
      return const ChangePasswordView();
    }

    if (!(user?.isApproved ?? false)) {
      return const AccountVerificationView();
    }

    return home;
  }

  ThemeData get _theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: ColorRes.backgroundColor,
        fontFamily: FontFamily.dmSans,
        colorScheme: ColorScheme.light(
          primary: ColorRes.primaryColor,
          // White, not the canvas: the canvas is now near-white itself,
          // so using it here would put white-on-white inside any widget
          // that paints onPrimary over the primary fill.
          onPrimary: ColorRes.whiteColor,
          surface: ColorRes.surfaceColor,
          onSurface: ColorRes.secondaryColor,
          error: ColorRes.errorColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: ColorRes.surfaceColor,
          foregroundColor: ColorRes.secondaryColor,
          surfaceTintColor: ColorRes.transparent,
          elevation: 0,
        ),
      );
}
