import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app.export.dart';

/// Vendor portfolio (SPEC section 3 item 5, task 4.5) — photos/videos of
/// completed work, quota-capped by the active subscription's plan, routed
/// through admin moderation before going live.
///
/// OWN fetch, not shared with VendorDashboardController — unlike the
/// Services tab (task 4.4), which deliberately shares the dashboard's
/// single GET /vendors/me fetch because it's a view over the same data,
/// this is genuinely independent data (its own list, its own quota
/// source), matching the salesman_home_module -> my_vendors_module split
/// instead.
///
/// VIDEO COMPRESSION: no client-side transcoding exists (see PROGRESS.md's
/// Before Launch Checklist) — real compression needs a native-encoder or
/// FFmpeg wrapper, neither a responsible dependency to add today (see the
/// task 4.5 plan). The fallback: pickVideo caps recording/selection length,
/// and a picked file over the 50 MB server cap is rejected locally before
/// any upload attempt, so the vendor gets fast feedback rather than a slow
/// failed request.
class VendorPortfolioController extends GetxController {
  static const int _maxVideoBytes = 50 * 1024 * 1024; // 50 MB, matches the server cap.

  final ImagePicker _picker = ImagePicker();

  List<PortfolioMediaModel> media = [];
  List<SelectedServiceItemModel> subcategories = [];

  /// For the hero. Taken from this screen's own /vendors/me call rather
  /// than reached for on the dashboard controller — the two already fetch
  /// independently, and a cross-controller read would couple this screen
  /// to being hosted by that shell.
  String businessName = '';

  /// Two letters for the hero's avatar tile.
  String get initials {
    final parts = businessName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      final one = parts.first;

      return (one.length >= 2 ? one.substring(0, 2) : one).toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  QuotaResourceModel? photosQuota;
  QuotaResourceModel? videosQuota;
  bool isLoading = false;
  bool isUploading = false;
  int? selectedSubcategoryId;

  /// Which kind of file is going up, so the progress card can name it.
  /// Null whenever nothing is uploading.
  String? uploadingType;

  /// 0..1 of the request body written so far, or null until the first
  /// callback arrives — and while the server is still working after the
  /// last byte went out. A video upload finishes sending long before the
  /// response comes back, and pinning the bar at 100% through that wait
  /// reads as a hang, so the view shows an indeterminate bar instead.
  double? uploadProgress;

  @override
  void onInit() {
    super.onInit();
    fetchPortfolioAPI();
  }

  Future<void> fetchPortfolioAPI() async {
    isLoading = true;
    update();

    try {
      final responses = await Future.wait([
        DataSource.instance.vendorPortfolioAPI(),
        DataSource.instance.vendorMeAPI(),
      ]);

      final portfolioResponse = responses[0];
      final meResponse = responses[1];

      if (portfolioResponse == null ||
          !portfolioResponse.isSuccess ||
          portfolioResponse.data == null) {
        Utils.showToast(
          portfolioResponse?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final portfolio =
          VendorPortfolioModel.fromJson(portfolioResponse.data as Map<String, dynamic>);
      media = portfolio.media;
      photosQuota = portfolio.photos;
      videosQuota = portfolio.videos;

      if (meResponse != null && meResponse.isSuccess && meResponse.data != null) {
        final vendorMe = VendorMeModel.fromJson(meResponse.data as Map<String, dynamic>);
        businessName = vendorMe.businessName ?? '';
        subcategories = vendorMe.activeSubscription?.selectedSubcategories ?? [];
        selectedSubcategoryId ??= subcategories.isEmpty ? null : subcategories.first.id;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch portfolio error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  void selectSubcategory(int subcategoryId) {
    selectedSubcategoryId = subcategoryId;
    update();
  }

  /// What the grid shows: only the work filed under the selected service.
  ///
  /// The chip row does double duty — it tags a new upload and it scopes
  /// the grid — because those are the same question asked twice. A
  /// vendor on a large plan can have forty subcategories, and one
  /// undifferentiated wall of every photo they have ever uploaded is not
  /// something they can check their AC-repair work in.
  List<PortfolioMediaModel> get visibleMedia {
    if (selectedSubcategoryId == null) {
      return media;
    }

    return media
        .where((item) => item.subcategoryId == selectedSubcategoryId)
        .toList();
  }

  /// Name of the service the grid is currently scoped to, for the empty
  /// state to name it rather than say "this service".
  String? get selectedSubcategoryName {
    for (final subcategory in subcategories) {
      if (subcategory.id == selectedSubcategoryId) {
        return subcategory.name;
      }
    }

    return null;
  }

  /// Media count per subcategory id, so a chip can say what is behind it
  /// before the vendor taps it.
  Map<int, int> get mediaCountBySubcategory {
    final counts = <int, int>{};

    for (final item in media) {
      final id = item.subcategoryId;
      if (id != null) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }

    return counts;
  }

  Future<void> pickAndUploadPhoto() async {
    if (!_validateReadyToUpload()) {
      return;
    }

    XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (kDebugMode) {
        print('Pick photo error $e');
      }
    }

    if (picked == null) {
      return;
    }

    final compressedPath = await _compress(picked.path);

    await uploadFile(type: 'image', filePath: compressedPath ?? picked.path);
  }

  Future<void> pickAndUploadVideo() async {
    if (!_validateReadyToUpload()) {
      return;
    }

    XFile? picked;
    try {
      picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Pick video error $e');
      }
    }

    if (picked == null) {
      return;
    }

    final size = await File(picked.path).length();

    await uploadFile(type: 'video', filePath: picked.path, sizeBytes: size);
  }

  bool _validateReadyToUpload() {
    if (selectedSubcategoryId == null) {
      Utils.showToast(tr(StringRes.selectASubcategory), isError: true);
      return false;
    }

    return true;
  }

  bool isVideoTooLarge(int sizeBytes) => sizeBytes > _maxVideoBytes;

  /// Best-effort — an upload still proceeds with the original file if
  /// compression fails, rather than blocking the vendor entirely.
  Future<String?> _compress(String sourcePath) async {
    try {
      final targetPath = '${sourcePath}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: 80,
        minWidth: 1600,
        minHeight: 1600,
      );

      return result?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Compress photo error $e');
      }
      return null;
    }
  }

  /// The actual upload call, kept separate from the picker methods above so
  /// it's directly testable without mocking image_picker's platform channel
  /// — no test in this codebase exercises image_picker itself (same reason
  /// add_vendor_controller's KYC upload isn't unit-tested through the
  /// picker either), only the validation/API-call logic around it.
  @visibleForTesting
  Future<void> uploadFile({
    required String type,
    required String filePath,
    int? sizeBytes,
  }) async {
    if (!_validateReadyToUpload()) {
      return;
    }

    if (type == 'video' && sizeBytes != null && isVideoTooLarge(sizeBytes)) {
      Utils.showToast(tr(StringRes.videoTooLarge), isError: true);
      return;
    }

    isUploading = true;
    uploadingType = type;
    uploadProgress = null;
    update();

    try {
      // No full-screen Lottie here, unlike the other calls: an upload is
      // the one request in this app slow enough that the vendor needs to
      // see how far along it is, and a blocking overlay would hide the
      // grid it is being added to.
      final response = await DataSource.instance.uploadPortfolioMediaAPI(
        type: type,
        subcategoryId: selectedSubcategoryId!,
        filePath: filePath,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            return;
          }

          // Back to indeterminate once the body is fully sent — what is
          // left is server-side work with no progress to report.
          uploadProgress = sent >= total ? null : sent / total;
          update();
        },
      );

      if (response == null || !response.isSuccess || response.data == null) {
        final fieldError = response?.fieldError('file') ??
            response?.fieldError('subcategory_id') ??
            response?.fieldError('subscription');

        Utils.showToast(
          fieldError ?? response?.message ?? tr(StringRes.uploadFailed),
          isError: true,
        );
        return;
      }

      Utils.showToast(tr(StringRes.mediaUploaded));
      await fetchPortfolioAPI();
    } catch (e) {
      if (kDebugMode) {
        print('Upload media error $e');
      }
      Utils.showToast(tr(StringRes.uploadFailed), isError: true);
    } finally {
      isUploading = false;
      uploadingType = null;
      uploadProgress = null;
      update();
    }
  }
}
