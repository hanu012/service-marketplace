import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/constants/flavor_config.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/forgot_password_module/forgot_password_controller.dart';
import 'package:service_marketplace/screens/auth_flow/forgot_password_module/forgot_password_view.dart';

class _ResetRequestDataSource extends DataSource {
  Map<String, dynamic>? capturedBody;
  int calls = 0;

  @override
  Future<CommonResponse?> passwordResetRequestAPI({
    required Map<String, dynamic> body,
  }) async {
    calls++;
    capturedBody = body;

    return CommonResponse.fromJson({
      'success': true,
      'data': {'message': 'ok'},
      'error': null,
    });
  }
}

void main() {
  setUpAll(() {
    FlavorConfig.initialize(FlavorConfig.vendor);
  });

  tearDown(Get.reset);

  testWidgets('prefills the email typed on the login screen', (tester) async {
    DataSource.instance = _ResetRequestDataSource();

    await tester.pumpWidget(
      const GetMaterialApp(home: ForgotPasswordView(initialEmail: 'asha@example.com')),
    );
    await tester.pumpAndSettle();

    expect(Get.find<ForgotPasswordController>().emailController.text, 'asha@example.com');
  });

  testWidgets('sends the trimmed email and returns to the login screen', (tester) async {
    final dataSource = _ResetRequestDataSource();
    DataSource.instance = dataSource;

    // Login stands in underneath, as in the app — the screen is pushed.
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: Text('login'))));
    Get.to(() => const ForgotPasswordView(initialEmail: '  asha@example.com '));
    await tester.pumpAndSettle();

    await Get.find<ForgotPasswordController>().sendResetRequestAPI();
    await tester.pumpAndSettle();

    expect(dataSource.capturedBody, {'email': 'asha@example.com'});
    expect(find.byType(ForgotPasswordView), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('an invalid email is caught before any request', (tester) async {
    final dataSource = _ResetRequestDataSource();
    DataSource.instance = dataSource;

    await tester.pumpWidget(
      const GetMaterialApp(home: ForgotPasswordView(initialEmail: 'not-an-email')),
    );
    await tester.pumpAndSettle();

    await Get.find<ForgotPasswordController>().sendResetRequestAPI();
    await tester.pumpAndSettle();

    expect(dataSource.calls, 0);
    expect(find.byType(ForgotPasswordView), findsOneWidget);
  });
}
