import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app.export.dart';

/// Vendor detail page (SPEC section 4 item 6, task 5.4/5.5).
///
/// The Call/WhatsApp buttons are this controller's other reason to
/// exist: SPEC section 4 item 7 requires the lead record to be written
/// and CONFIRMED before the dialer/WhatsApp intent opens — never
/// fire-and-forget. [_recordLead] is the one chokepoint both buttons
/// share, so that ordering can't drift between them.
///
/// [submitReviewAPI] (SPEC section 9, task 5.5) re-runs [fetchAPI] on
/// success rather than inserting the new review locally — the backend
/// also just recalculated `rating_avg`/`rating_count`, and re-fetching
/// is the only way this screen picks that up too, not just the review
/// list. No edit UI here: the 24-hour edit window is a real, tested
/// backend capability (PATCH /api/reviews/{review}), but this public,
/// unauthenticated detail response has no way to say "which of these
/// reviews is mine" — see PROGRESS.md's task 5.5 entry.
class VendorDetailController extends GetxController {
  final int vendorId;

  /// Nullable: the search-results screen always has one (the
  /// subcategory the customer drilled into), but the favorites list
  /// (task: favorites/share/report/account deletion) does not — a
  /// favorited vendor isn't tied to any one subcategory. When absent,
  /// [_recordLead] falls back to the vendor's own first listed service
  /// once the detail response has loaded, rather than blocking Call/
  /// WhatsApp entirely.
  final int? subcategoryId;
  final int? zoneId;
  final double? latitude;
  final double? longitude;

  VendorDetailController({
    required this.vendorId,
    required this.subcategoryId,
    required this.zoneId,
    required this.latitude,
    required this.longitude,
  });

  /// Swappable seam for tests — url_launcher's top-level launchUrl() is a
  /// platform channel call with no test double of its own, same
  /// @visibleForTesting extraction VendorPortfolioController.uploadFile()
  /// already uses for image_picker.
  @visibleForTesting
  Future<bool> Function(Uri url) launchUrlFn = launchUrl;

  /// Swappable seam for tests — Share.share() is a platform channel
  /// call with no test double of its own, same reasoning as
  /// [launchUrlFn].
  @visibleForTesting
  Future<void> Function(String text) shareFn = (text) async {
    await Share.share(text);
  };

  VendorDetailModel? vendor;
  bool isLoading = false;
  bool isSubmittingLead = false;
  bool isSubmittingReview = false;
  bool isSubmittingReport = false;

  @override
  void onInit() {
    super.onInit();
    fetchAPI();
  }

  Future<void> fetchAPI() async {
    isLoading = true;
    update();

    try {
      final response = await DataSource.instance.vendorDetailAPI(
        vendorId: vendorId,
        latitude: latitude,
        longitude: longitude,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.vendorNotFound),
          isError: true,
        );
        return;
      }

      vendor = VendorDetailModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('Vendor detail error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> callAPI() async {
    final phone = vendor?.phone;

    if (phone == null || phone.isEmpty || isSubmittingLead) {
      return;
    }

    final leadWritten = await _recordLead('call');

    if (!leadWritten) {
      return;
    }

    await launchUrlFn(Uri(scheme: 'tel', path: phone));
  }

  Future<void> whatsappAPI() async {
    final phone = vendor?.phone;

    if (phone == null || phone.isEmpty || isSubmittingLead) {
      return;
    }

    final leadWritten = await _recordLead('whatsapp');

    if (!leadWritten) {
      return;
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await launchUrlFn(Uri.parse('https://wa.me/$digits'));
  }

  /// The single chokepoint SPEC section 4 item 7's ordering rule runs
  /// through: writes the lead and returns whether it durably succeeded.
  /// Callers must not open the dialer/WhatsApp intent when this returns
  /// false — the write failing is surfaced as an error, not swallowed.
  Future<bool> _recordLead(String channel) async {
    final effectiveSubcategoryId = subcategoryId ??
        (vendor != null && vendor!.services.isNotEmpty ? vendor!.services.first.subcategoryId : null);

    if (effectiveSubcategoryId == null) {
      Utils.showToast(tr(StringRes.leadFailedTryAgain), isError: true);
      return false;
    }

    isSubmittingLead = true;
    update();

    try {
      final response = await DataSource.instance.createLeadAPI(
        vendorId: vendorId,
        subcategoryId: effectiveSubcategoryId,
        zoneId: zoneId,
        channel: channel,
      );

      if (response == null || !response.isSuccess) {
        Utils.showToast(tr(StringRes.leadFailedTryAgain), isError: true);
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Record lead error $e');
      }
      Utils.showToast(tr(StringRes.leadFailedTryAgain), isError: true);
      return false;
    } finally {
      isSubmittingLead = false;
      update();
    }
  }

  /// SPEC section 9: gated server-side on a matching lead within the
  /// last 30 days. The "no eligible lead" case (a 422 on `vendor_id`)
  /// gets its own message rather than the generic error toast, since
  /// "you haven't contacted this vendor recently enough to review them"
  /// is actionable information, not a failure to apologize for.
  Future<bool> submitReviewAPI({required int rating, String? comment}) async {
    isSubmittingReview = true;
    update();

    try {
      final response = await DataSource.instance.submitReviewAPI(
        vendorId: vendorId,
        rating: rating,
        comment: comment,
      );

      if (response == null || !response.isSuccess) {
        Utils.showToast(
          response?.fieldError('vendor_id') ?? tr(StringRes.reviewSubmitFailed),
          isError: true,
        );
        return false;
      }

      Utils.showToast(tr(StringRes.reviewSubmitted));
      await fetchAPI();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Submit review error $e');
      }
      Utils.showToast(tr(StringRes.reviewSubmitFailed), isError: true);
      return false;
    } finally {
      isSubmittingReview = false;
      update();
    }
  }

  /// Optimistic, same shape as VendorSearchController's own toggle —
  /// the two are separate copies (not shared) because they operate on
  /// different model instances (VendorDetailModel vs VendorSearchModel)
  /// with no relation between them.
  Future<void> toggleFavoriteAPI() async {
    final current = vendor;
    if (current == null) {
      return;
    }

    final previous = current.isFavorite;
    current.isFavorite = !previous;
    update();

    try {
      final response = await DataSource.instance.toggleFavoriteAPI(vendorId: vendorId);

      if (response == null || !response.isSuccess) {
        current.isFavorite = previous;
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
      }
    } catch (e) {
      current.isFavorite = previous;
      if (kDebugMode) {
        print('Toggle favorite error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      update();
    }
  }

  /// A text summary only — see CLAUDE.md/PROGRESS.md: no deep-linking
  /// package exists in this app, so a shared "link" could not actually
  /// open the profile for someone without the app. Building real deep
  /// linking is a separate, much larger undertaking, out of scope here.
  Future<void> shareProfile() async {
    final current = vendor;
    if (current == null) {
      return;
    }

    final ratingLine = (current.ratingCount ?? 0) > 0
        ? '${current.ratingAvg?.toStringAsFixed(1)} ★ (${current.ratingCount} ${tr(StringRes.reviewsSectionTitle)})'
        : tr(StringRes.newVendorLabel);

    final message = '${current.businessName ?? ''}\n'
        '$ratingLine\n'
        '${current.address ?? ''}\n'
        '${current.phone ?? ''}';

    try {
      await shareFn(message);
    } catch (e) {
      if (kDebugMode) {
        print('Share vendor profile error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  /// SPEC section 4 item 10 / section 5.15 — minimal, no ticket
  /// lifecycle. A repeat report against the same vendor is a no-op
  /// success server-side, so this never needs to distinguish "already
  /// reported" from "reported just now".
  Future<bool> reportVendorAPI(String reason) async {
    isSubmittingReport = true;
    update();

    try {
      final response = await DataSource.instance.reportVendorAPI(
        vendorId: vendorId,
        reason: reason,
      );

      if (response == null || !response.isSuccess) {
        Utils.showToast(response?.message ?? tr(StringRes.reportVendorFailed), isError: true);
        return false;
      }

      Utils.showToast(tr(StringRes.reportVendorSubmitted));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Report vendor error $e');
      }
      Utils.showToast(tr(StringRes.reportVendorFailed), isError: true);
      return false;
    } finally {
      isSubmittingReport = false;
      update();
    }
  }
}
