<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Responses\ApiResponse;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;

class SettingController extends Controller
{
    /**
     * A whitelisted subset of admin-editable settings (SPEC section 5.17),
     * for screens that need a live value rather than a hardcoded one — e.g.
     * the free-trial duration picker capped by free_trial_max_days.
     *
     * DELIBERATELY NOT the whole settings table: some rows are internal
     * (force_update_version, maintenance_mode gating) or simply not needed
     * by any client yet. Add a key here only when a screen actually reads
     * it, same reasoning as every other master-data endpoint in this file's
     * siblings.
     *
     * Public: no token required, matching /api/plans, /api/categories,
     * /api/zones.
     */
    public function index(): JsonResponse
    {
        return ApiResponse::success([
            'free_trial_max_days' => Setting::get('free_trial_max_days', 15),
        ]);
    }
}
