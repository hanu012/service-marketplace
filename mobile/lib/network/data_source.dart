import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../common_model/common_response.dart';
import '../utils/injector.dart';

/// Single place every API call goes through, per CLAUDE.md: one named method
/// per endpoint on this singleton. No per-feature API classes, no generic
/// repository layer.
///
/// Endpoints mirror the backend built in tasks 0.2 and 0.3. The demo-app's
/// OTP endpoints (send-otp, verify-otp, login-with-phone) are deliberately
/// absent — CLAUDE.md forbids OTP/phone auth; this project is email + password.
class DataSource {
  static DataSource instance = DataSource();

  /// 10.0.2.2 is the host machine as seen from the Android emulator.
  /// Overridable at build time:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api/
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/',
  );

  // ── Endpoints ────────────────────────────────────────────────────────────
  static const String register = 'auth/register';
  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String forgotPassword = 'auth/forgot-password';
  static const String resetPassword = 'auth/reset-password';
  static const String resendVerification = 'auth/resend-verification';
  static const String changePassword = 'auth/change-password';
  static const String user = 'user';
  static const String vendors = 'vendors';
  static const String vendorDraft = 'vendors/draft';
  static const String categories = 'categories';
  static const String plans = 'plans';
  static const String zones = 'zones';
  static const String subscriptions = 'subscriptions';
  static const String settings = 'settings';
  static const String salesmanVendors = 'salesmen/me/vendors';
  static const String salesmanCommissions = 'salesmen/me/commissions';
  static const String vendorMe = 'vendors/me';
  static const String vendorMeServices = 'vendors/me/services';
  static const String vendorMePortfolio = 'vendors/me/portfolio';
  static const String customerMeLocation = 'customers/me/location';
  static const String vendorSearch = 'vendors/search';
  static const String leads = 'leads';
  static const String reviews = 'reviews';
  static const String vendorMeLeads = 'vendors/me/leads';
  static const String vendorMeReviews = 'vendors/me/reviews';
  static const String customerMeFavorites = 'customers/me/favorites';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      // The envelope is meaningful on 4xx too, so let those through to be
      // parsed rather than thrown.
      validateStatus: (status) => status != null && status < 500,
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (Injector.accessToken.isNotEmpty) {
            options.headers[HttpHeaders.authorizationHeader] =
                'Bearer ${Injector.accessToken}';
          }
          return handler.next(options);
        },
      ),
    );

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<CommonResponse?> registerAPI({required Map<String, dynamic> body}) =>
      _post(register, body);

  Future<CommonResponse?> loginAPI({required Map<String, dynamic> body}) =>
      _post(login, body);

  Future<CommonResponse?> logoutAPI() => _post(logout, {});

  /// Changing your own password while signed in. Distinct from the emailed
  /// reset flow: a salesman on first login has the temporary password an
  /// admin gave them, not a reset token.
  Future<CommonResponse?> changePasswordAPI({required Map<String, dynamic> body}) =>
      _post(changePassword, body);

  Future<CommonResponse?> forgotPasswordAPI({required Map<String, dynamic> body}) =>
      _post(forgotPassword, body);

  Future<CommonResponse?> resetPasswordAPI({required Map<String, dynamic> body}) =>
      _post(resetPassword, body);

  Future<CommonResponse?> resendVerificationAPI({required Map<String, dynamic> body}) =>
      _post(resendVerification, body);

  Future<CommonResponse?> userAPI() => _get(user);

  // ── Vendors (salesman add-vendor flow, SPEC 2.2) ─────────────────────────

  /// Creates the vendor in Draft before payment, so a dropped connection
  /// resumes rather than restarting. Resubmitting the same details returns
  /// the existing draft with `resumed: true` instead of a duplicate error.
  Future<CommonResponse?> vendorDraftAPI({required Map<String, dynamic> body}) =>
      _post(vendorDraft, body);

  Future<CommonResponse?> vendorShowAPI({required int vendorId}) =>
      _get('$vendors/$vendorId');

  /// The vendor's own record (SPEC section 3.2) — checked on login to
  /// decide dashboard vs plan-selection, per has_active_subscription.
  Future<CommonResponse?> vendorMeAPI() => _get(vendorMe);

  /// Adding categories/subcategories/zones to the caller's own active
  /// subscription, within whatever quota is still unused (SPEC section
  /// 3.3, task 4.4). Unlike subscribeAPI, no Idempotency-Key: this has no
  /// payment/commission side effect, and the server-side diff-based insert
  /// is naturally idempotent.
  Future<CommonResponse?> addServicesAPI({required Map<String, dynamic> body}) =>
      _post(vendorMeServices, body);

  /// The vendor's own portfolio uploads plus current photo/video quota
  /// (SPEC section 3 item 5, task 4.5) — the read companion to
  /// uploadPortfolioMediaAPI below.
  Future<CommonResponse?> vendorPortfolioAPI() => _get(vendorMePortfolio);

  /// Uploads one portfolio photo or video within remaining quota. No
  /// Idempotency-Key, matching addServicesAPI's reasoning — no payment
  /// side effect here either.
  Future<CommonResponse?> uploadPortfolioMediaAPI({
    required String type,
    required int subcategoryId,
    required String filePath,
  }) async {
    final form = FormData.fromMap({
      'type': type,
      'subcategory_id': subcategoryId,
      'file': await MultipartFile.fromFile(filePath),
    });

    return _multipart(vendorMePortfolio, form);
  }

  /// The vendor Leads tab (SPEC section 3 item 7, task 4.8) — every
  /// customer who tapped Call or WhatsApp, paginated.
  Future<CommonResponse?> vendorLeadsAPI({int page = 1, int perPage = 15}) =>
      _get(vendorMeLeads, queryParameters: {'page': page, 'per_page': perPage});

  /// SPEC section 3 item 8: "send a review request — scoped to a
  /// specific lead only." Rejects (422) if already requested, the lead
  /// already has a review, or the lead is more than 30 days old.
  Future<CommonResponse?> requestReviewAPI({required int leadId}) =>
      _post('$vendorMeLeads/$leadId/request-review', {});

  /// The vendor's OWN Reviews tab (SPEC section 3 item 8, task 4.8) —
  /// unfiltered, unlike the customer-facing vendor detail response: a
  /// vendor sees a review an admin hid, not have it silently vanish.
  Future<CommonResponse?> vendorReviewsAPI({int page = 1, int perPage = 15}) =>
      _get(vendorMeReviews, queryParameters: {'page': page, 'per_page': perPage});

  /// A vendor's right of reply on a review of their own listing (SPEC
  /// section 4 item 9, task 5.5).
  Future<CommonResponse?> replyToReviewAPI({required int reviewId, required String reply}) =>
      _post('$vendorMeReviews/$reviewId/reply', {'reply': reply});

  // ── Customer (home screen location detection, SPEC 4.2, task 4.6) ────────

  /// Resolves and persists the customer's location in one call — a GPS
  /// point, a pincode, or both (the point wins server-side when both are
  /// present). Not required together: pass whichever the caller has.
  Future<CommonResponse?> updateCustomerLocationAPI({
    double? latitude,
    double? longitude,
    String? pincode,
  }) =>
      _post(customerMeLocation, {
        'latitude': ?latitude,
        'longitude': ?longitude,
        'pincode': ?pincode,
      });

  // ── Vendor search / detail / leads (SPEC 4 items 4/6/7, tasks 5.3-5.4) ───

  /// The core customer vendor-matching query. Location is always explicit
  /// — a point or a pincode, never resolved from a stored profile (task
  /// 5.3's decision) — since this isn't a "my own record" endpoint.
  Future<CommonResponse?> vendorSearchAPI({
    required int subcategoryId,
    double? latitude,
    double? longitude,
    String? pincode,
    int page = 1,
    int perPage = 15,
  }) =>
      _get(vendorSearch, queryParameters: {
        'subcategory_id': subcategoryId,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'pincode': ?pincode,
        'page': page,
        'per_page': perPage,
      });

  /// `latitude`/`longitude` are optional — the response simply omits
  /// distance when absent, unlike search's either/or requirement.
  Future<CommonResponse?> vendorDetailAPI({
    required int vendorId,
    double? latitude,
    double? longitude,
  }) =>
      _get('$vendors/$vendorId/detail', queryParameters: {
        'latitude': ?latitude,
        'longitude': ?longitude,
      });

  /// SPEC section 4 item 7: written BEFORE the dialer/WhatsApp intent
  /// opens, never fire-and-forget. Callers must await this and check
  /// `isSuccess` before launching anything.
  Future<CommonResponse?> createLeadAPI({
    required int vendorId,
    required int subcategoryId,
    int? zoneId,
    required String channel,
  }) =>
      _post(leads, {
        'vendor_id': vendorId,
        'subcategory_id': subcategoryId,
        'zone_id': ?zoneId,
        'channel': channel,
      });

  /// SPEC section 9: gated server-side on a matching lead within the
  /// last 30 days — the server resolves which lead, this call only
  /// needs `vendorId`. A 422 with a `vendor_id` field error means no
  /// eligible lead was found.
  Future<CommonResponse?> submitReviewAPI({
    required int vendorId,
    required int rating,
    String? comment,
  }) =>
      _post(reviews, {
        'vendor_id': vendorId,
        'rating': rating,
        'comment': ?comment,
      });

  // ── Favorites / share / report vendor / account deletion (SPEC 4 item 10)

  /// Toggles — creates if absent, deletes if present — rather than
  /// separate favorite/unfavorite calls, since the caller only ever
  /// needs "is it favorited now" either way.
  Future<CommonResponse?> toggleFavoriteAPI({required int vendorId}) =>
      _post('$vendors/$vendorId/favorite', {});

  Future<CommonResponse?> favoritesAPI({int page = 1, int perPage = 15}) =>
      _get(customerMeFavorites, queryParameters: {'page': page, 'per_page': perPage});

  Future<CommonResponse?> reportVendorAPI({required int vendorId, required String reason}) =>
      _post('$vendors/$vendorId/report', {'reason': reason});

  /// Self-service account deletion (SPEC section 4 item 10, "required
  /// for app store compliance") — reuses the same tombstone mechanism
  /// the admin panel already uses, exposed here for the caller's own
  /// account only. `password` re-verifies the caller, same reasoning as
  /// changePasswordAPI's `current_password`.
  Future<CommonResponse?> deleteAccountAPI({required String password}) =>
      _delete(user, body: {'password': password});

  // ── Master data (SPEC 2.2 step 2: plan → categories/subcategories → zones)

  /// Unpaginated by design (CLAUDE.md) — the whole tree is needed in one
  /// request to render selection with a live "X of Y selected" counter.
  Future<CommonResponse?> categoriesAPI() => _get(categories);

  Future<CommonResponse?> plansAPI() => _get(plans);

  Future<CommonResponse?> zonesAPI() => _get(zones);

  /// A whitelisted subset of admin Settings (SPEC section 5.17) — currently
  /// just free_trial_max_days. Fetched live rather than hardcoded, so an
  /// admin-changed cap takes effect without an app update.
  Future<CommonResponse?> settingsAPI() => _get(settings);

  // ── Salesman (My Vendors / Earnings, SPEC 2.3, 2.4) ──────────────────────

  Future<CommonResponse?> salesmanVendorsAPI() => _get(salesmanVendors);

  Future<CommonResponse?> salesmanCommissionsAPI() => _get(salesmanCommissions);

  /// Subscribe (SPEC section 6). The Idempotency-Key header is required
  /// server-side and enforced via a unique column there — a dropped
  /// response and a retry with the same key returns the original
  /// subscription rather than creating a second one.
  Future<CommonResponse?> subscribeAPI({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) =>
      _post(subscriptions, body, headers: {'Idempotency-Key': idempotencyKey});

  /// KYC upload. A separate call from the draft create on purpose: a slow or
  /// failed photo on a weak connection costs the upload, not the typed
  /// business details.
  Future<CommonResponse?> vendorKycAPI({
    required int vendorId,
    String? shopPhotoPath,
    String? idProofPath,
    String? idProofType,
  }) async {
    final form = FormData.fromMap({
      'id_proof_type': ?idProofType,
      if (shopPhotoPath != null)
        'shop_photo': await MultipartFile.fromFile(shopPhotoPath),
      if (idProofPath != null)
        'id_proof': await MultipartFile.fromFile(idProofPath),
    });

    return _multipart('$vendors/$vendorId/kyc', form);
  }

  // ── Plumbing ─────────────────────────────────────────────────────────────

  Future<CommonResponse?> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: body,
        options: headers == null ? null : Options(headers: headers),
      );
      return _parse(response);
    } catch (e) {
      if (kDebugMode) {
        print('POST $path failed: $e');
      }
      return null;
    }
  }

  /// Multipart variant of _post. Dio sets the boundary and content-type
  /// itself for FormData, so the JSON content-type header from BaseOptions is
  /// overridden per request rather than globally.
  Future<CommonResponse?> _multipart(String path, FormData form) async {
    try {
      final response = await _dio.post(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _parse(response);
    } catch (e) {
      if (kDebugMode) {
        print('MULTIPART $path failed: $e');
      }
      return null;
    }
  }

  Future<CommonResponse?> _delete(String path, {Map<String, dynamic>? body}) async {
    try {
      final response = await _dio.delete(path, data: body);
      return _parse(response);
    } catch (e) {
      if (kDebugMode) {
        print('DELETE $path failed: $e');
      }
      return null;
    }
  }

  Future<CommonResponse?> _get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _parse(response);
    } catch (e) {
      if (kDebugMode) {
        print('GET $path failed: $e');
      }
      return null;
    }
  }

  CommonResponse? _parse(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final parsed = CommonResponse.fromJson(data, statusCode: response.statusCode);

    // The token is gone server-side, so drop the local copy rather than
    // letting screens retry with a credential that can never work again.
    if (response.statusCode == 401) {
      Injector.clearUserData();
    }

    return parsed;
  }
}
