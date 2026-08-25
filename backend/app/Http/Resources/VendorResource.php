<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Vendor as the salesman app sees it while building a draft.
 *
 * `id` is the important field: the app stores it so a dropped connection
 * resumes the flow rather than restarting it (SPEC section 2.2).
 */
class VendorResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'business_name' => $this->business_name,
            'owner_name' => $this->owner_name,
            'phone' => $this->phone,
            'email' => $this->whenLoaded('user', fn () => $this->user->email),
            'address' => $this->address,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'status' => $this->status,

            // Resolved through the row's own disk, so files already moved to
            // R2 and files still local both return a working URL.
            'shop_photo_url' => $this->fileUrl($this->shop_photo_path),
            'id_proof_url' => $this->fileUrl($this->id_proof_path),
            'id_proof_type' => $this->id_proof_type,

            // Lets the app show which step still needs work when resuming.
            'has_kyc' => $this->shop_photo_path !== null && $this->id_proof_path !== null,

            // SPEC section 3.2: what GET /api/vendors/me's caller (task 4.2)
            // branches on — skip plan selection when this is true.
            'has_active_subscription' => $this->subscriptions()
                ->where('status', 'active')
                ->where('end_date', '>=', now())
                ->exists(),

            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
