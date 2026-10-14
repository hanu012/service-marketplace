/// One review from a vendor's detail page (SPEC section 9, task 5.5) —
/// always visible-only, since the backend already filters out anything
/// an admin has hidden before this ever reaches the app.
class ReviewModel {
  int? id;
  int? rating;
  String? comment;
  String? customerName;
  String? vendorReply;
  String? repliedAt;
  String? createdAt;

  ReviewModel({
    this.id,
    this.rating,
    this.comment,
    this.customerName,
    this.vendorReply,
    this.repliedAt,
    this.createdAt,
  });

  ReviewModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        rating = json['rating'] as int?,
        comment = json['comment'] as String?,
        customerName = json['customer_name'] as String?,
        vendorReply = json['vendor_reply'] as String?,
        repliedAt = json['replied_at'] as String?,
        createdAt = json['created_at'] as String?;
}
