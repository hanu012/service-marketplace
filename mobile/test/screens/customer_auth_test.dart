import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/constants/flavor_config.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/account_verification_module/account_verification_view.dart';
import 'package:service_marketplace/screens/auth_flow/customer_home_module/customer_home_view.dart';
import 'package:service_marketplace/screens/auth_flow/customer_login_module/customer_login_controller.dart';
import 'package:service_marketplace/screens/auth_flow/customer_register_module/customer_register_controller.dart';

/// The home screen's onInit fires a real GPS detection — this fakes it
/// denied so pumpAndSettle resolves quickly rather than hanging on a real
/// platform channel that doesn't exist in a widget test, same pattern
/// add_vendor_controller_test.dart already established.
class _DeniedGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;
}

/// Mirrors vendor_auth_test.dart — same conventions, trimmed to what's
/// actually different for role=customer: no business_name/phone fields.
///
/// The approval gate is NOT one of the differences any more. Customers were
/// exempt from email verification; they are not exempt from admin approval
/// (SPEC section 3.1), so both flows carry an approval_status the same way
/// the vendor ones do.
class _RecordingAuthDataSource extends DataSource {
  Map<String, dynamic>? capturedLoginBody;
  Map<String, dynamic>? capturedRegisterBody;

  bool loginSucceeds = true;

  /// Defaults to approved so the existing happy-path tests keep asserting
  /// what they were written to assert; the gate itself is covered by the
  /// tests that set these to 'pending'.
  String loginApprovalStatus = 'approved';
  String registerApprovalStatus = 'approved';

  Map<String, List<String>>? registerFieldErrors;

  @override
  Future<CommonResponse?> loginAPI({required Map<String, dynamic> body}) async {
    capturedLoginBody = body;

    if (!loginSucceeds) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Bad credentials.'},
      }, statusCode: 401);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'user': {
          'id': 1,
          'name': 'Riya Shah',
          'email': body['email'],
          'role': 'customer',
          'must_change_password': false,
          'approval_status': loginApprovalStatus,
        },
        'token': '1|abc',
      },
      'error': null,
    }, statusCode: 200);
  }

  // The home screen fetches this immediately after login/register
  // navigates — stubbed to fail fast so these auth tests stay fully
  // offline, same reasoning vendor_auth_test.dart's fake documents.
  @override
  Future<CommonResponse?> updateCustomerLocationAPI({
    double? latitude,
    double? longitude,
    String? pincode,
  }) async =>
      null;

  @override
  Future<CommonResponse?> registerAPI({required Map<String, dynamic> body}) async {
    capturedRegisterBody = body;

    if (registerFieldErrors != null) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'The given data was invalid.',
          'fields': registerFieldErrors,
        },
      }, statusCode: 422);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'user': {
          'id': 2,
          'name': body['name'],
          'email': body['email'],
          'role': 'customer',
          'must_change_password': false,
          'approval_status': registerApprovalStatus,
        },
        'token': '1|abc',
      },
      'error': null,
    }, statusCode: 201);
  }
}

CustomerLoginController _fillLoginController() {
  final controller = CustomerLoginController();
  controller.emailController.text = 'riya@example.com';
  controller.passwordController.text = 'correct-horse-battery';
  return controller;
}

Future<void> _pumpLoginForm(WidgetTester tester, CustomerLoginController controller) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: Form(
          key: controller.formKey,
          child: Column(
            children: [
              TextFormField(
                controller: controller.emailController,
                validator: controller.validateEmail,
              ),
              TextFormField(
                controller: controller.passwordController,
                validator: controller.validatePassword,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    FlavorConfig.initialize(FlavorConfig.customer);
  });

  setUp(() {
    GeolocatorPlatform.instance = _DeniedGeolocator();
  });

  group('CustomerLoginController', () {
    testWidgets('a successful login stores the user and lands on CustomerHomeView', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = _fillLoginController();
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedLoginBody?['email'], 'riya@example.com');
      expect(find.byType(CustomerHomeView), findsOneWidget);

      controller.onClose();
    });

    /// Customers were exempt from the old email-verification gate. They are
    /// not exempt from this one, and that is the whole point of the change.
    testWidgets('an unapproved customer lands on the verification screen', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource()..loginApprovalStatus = 'pending';
      DataSource.instance = fake;

      final controller = _fillLoginController();
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(find.byType(AccountVerificationView), findsOneWidget);
      expect(find.byType(CustomerHomeView), findsNothing);

      controller.onClose();
    });

    testWidgets('invalid credentials do not navigate anywhere', (tester) async {
      final fake = _RecordingAuthDataSource()..loginSucceeds = false;
      DataSource.instance = fake;

      final controller = _fillLoginController();
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeView), findsNothing);
      expect(find.byType(AccountVerificationView), findsNothing);

      controller.onClose();
    });

    testWidgets('an empty form is never submitted', (tester) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = CustomerLoginController();
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedLoginBody, isNull);

      controller.onClose();
    });
  });

  group('CustomerRegisterController', () {
    CustomerRegisterController buildController() {
      final controller = CustomerRegisterController();
      controller.nameController.text = 'Riya Shah';
      controller.emailController.text = 'riya@example.com';
      controller.passwordController.text = 'correct-horse-battery';
      controller.confirmPasswordController.text = 'correct-horse-battery';
      return controller;
    }

    Future<void> pumpRegisterForm(WidgetTester tester, CustomerRegisterController controller) {
      return tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Form(
              key: controller.formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: controller.nameController,
                    validator: (v) => controller.validateRequired(v, 'x'),
                  ),
                  TextFormField(
                    controller: controller.emailController,
                    validator: controller.validateEmail,
                  ),
                  TextFormField(
                    controller: controller.passwordController,
                    validator: controller.validatePassword,
                  ),
                  TextFormField(
                    controller: controller.confirmPasswordController,
                    validator: controller.validateConfirmPassword,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('sends role from FlavorConfig, not a form field', (tester) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = buildController();
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedRegisterBody?['role'], 'customer');
      expect(fake.capturedRegisterBody!.containsKey('business_name'), isFalse);
      expect(fake.capturedRegisterBody!.containsKey('phone'), isFalse);

      controller.onClose();
    });

    /// What a real registration does: the account comes back Pending, so
    /// the customer goes to the verification screen rather than home.
    testWidgets('a registration lands on the verification screen, not home', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource()..registerApprovalStatus = 'pending';
      DataSource.instance = fake;

      final controller = buildController();
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(find.byType(AccountVerificationView), findsOneWidget);
      expect(find.byType(CustomerHomeView), findsNothing);

      controller.onClose();
    });

    /// The other side of the branch — kept so an approved account is still
    /// proven to reach home, in case approval ever becomes automatic for
    /// some path.
    testWidgets('an already-approved registration lands on CustomerHomeView', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = buildController();
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeView), findsOneWidget);

      controller.onClose();
    });

    testWidgets('a duplicate-email field error surfaces without crashing', (tester) async {
      final fake = _RecordingAuthDataSource()
        ..registerFieldErrors = {
          'email': ['This email is already registered.'],
        };
      DataSource.instance = fake;

      final controller = buildController();
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeView), findsNothing);

      controller.onClose();
    });

    testWidgets('mismatched passwords are never submitted', (tester) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = buildController();
      controller.confirmPasswordController.text = 'something-else';
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedRegisterBody, isNull);

      controller.onClose();
    });
  });
}
