<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\ResolvesOptionalAuthUser;
use App\Http\Controllers\Controller;
use App\Http\Requests\Vendor\VendorSearchRequest;
use App\Http\Resources\VendorSearchResource;
use App\Models\Zone;
use App\Services\VendorSearchService;
use Illuminate\Http\JsonResponse;

/**
 * Public customer vendor search (SPEC section 4 item 4, task 5.3) — the
 * screen CustomerSubcategoriesController.selectSubcategory() (task 5.1)
 * navigates into once a subcategory is tapped.
 */
class VendorSearchController extends Controller
{
    use ResolvesOptionalAuthUser;

    public function __construct(private readonly VendorSearchService $service)
    {
    }

    public function index(VendorSearchRequest $request): JsonResponse
    {
        // Optional: an unauthenticated search still works exactly as
        // before (task 5.3), this only adds is_favorite when a valid
        // customer token happens to be presented (favorites task).
        $this->resolveOptionalUser($request);

        $result = $this->service->search(
            subcategoryId: (int) $request->input('subcategory_id'),
            lat: $request->hasPoint() ? (float) $request->input('latitude') : null,
            lng: $request->hasPoint() ? (float) $request->input('longitude') : null,
            pincode: $request->filled('pincode') ? $request->string('pincode')->toString() : null,
            perPage: (int) $request->input('per_page', 15),
        );

        $zone = $result['zone'];
        $paginator = $result['paginator'];

        // No zone matched the given point/pincode — not an error, mirrors
        // CustomerController::updateLocation()'s same outcome. No `meta`
        // block: nothing was paginated.
        if ($zone === null || $paginator === null) {
            return response()->json([
                'success' => true,
                'data' => ['zone' => null, 'vendors' => []],
                'error' => null,
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'zone' => $this->zoneResource($zone),
                'vendors' => VendorSearchResource::collection($paginator->getCollection())->resolve(),
            ],
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
            ],
            'error' => null,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function zoneResource(Zone $zone): array
    {
        return ['id' => $zone->id, 'name' => $zone->name];
    }
}
