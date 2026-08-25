<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\CreateLeadRequest;
use App\Http\Responses\ApiResponse;
use App\Models\Lead;
use Illuminate\Http\JsonResponse;

/**
 * SPEC section 4 item 7, task 5.4 — the write the vendor-detail screen's
 * Call/WhatsApp buttons must complete and confirm BEFORE opening the
 * dialer/WhatsApp intent. See Lead's own docblock for why this table is
 * load-bearing well beyond this one screen.
 */
class LeadController extends Controller
{
    public function store(CreateLeadRequest $request): JsonResponse
    {
        $customer = $request->user()->customer;

        if ($customer === null) {
            return ApiResponse::error('NOT_FOUND', 'No customer profile exists for this account.', 404);
        }

        $lead = Lead::create([
            'customer_id' => $customer->id,
            'vendor_id' => $request->integer('vendor_id'),
            'subcategory_id' => $request->integer('subcategory_id'),
            'zone_id' => $request->filled('zone_id') ? $request->integer('zone_id') : null,
            'channel' => $request->string('channel')->toString(),
        ]);

        return ApiResponse::success([
            'id' => $lead->id,
            'created_at' => $lead->created_at?->toIso8601String(),
        ], 201);
    }
}
