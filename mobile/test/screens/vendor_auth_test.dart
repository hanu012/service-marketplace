import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/constants/flavor_config.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/change_password_module/change_password_view.dart';
import 'package:service_marketplace/screens/auth_flow/email_verification_pending_module/email_verification_pending_view.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_landing_module/vendor_landing_view.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_login_module/vendor_login_controller.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_register_module/vendor_register_controller.dart';

/// Captures what would go out over the wire to /api/auth/login and
/// /api/auth/register, instead of making real HTTP calls.
class _RecordingAuthDataSource extends DataSource {
  Map<String, dynamic>? capturedLoginBody;
  Map<String, dynamic>? capturedRegisterBody;

  String loginOutcome = 'success'; // success | invalid | unverified
  bool registerIssuesToken = false;
  Map<String, List<String>>? registerFieldErrors;

  @override
  Future<CommonResponse?> loginAPI({required Map<String, dynamic> body}) async {
    capturedLoginBody = body;

    if (loginOutcome == 'invalid') {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Bad credentials.'},
      }, statusCode: 401);
    }

    if (loginOutcome == 'unverified') {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'EMAIL_NOT_VERIFIED', 'message': 'Please verify your email.'},
      }, statusCode: 403);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'user': {
          'id': 1,
          'name': 'Asha Patel',
          'email': body['email'],
          'role': 'vendor',
          'must_change_password': false,
        },
        'token': '1|abc',
      },
      'error': null,
    }, statusCode: 200);
  }

  // VendorLandingController fetches this immediately after login/register
  // navigates. Stubbed to fail fast so these auth tests stay fully offline
  // and don't cascade into whatever vendor_select_plan_module's onInit
  // would also fetch — that branch is covered separately.
  @override
  Future<CommonResponse?> vendorMeAPI() async => null;

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
          'role': 'vendor',
          'must_change_password': false,
        },
        'token': registerIssuesToken ? '1|abc' : null,
      },
      'error': null,
    }, statusCode: 201);
  }
}

VendorLoginController _fillLoginController(WidgetTester tester) {
  final controller = VendorLoginController();
  controller.emailController.text = 'vendor@example.com';
  controller.passwordController.text = 'correct-horse-battery';
  return controller;
}

Future<void> _pumpLoginForm(WidgetTester tester, VendorLoginController controller) async {
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
    FlavorConfig.initialize(FlavorConfig.vendor);
  });

  group('VendorLoginController', () {
    testWidgets('a successful login stores the user and lands on VendorLandingView', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = _fillLoginController(tester);
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedLoginBody?['email'], 'vendor@example.com');
      expect(find.byType(VendorLandingView), findsOneWidget);

      controller.onClose();
    });

    testWidgets('must_change_password routes to ChangePasswordView instead', (tester) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      // Override to report must_change_password: true for this one test.
      fake.capturedLoginBody = null;

      final controller = _fillLoginController(tester);
      await _pumpLoginForm(tester, controller);

      // Patch the fake's response just for this case by re-assigning.
      DataSource.instance = _MustChangePasswordDataSource();

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordView), findsOneWidget);

      controller.onClose();
    });

    testWidgets('EMAIL_NOT_VERIFIED navigates to the verification-pending screen', (
      tester,
    ) async {
      final fake = _RecordingAuthDataSource()..loginOutcome = 'unverified';
      DataSource.instance = fake;

      final controller = _fillLoginController(tester);
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationPendingView), findsOneWidget);
      expect(find.text('vendor@example.com'), findsOneWidget);

      controller.onClose();
    });

    testWidgets('invalid credentials do not navigate anywhere', (tester) async {
      final fake = _RecordingAuthDataSource()..loginOutcome = 'invalid';
      DataSource.instance = fake;

      final controller = _fillLoginController(tester);
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(find.byType(VendorLandingView), findsNothing);
      expect(find.byType(EmailVerificationPendingView), findsNothing);

      controller.onClose();
    });

    testWidgets('an empty form is never submitted', (tester) async {
      final fake = _RecordingAuthDataSource();
      DataSource.instance = fake;

      final controller = VendorLoginController();
      await _pumpLoginForm(tester, controller);

      await controller.loginAPI();
      await tester.pumpAndSettle();

      expect(fake.capturedLoginBody, isNull);

      controller.onClose();
    });
  });

  group('VendorRegisterController', () {
    VendorRegisterController buildController() {
      final controller = VendorRegisterController();
      controller.nameController.text = 'Asha Patel';
      controller.businessNameController.text = 'Cool Air Services';
      controller.phoneController.text = '9812345678';
      controller.emailController.text = 'vendor@example.com';
      controller.passwordController.text = 'correct-horse-battery';
      controller.confirmPasswordController.text = 'correct-horse-battery';
      return controller;
    }

    Future<void> pumpRegisterForm(WidgetTester tester, VendorRegisterController controller) {
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
                    controller: controller.businessNameController,
                    validator: (v) => controller.validateRequired(v, 'x'),
                  ),
                  TextFormField(
                    controller: controller.phoneController,
                    validator: controller.validatePhone,
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

      expect(fake.capturedRegisterBody?['role'], 'vendor');
      expect(fake.capturedRegisterBody?['business_name'], 'Cool Air Services');
      expect(fake.capturedRegisterBody?['phone'], '9812345678');

      controller.onClose();
    });

    testWidgets(
      'a token-less response (the expected case) navigates to verification-pending, not home',
      (tester) async {
        final fake = _RecordingAuthDataSource()..registerIssuesToken = false;
        DataSource.instance = fake;

        final controller = buildController();
        await pumpRegisterForm(tester, controller);

        await controller.registerAPI();
        await tester.pumpAndSettle();

        expect(find.byType(EmailVerificationPendingView), findsOneWidget);
        expect(find.byType(VendorLandingView), findsNothing);

        controller.onClose();
      },
    );

    testWidgets('a duplicate-phone field error surfaces without crashing', (tester) async {
      final fake = _RecordingAuthDataSource()
        ..registerFieldErrors = {
          'phone': ['This phone number is already registered.'],
        };
      DataSource.instance = fake;

      final controller = buildController();
      await pumpRegisterForm(tester, controller);

      await controller.registerAPI();
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationPendingView), findsNothing);
      expect(find.byType(VendorLandingView), findsNothing);

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

/// A minimal fake for the one must_change_password case, kept separate so
/// the main fake's response shape stays simple for every other test.
class _MustChangePasswordDataSource extends DataSource {
  @override
  Future<CommonResponse?> loginAPI({required Map<String, dynamic> body}) async {
    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'user': {
          'id': 1,
          'name': 'Asha Patel',
          'email': body['email'],
          'role': 'vendor',
          'must_change_password': true,
        },
        'token': '1|abc',
      },
      'error': null,
    }, statusCode: 200);
  }
}
