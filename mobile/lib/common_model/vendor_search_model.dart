import 'customer_location_model.dart';

/// One vendor row from `GET /api/vendors/search` (SPEC section 4 item 4,
/// task 5.3) — deliberately narrow (no phone/services/media, those are
/// vendor_detail_model.dart's job, task 5.4).
class VendorSearchModel {
  int? id;
  String? businessName;
  String? address;
  double? latitude;
  double? longitude;
  String? shopPhotoUrl;
  double? ratingAvg;
  int? ratingCount;

  /// Task: favorites/share/report/account deletion. Not nullable —
  /// the backend always includes it, defaulting `false` for a guest.
  bool isFavorite;

  VendorSearchModel({
    this.id,
    this.businessName,
    this.address,
    this.latitude,
    this.longitude,
    this.shopPhotoUrl,
    this.ratingAvg,
    this.ratingCount,
    this.isFavorite = false,
  });

  VendorSearchModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        businessName = json['business_name'] as String?,
        address = json['address'] as String?,
        latitude = (json['latitude'] as num?)?.toDouble(),
        longitude = (json['longitude'] as num?)?.toDouble(),
        shopPhotoUrl = json['shop_photo_url'] as String?,
        ratingAvg = (json['rating_avg'] as num?)?.toDouble(),
        ratingCount = json['rating_count'] as int?,
        isFavorite = json['is_favorite'] as bool? ?? false;
}

/// `GET /api/vendors/search`'s `data` envelope — the zone the search
/// actually resolved to (task 4.6's ZoneMatcher, server-side) plus the
/// page of matching vendors. `meta` (pagination) lives on `CommonResponse`
/// as a sibling, not here.
class VendorSearchResultModel {
  ResolvedZoneModel? zone;
  List<VendorSearchModel> vendors;

  VendorSearchResultModel({this.zone, List<VendorSearchModel>? vendors}) : vendors = vendors ?? [];

  VendorSearchResultModel.fromJson(Map<String, dynamic> json)
      : zone = json['zone'] is Map<String, dynamic>
            ? ResolvedZoneModel.fromJson(json['zone'] as Map<String, dynamic>)
            : null,
        vendors = ((json['vendors'] as List<dynamic>?) ?? [])
            .map((e) => VendorSearchModel.fromJson(e as Map<String, dynamic>))
            .toList();
}
