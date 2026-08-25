import 'review_model.dart';

/// `GET /api/vendors/{vendor}/detail` (SPEC section 4 item 6, task 5.4).
class VendorDetailModel {
  int? id;
  String? businessName;
  String? address;
  double? latitude;
  double? longitude;
  String? phone;
  String? shopPhotoUrl;
  double? ratingAvg;
  int? ratingCount;
  double? distanceKm;
  List<VendorServiceModel> services;
  List<VendorDetailMediaModel> media;
  List<ReviewModel> reviews;

  /// Task: favorites/share/report/account deletion. Not nullable —
  /// the backend always includes it, defaulting `false` for a guest.
  bool isFavorite;

  VendorDetailModel({
    this.id,
    this.businessName,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.shopPhotoUrl,
    this.ratingAvg,
    this.ratingCount,
    this.distanceKm,
    List<VendorServiceModel>? services,
    List<VendorDetailMediaModel>? media,
    List<ReviewModel>? reviews,
    this.isFavorite = false,
  })  : services = services ?? [],
        media = media ?? [],
        reviews = reviews ?? [];

  VendorDetailModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        businessName = json['business_name'] as String?,
        address = json['address'] as String?,
        latitude = (json['latitude'] as num?)?.toDouble(),
        longitude = (json['longitude'] as num?)?.toDouble(),
        phone = json['phone'] as String?,
        shopPhotoUrl = json['shop_photo_url'] as String?,
        ratingAvg = (json['rating_avg'] as num?)?.toDouble(),
        ratingCount = json['rating_count'] as int?,
        // Backend serializes a whole-number Haversine result (e.g. 1.0)
        // as a bare JSON integer, not a float — parse via num either way.
        distanceKm = (json['distance_km'] as num?)?.toDouble(),
        services = ((json['services'] as List<dynamic>?) ?? [])
            .map((e) => VendorServiceModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        media = ((json['media'] as List<dynamic>?) ?? [])
            .map((e) => VendorDetailMediaModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        reviews = ((json['reviews'] as List<dynamic>?) ?? [])
            .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        isFavorite = json['is_favorite'] as bool? ?? false;
}

class VendorServiceModel {
  int? subcategoryId;
  String? name;
  int? categoryId;
  String? categoryName;

  VendorServiceModel({this.subcategoryId, this.name, this.categoryId, this.categoryName});

  VendorServiceModel.fromJson(Map<String, dynamic> json)
      : subcategoryId = json['subcategory_id'] as int?,
        name = json['name'] as String?,
        categoryId = json['category_id'] as int?,
        categoryName = json['category_name'] as String?;
}

/// Approved-only — the detail endpoint never returns pending/rejected
/// rows, so unlike PortfolioMediaModel (the vendor's own view of its
/// uploads) there's no moderation_status/rejection_reason to carry.
class VendorDetailMediaModel {
  int? id;
  String? type; // 'image' | 'video'
  String? url;
  String? createdAt;

  VendorDetailMediaModel({this.id, this.type, this.url, this.createdAt});

  VendorDetailMediaModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        type = json['type'] as String?,
        url = json['url'] as String?,
        createdAt = json['created_at'] as String?;
}
