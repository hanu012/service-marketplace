import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/constants/string_res.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_dashboard_module/vendor_dashboard_view.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_select_plan_module/vendor_select_plan_view.dart';
import 'package:service_marketplace/widgets/base_button.dart';

/// Answers GET /api/vendors/me the way task 4.2's real endpoint does:
/// active_subscription is null with no subscription, or plan/quota/days
/// detail with one — never fake leads/rating/photos data (Phase 5).
class _RecordingVendorMeDataSource extends DataSource {
  bool hasActiveSubscription = true;
  bool fails = false;

  @override
  Future<CommonResponse?> vendorMeAPI() async {
    if (fails) {
      return null;
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'vendor': {
          'id': 1,
          'business_name': 'Cool Air Services',
          'owner_name': 'Asha Patel',
          'phone': '9812345678',
          'email': 'vendor@example.com',
          'status': hasActiveSubscription ? 'active' : 'pending_payment',
          'has_active_subscription': hasActiveSubscription,
        },
        'active_subscription': hasActiveSubscription
            ? {
                'plan_name': 'Gold',
                'end_date': '2027-01-01',
                'days_remaining': 45,
                'quota': {
                  'categories': {'used': 1, 'max': 3},
                  'subcategories': {'used': 2, 'max': 6},
                  'zones': {'used': 1, 'max': 2},
                },
                'items': {
                  'categories': [
                    {'id': 1, 'name': 'AC Repair'},
                  ],
                  'subcategories': [
                    {'id': 10, 'name': 'Gas Filling'},
                    {'id': 11, 'name': 'Installation'},
                  ],
                  'zones': [
                    {'id': 100, 'name': 'Gota'},
                  ],
                },
              }
            : null,
      },
      'error': null,
    });
  }
}

void main() {
  testWidgets('a fetch populates vendorMe with plan and quota detail', (tester) async {
    final fake = _RecordingVendorMeDataSource()..hasActiveSubscription = true;
    DataSource.instance = fake;

    await tester.pumpWidget(GetMaterialApp(home: const VendorDashboardView()));
    await tester.pumpAndSettle();

    expect(find.text('Cool Air Services'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('the Services tab shows the selected item names and remaining quota', (
    tester,
  ) async {
    final fake = _RecordingVendorMeDataSource()..hasActiveSubscription = true;
    DataSource.instance = fake;

    await tester.pumpWidget(GetMaterialApp(home: const VendorDashboardView()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr(StringRes.servicesTab)));
    await tester.pumpAndSettle();

    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Gas Filling'), findsOneWidget);
    expect(find.text('Installation'), findsOneWidget);
    expect(find.text('Gota'), findsOneWidget);
    // categories: 1 used of 3 max, 2 remaining.
    expect(
      find.text('1 ${tr(StringRes.of)} 3 (2 ${tr(StringRes.remainingLabel)})'),
      findsOneWidget,
    );
    expect(find.byType(BaseRaisedButton), findsOneWidget);
  });

  testWidgets('no active subscription shows the fallback state with a way to subscribe', (
    tester,
  ) async {
    final fake = _RecordingVendorMeDataSource()..hasActiveSubscription = false;
    DataSource.instance = fake;

    await tester.pumpWidget(GetMaterialApp(home: const VendorDashboardView()));
    await tester.pumpAndSettle();

    expect(find.text('Cool Air Services'), findsNothing);
    expect(find.byType(BaseRaisedButton), findsOneWidget);

    await tester.tap(find.byType(BaseRaisedButton));
    await tester.pumpAndSettle();

    expect(find.byType(VendorSelectPlanView), findsOneWidget);
  });

  testWidgets('a failed fetch does not crash and simply shows the fallback state', (
    tester,
  ) async {
    final fake = _RecordingVendorMeDataSource()..fails = true;
    DataSource.instance = fake;

    await tester.pumpWidget(GetMaterialApp(home: const VendorDashboardView()));
    await tester.pumpAndSettle();

    expect(find.byType(VendorDashboardView), findsOneWidget);
    expect(find.text('Cool Air Services'), findsNothing);
  });
}
