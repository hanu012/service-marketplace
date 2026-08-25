<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Http\Responses\ApiResponse;
use App\Models\Category;
use Illuminate\Http\JsonResponse;

class CategoryController extends Controller
{
    /**
     * The full active category tree, consumed by all three apps.
     *
     * DELIBERATELY NOT PAGINATED, against CLAUDE.md's "paginate every list
     * endpoint" rule. This is cache-on-launch master data, not a feed: the
     * customer app draws its browse grid from the whole tree, and the vendor
     * and salesman apps need all of it to render subscription selection with
     * a live "X of Y selected" counter. Paging would mean several round trips
     * before the first screen could draw, and nesting subcategories inside a
     * paginated parent list makes the meta block ambiguous.
     *
     * Public: no token required. Customers browse before signing in.
     */
    public function index(): JsonResponse
    {
        $categories = Category::query()
            ->active()
            ->with([
                'subcategories' => fn ($query) => $query
                    ->active()
                    ->orderBy('sort_order')
                    ->orderBy('name'),
            ])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        return ApiResponse::success(CategoryResource::collection($categories));
    }
}
