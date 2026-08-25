<?php

namespace App\Services;

use App\Models\Lead;
use App\Models\Vendor;

/**
 * Push notification seam for vendor verification outcomes (SPEC section 5.8)
 * and, since task 4.8, a vendor's "Request a review" action (SPEC section 3
 * item 8).
 *
 * No FCM calls here — CLAUDE.md: FCM isn't wired up until Phase 7. Every
 * method is a documented no-op for now; the `notifications` table
 * (`database/migrations/..._create_notifications_table.php`) already exists
 * and its own docblock names `verification_approved` as a worked example
 * trigger type — `review_request` is SPEC section 12's other named
 * automated trigger. When Phase 7 lands, each method gains a body that
 * writes a row there (`type` = 'verification_approved'/
 * 'verification_rejected'/'review_request', `target_app` =
 * 'vendor'/'customer') and hands off to the dispatcher — the call sites
 * don't need to change.
 */
class PushNotificationService
{
    public function notifyVendorApproved(Vendor $vendor): void
    {
        // Intentional no-op until Phase 7.
    }

    public function notifyVendorRejected(Vendor $vendor, string $reason): void
    {
        // Intentional no-op until Phase 7.
    }

    /**
     * Sent to the CUSTOMER on the lead, not the vendor — the vendor is
     * the one asking, the customer is the one who'd act on it.
     */
    public function notifyReviewRequested(Vendor $vendor, Lead $lead): void
    {
        // Intentional no-op until Phase 7.
    }
}
