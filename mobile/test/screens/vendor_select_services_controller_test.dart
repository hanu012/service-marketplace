import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/common_model/category_model.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/common_model/plan_model.dart';
import 'package:service_marketplace/common_model/zone_model.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_dashboard_module/vendor_dashboard_view.dart';
import 'package:service_marketplace/screens/auth_flow/vendor_select_services_module/vendor_select_services_controller.dart';

/// Selection-cascade rules mirror select_services_controller_test.dart
/// (same underlying quota logic, SPEC section 3.2) — this module is a
/// fresh copy, not a reuse, so it needs its own coverage rather than
/// inheriting the salesman-flow tests.
void main() {
  late CategoryModel acRepair;
  late SubcategoryModel gasFilling;
  late SubcategoryModel installation;
  late ZoneModel ahmedabad;
  late ZoneModel gota;
  late ZoneModel sola;

  VendorSelectServicesController buildController({
    int maxCategories = 2,
    int maxSubcategories = 2,
    int maxZones = 2,
  }) {
    gasFilling = SubcategoryModel(id: 101, categoryId: 1, name: 'Gas Filling');
    installation = SubcategoryModel(id: 102, categoryId: 1, name: 'Installation');
    acRepair = CategoryModel(id: 1, name: 'AC Repair', subcategories: [gasFilling, installation]);

    gota = ZoneModel(id: 201, name: 'Gota', isLeaf: true);
    sola = ZoneModel(id: 202, name: 'Sola', isLeaf: true);
    ahmedabad = ZoneModel(id: 200, name: 'Ahmedabad', isLeaf: false, children: [gota, sola]);

    final plan = PlanModel(
      id: 2,
      name: 'Gold',
      maxCategories: maxCategories,
      maxSubcategories: maxSubcategories,
      maxZones: maxZones,
    );

    final controller = VendorSelectServicesController(vendorId: 42, plan: plan);
    controller.categories = [acRepair];
    controller.zones = [ahmedabad];

    return controller;
  }

  testWidgets('selecting a subcategory auto-selects its parent category', (tester) async {
    final controller = buildController();

    controller.toggleSubcategory(gasFilling, acRepair);

    expect(controller.isSubcategorySelected(gasFilling.id!), isTrue);
    expect(controller.isCategorySelected(acRepair.id!), isTrue);
  });

  testWidgets('zone selection respects max_zones', (tester) async {
    final controller = buildController(maxZones: 1);

    controller.toggleZone(gota);
    expect(controller.zoneQuotaReached, isTrue);

    controller.toggleZone(sola);
    expect(controller.isZoneSelected(sola.id!), isFalse);
  });

  testWidgets('validateSelections fails when a dimension is empty', (tester) async {
    final controller = buildController();

    expect(controller.validateSelections(), isFalse);
  });

  testWidgets('validateSelections passes once every dimension has a pick', (tester) async {
    final controller = buildController();

    controller.toggleSubcategory(gasFilling, acRepair);
    controller.toggleZone(gota);

    expect(controller.validateSelections(), isTrue);
  });

  testWidgets('quota caps come from the plan passed in, not a hardcoded default', (
    tester,
  ) async {
    final controller = buildController(maxCategories: 3, maxSubcategories: 6, maxZones: 2);

    expect(controller.maxCategories, 3);
    expect(controller.maxSubcategories, 6);
    expect(controller.maxZones, 2);
  });

  VendorSelectServicesController buildReadyController() {
    final plan =
        PlanModel(id: 2, name: 'Gold', maxCategories: 2, maxSubcategories: 2, maxZones: 2);
    final controller = VendorSelectServicesController(vendorId: 42, plan: plan);
    controller.selectedCategoryIds.add(1);
    controller.selectedSubcategoryIds.add(101);
    controller.selectedZoneIds.add(201);
    return controller;
  }

  testWidgets('subscribeAPI always sends payment_mode online, no dialog involved', (
    tester,
  ) async {
    final fake = _RecordingSubscribeDataSource();
    DataSource.instance = fake;

    final controller = buildReadyController();

    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: SizedBox())));
    await controller.subscribeAPI();
    await tester.pumpAndSettle();

    expect(fake.capturedBody?['vendor_id'], 42);
    expect(fake.capturedBody?['plan_id'], 2);
    expect(fake.capturedBody?['payment_mode'], 'online');
    expect(fake.capturedBody!.containsKey('free_trial_days'), isFalse);

    expect(find.byType(VendorDashboardView), findsOneWidget);

    controller.onClose();
  });

  testWidgets('a server-side rejection does not navigate and resets isSubmitting', (
    tester,
  ) async {
    final fake = _RecordingSubscribeDataSource()..succeeds = false;
    DataSource.instance = fake;

    final controller = buildReadyController();

    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: SizedBox())));
    await controller.subscribeAPI();
    await tester.pumpAndSettle();

    expect(find.byType(VendorDashboardView), findsNothing);
    expect(controller.isSubmitting, isFalse);

    controller.onClose();
  });

  // ── Add more within remaining quota (task 4.4) ──────────────────────────

  VendorSelectServicesController buildAddMoreController() {
    final controller = buildController(maxCategories: 2, maxSubcategories: 2, maxZones: 2);
    final addMore = VendorSelectServicesController(
      vendorId: 42,
      plan: controller.plan,
      isAddingMore: true,
      existingCategoryIds: {acRepair.id!},
      existingSubcategoryIds: {gasFilling.id!},
      existingZoneIds: {gota.id!},
    );
    addMore.categories = [acRepair];
    addMore.zones = [ahmedabad];
    return addMore;
  }

  testWidgets('existing selections are pre-seeded and cannot be toggled off', (tester) async {
    final controller = buildAddMoreController();

    expect(controller.isCategorySelected(acRepair.id!), isTrue);
    expect(controller.isSubcategorySelected(gasFilling.id!), isTrue);
    expect(controller.isZoneSelected(gota.id!), isTrue);

    controller.toggleCategory(acRepair);
    controller.toggleSubcategory(gasFilling, acRepair);
    controller.toggleZone(gota);

    expect(controller.isCategorySelected(acRepair.id!), isTrue);
    expect(controller.isSubcategorySelected(gasFilling.id!), isTrue);
    expect(controller.isZoneSelected(gota.id!), isTrue);
  });

  testWidgets('quota caps count existing selections toward the max', (tester) async {
    // maxSubcategories: 2, one (gasFilling) is already existing/locked —
    // only one more slot remains.
    final controller = buildAddMoreController();

    expect(controller.subcategoryQuotaReached, isFalse);
    controller.toggleSubcategory(installation, acRepair);

    expect(controller.isSubcategorySelected(installation.id!), isTrue);
    expect(controller.subcategoryQuotaReached, isTrue);
  });

  testWidgets('addServicesAPI sends only the newly added ids, no vendor_id or payment_mode', (
    tester,
  ) async {
    final fake = _RecordingAddServicesDataSource();
    DataSource.instance = fake;

    final controller = buildAddMoreController();
    controller.toggleSubcategory(installation, acRepair);
    controller.toggleZone(sola);

    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: SizedBox())));
    await controller.addServicesAPI();
    await tester.pumpAndSettle();

    expect(fake.capturedBody?['category_ids'], isEmpty);
    expect(fake.capturedBody?['subcategory_ids'], [installation.id]);
    expect(fake.capturedBody?['zone_ids'], [sola.id]);
    expect(fake.capturedBody!.containsKey('vendor_id'), isFalse);
    expect(fake.capturedBody!.containsKey('plan_id'), isFalse);
    expect(fake.capturedBody!.containsKey('payment_mode'), isFalse);

    controller.onClose();
  });

  testWidgets('addServicesAPI with nothing new selected does not call the API', (tester) async {
    final fake = _RecordingAddServicesDataSource();
    DataSource.instance = fake;

    final controller = buildAddMoreController();

    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: SizedBox())));
    await controller.addServicesAPI();
    await tester.pumpAndSettle();

    expect(fake.capturedBody, isNull);

    controller.onClose();
  });

  testWidgets('a server-side rejection from addServicesAPI resets isSubmitting', (
    tester,
  ) async {
    final fake = _RecordingAddServicesDataSource()..succeeds = false;
    DataSource.instance = fake;

    final controller = buildAddMoreController();
    controller.toggleZone(sola);

    await tester.pumpWidget(GetMaterialApp(home: const Scaffold(body: SizedBox())));
    await controller.addServicesAPI();
    await tester.pumpAndSettle();

    expect(fake.capturedBody, isNotNull);
    expect(controller.isSubmitting, isFalse);

    controller.onClose();
  });
}

/// Captures what would go out over the wire to POST /vendors/me/services
/// (task 4.4) — no vendor_id/plan_id/payment_mode, unlike subscribeAPI's
/// body, since everything resolves server-side from the caller's own
/// active subscription.
class _RecordingAddServicesDataSource extends DataSource {
  Map<String, dynamic>? capturedBody;
  bool succeeds = true;

  @override
  Future<CommonResponse?> addServicesAPI({required Map<String, dynamic> body}) async {
    capturedBody = body;

    if (!succeeds) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'VALIDATION_FAILED', 'message': 'The given data was invalid.'},
      }, statusCode: 422);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'active_subscription': {
          'plan_name': 'Gold',
          'end_date': '2027-01-01',
          'days_remaining': 100,
          'quota': {
            'categories': {'used': 1, 'max': 2},
            'subcategories': {'used': 2, 'max': 2},
            'zones': {'used': 2, 'max': 2},
          },
        },
      },
      'error': null,
    });
  }
}

/// Captures what would go out over the wire to POST /api/subscriptions for
/// the self-service caller — no payment_mode dialog exists on this screen,
/// so subscribeAPI always sends 'online' (SPEC section 3.2).
class _RecordingSubscribeDataSource extends DataSource {
  Map<String, dynamic>? capturedBody;
  bool succeeds = true;

  @override
  Future<CommonResponse?> subscribeAPI({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    capturedBody = body;

    if (!succeeds) {
      return CommonResponse.fromJson({
        'success': false,
        'data': null,
        'error': {'code': 'VALIDATION_FAILED', 'message': 'The given data was invalid.'},
      }, statusCode: 422);
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'subscription': {
          'id': 55,
          'vendor_id': body['vendor_id'],
          'plan_id': body['plan_id'],
          'plan_name': 'Gold',
          'source': 'self',
          'status': 'pending_verification',
          'start_date': '2026-08-21',
          'end_date': '2026-11-19',
          'price_paise': 249900,
        },
        'vendor': {'id': body['vendor_id'], 'status': 'pending_verification'},
        'temporary_password': null,
      },
      'error': null,
    }, statusCode: 201);
  }

  // The dashboard it navigates to on success fetches this in onInit.
  @override
  Future<CommonResponse?> vendorMeAPI() async {
    return CommonResponse.fromJson({
      'success': true,
      'data': {
        'vendor': {
          'id': 42,
          'business_name': 'Cool Air',
          'owner_name': 'Asha Patel',
          'phone': '9812345678',
          'email': 'vendor@example.com',
          'status': 'pending_verification',
          'has_active_subscription': false,
        },
        'active_subscription': null,
      },
      'error': null,
    });
  }
}
