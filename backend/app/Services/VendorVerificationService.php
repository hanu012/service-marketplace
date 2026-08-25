<?php

namespace App\Services;

use App\Models\User;
use App\Models\Vendor;

/**
 * Approve/Reject transitions for the vendor verification queue (SPEC
 * section 5.8) — pulled out of the Filament actions so the state transition
 * lives in one place regardless of which Action class triggers it (table
 * row vs page header).
 */
class VendorVerificationService
{
    public function __construct(private PushNotificationService $pushNotifications)
    {
    }

    public function approve(Vendor $vendor, User $admin): void
    {
        $vendor->update([
            'status' => 'active',
            'verified_at' => now(),
            'verified_by' => $admin->id,
            'rejection_reason' => null,
        ]);

        $this->pushNotifications->notifyVendorApproved($vendor);
    }

    public function reject(Vendor $vendor, User $admin, string $reason): void
    {
        $vendor->update([
            'status' => 'rejected',
            'verified_at' => now(),
            'verified_by' => $admin->id,
            'rejection_reason' => $reason,
        ]);

        $this->pushNotifications->notifyVendorRejected($vendor, $reason);
    }
}
