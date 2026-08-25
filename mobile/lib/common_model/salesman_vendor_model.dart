/// A vendor row on the salesman's My Vendors tab (`GET /api/salesmen/me/vendors`,
/// SPEC section 2.3).
///
/// `planName`/`daysToExpiry` are both nullable — a vendor still in Draft has
/// no subscription at all. `daysToExpiry` can be negative: the backend
/// deliberately does not filter to active-only, so an expired vendor still
/// shows its last plan with a negative value rather than going blank.
///
/// No leads field — Phase 5's leads table doesn't exist yet, and the backend
/// omits the column entirely rather than sending a fake zero.
class SalesmanVendorModel {
  int? id;
  String? businessName;
  String? status;
  String? planName;
  int? daysToExpiry;

  SalesmanVendorModel({
    this.id,
    this.businessName,
    this.status,
    this.planName,
    this.daysToExpiry,
  });

  SalesmanVendorModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        businessName = json['business_name'] as String?,
        status = json['status'] as String?,
        planName = json['plan_name'] as String?,
        daysToExpiry = json['days_to_expiry'] as int?;
}
