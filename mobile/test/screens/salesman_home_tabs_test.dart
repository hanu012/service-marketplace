import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/earnings_module/earnings_controller.dart';
import 'package:service_marketplace/screens/auth_flow/earnings_module/earnings_view.dart';
import 'package:service_marketplace/screens/auth_flow/my_vendors_module/my_vendors_controller.dart';
import 'package:service_marketplace/screens/auth_flow/my_vendors_module/my_vendors_view.dart';
import 'package:service_marketplace/screens/auth_flow/salesman_home_module/salesman_home_view.dart';
import 'package:service_marketplace/screens/vendor_flow/add_vendor_module/add_vendor_view.dart';

/// GET /api/salesmen/me/vendors and GET /api/salesmen/me/commissions
/// (SPEC sections 2.3, 2.4).
class _RecordingSalesmanDataSource extends DataSource {
  List<Map<String, dynamic>> vendorRows = [];
  Map<String, dynamic>? commissionSummary;
  bool vendorsSucceed = true;
  bool commissionsSucceed = true;

  @override
  Future<CommonResponse?> salesmanVendorsAPI() async {
    if (!vendorsSucceed) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'FORBIDDEN', 'message': 'This action is unauthorized.'},
      }, statusCode: 403);
    }

    return CommonResponse.fromJson({'success': true, 'data': vendorRows, 'error': null});
  }

  @override
  Future<CommonResponse?> salesmanCommissionsAPI() async {
    if (!commissionsSucceed) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'FORBIDDEN', 'message': 'This action is unauthorized.'},
      }, statusCode: 403);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': commissionSummary ??
          {
            'pending_amount_paise': 0,
            'paid_amount_paise': 0,
            'pending_count': 0,
            'paid_count': 0,
          },
      'error': null,
    });
  }
}

void main() {
  group('MyVendorsController', () {
    testWidgets('parses vendor rows including null plan/days for a draft vendor', (
      tester,
    ) async {
      final fake = _RecordingSalesmanDataSource()
        ..vendorRows = [
          {
            'id': 1,
            'business_name': 'Cool Air',
            'status': 'active',
            'plan_name': 'Gold',
            'days_to_expiry': 10,
          },
          {
            'id': 2,
            'business_name': 'Still Draft',
            'status': 'draft',
            'plan_name': null,
            'days_to_expiry': null,
          },
        ];
      DataSource.instance = fake;

      final controller = MyVendorsController();
      await controller.fetchVendorsAPI();

      expect(controller.vendors.length, 2);
      expect(controller.vendors[0].planName, 'Gold');
      expect(controller.vendors[0].daysToExpiry, 10);
      expect(controller.vendors[1].planName, isNull);
      expect(controller.vendors[1].daysToExpiry, isNull);

      controller.onClose();
    });

    testWidgets('an expired subscription keeps its negative days-to-expiry, not clamped', (
      tester,
    ) async {
      final fake = _RecordingSalesmanDataSource()
        ..vendorRows = [
          {
            'id': 3,
            'business_name': 'Expired Vendor',
            'status': 'expired',
            'plan_name': 'Silver',
            'days_to_expiry': -4,
          },
        ];
      DataSource.instance = fake;

      final controller = MyVendorsController();
      await controller.fetchVendorsAPI();

      expect(controller.vendors.single.daysToExpiry, -4);

      controller.onClose();
    });

    testWidgets('a failed fetch leaves the vendor list empty rather than crashing', (
      tester,
    ) async {
      final fake = _RecordingSalesmanDataSource()..vendorsSucceed = false;
      DataSource.instance = fake;

      final controller = MyVendorsController();
      await controller.fetchVendorsAPI();

      expect(controller.vendors, isEmpty);
      expect(controller.isLoading, isFalse);

      controller.onClose();
    });

    testWidgets(
      'the rendered row shows "Expired N days ago", not a raw negative number, without overflowing',
      (tester) async {
        final fake = _RecordingSalesmanDataSource()
          ..vendorRows = [
            {
              'id': 3,
              'business_name': 'Expired Vendor',
              'status': 'expired',
              'plan_name': 'Silver',
              'days_to_expiry': -4,
            },
          ];
        DataSource.instance = fake;

        await tester.pumpWidget(const GetMaterialApp(home: MyVendorsView()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('-4'), findsNothing);
        expect(find.textContaining('4'), findsOneWidget);
      },
    );

    testWidgets(
      'the empty-state Add vendor button navigates to AddVendorView',
      (tester) async {
        DataSource.instance = _RecordingSalesmanDataSource();

        await tester.pumpWidget(const GetMaterialApp(home: MyVendorsView()));
        await tester.pumpAndSettle();

        // .tr() falls back to the raw key untranslated here since this
        // test doesn't wrap the tree in EasyLocalization, matching the
        // pattern the rest of this file's widget tests already rely on.
        await tester.tap(find.text('addVendorTitle'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AddVendorView), findsOneWidget);
      },
    );
  });

  group('SalesmanHomeView', () {
    testWidgets(
      'the app bar Add vendor icon navigates to AddVendorView from either tab',
      (tester) async {
        DataSource.instance = _RecordingSalesmanDataSource();

        await tester.pumpWidget(const GetMaterialApp(home: SalesmanHomeView()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.person_add_alt_1));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AddVendorView), findsOneWidget);
      },
    );
  });

  group('EarningsController', () {
    testWidgets('parses pending/paid totals separately', (tester) async {
      final fake = _RecordingSalesmanDataSource()
        ..commissionSummary = {
          'pending_amount_paise': 3000,
          'paid_amount_paise': 5000,
          'pending_count': 2,
          'paid_count': 1,
        };
      DataSource.instance = fake;

      final controller = EarningsController();
      await controller.fetchCommissionsAPI();

      expect(controller.summary?.pendingAmountPaise, 3000);
      expect(controller.summary?.paidAmountPaise, 5000);
      expect(controller.summary?.pendingCount, 2);
      expect(controller.summary?.paidCount, 1);

      controller.onClose();
    });

    testWidgets('a failed fetch leaves summary null rather than crashing', (tester) async {
      final fake = _RecordingSalesmanDataSource()..commissionsSucceed = false;
      DataSource.instance = fake;

      final controller = EarningsController();
      await controller.fetchCommissionsAPI();

      expect(controller.summary, isNull);
      expect(controller.isLoading, isFalse);

      controller.onClose();
    });

    testWidgets('the rendered cards show rupees, not paise, without overflowing', (tester) async {
      final fake = _RecordingSalesmanDataSource()
        ..commissionSummary = {
          'pending_amount_paise': 300000,
          'paid_amount_paise': 500000,
          'pending_count': 2,
          'paid_count': 1,
        };
      DataSource.instance = fake;

      await tester.pumpWidget(const GetMaterialApp(home: EarningsView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('₹3000.00'), findsOneWidget);
      expect(find.text('₹5000.00'), findsOneWidget);
    });
  });
}
