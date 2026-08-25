import 'package:easy_localization/easy_localization.dart';

import 'constants/app.export.dart';
import 'constants/constant.dart';
import 'constants/flavor_config.dart';
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

      home: _firstScreen(config),
    );
  }

  /// Each flavour's entry screen — all three now check login state and
  /// land on their real screens (task 4.6 replaced customer's ported
  /// create_account_module placeholder, the last one still stubbed).
  Widget _firstScreen(FlavorConfig config) {
    switch (config.flavor) {
      case Flavor.salesman:
        // Already signed in: skip login, but honour a pending forced change
        // (SPEC section 2.1) — the server blocks every other endpoint until
        // it is done, so landing on the home screen would fail on its first
        // request.
        if (Injector.isLoggedIn) {
          return (Injector.userData?.mustChangePassword ?? false)
              ? const ChangePasswordView()
              : const SalesmanHomeView();
        }

        return const SalesmanLoginView();
      case Flavor.vendor:
        // Same forced-change rule — SPEC section 2.1 is platform-wide, not
        // salesman-specific, so an admin-created vendor account still needs
        // it. A self-registered vendor never has this set.
        if (Injector.isLoggedIn) {
          return (Injector.userData?.mustChangePassword ?? false)
              ? const ChangePasswordView()
              : const VendorLandingView();
        }

        return const VendorLoginView();
      case Flavor.customer:
        // No forced-change branch: a customer registration never sets a
        // temporary password (SPEC section 4.1 is email + password only,
        // no admin-created customer accounts), so must_change_password
        // can't be true for this role.
        if (Injector.isLoggedIn) {
          return const CustomerHomeView();
        }

        return const CustomerLoginView();
    }
  }

  ThemeData get _theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ColorRes.backgroundColor,
        fontFamily: FontFamily.dmSans,
        colorScheme: ColorScheme.dark(
          primary: ColorRes.primaryColor,
          onPrimary: ColorRes.backgroundColor,
          surface: ColorRes.surfaceColor,
          onSurface: ColorRes.secondaryColor,
          error: ColorRes.errorColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: ColorRes.surfaceColor,
          foregroundColor: ColorRes.secondaryColor,
          elevation: 0,
        ),
      );
}
