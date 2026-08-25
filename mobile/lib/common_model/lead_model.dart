/// One lead on the vendor Leads tab (SPEC section 3 item 7, task 4.8) —
/// a customer who tapped Call or WhatsApp.
class LeadModel {
  int? id;
  String? customerName;
  String? subcategoryName;
  String? zoneName;
  String? channel; // 'call' | 'whatsapp'
  String? createdAt;
  String? reviewRequestedAt;
  bool hasReview;

  LeadModel({
    this.id,
    this.customerName,
    this.subcategoryName,
    this.zoneName,
    this.channel,
    this.createdAt,
    this.reviewRequestedAt,
    this.hasReview = false,
  });

  LeadModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        customerName = json['customer_name'] as String?,
        subcategoryName = json['subcategory_name'] as String?,
        zoneName = json['zone_name'] as String?,
        channel = json['channel'] as String?,
        createdAt = json['created_at'] as String?,
        reviewRequestedAt = json['review_requested_at'] as String?,
        hasReview = json['has_review'] as bool? ?? false;
}
