<?php

use App\Http\Controllers\Admin\PlaceLookupController;
use App\Http\Controllers\PageController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Public CMS pages (SPEC section 5 item 13) — the actual browsable
// page app store reviewers/users need, not a JSON API response.
// Registered before /pages/{slug} so "index" is never matched as a
// slug by the wildcard route below.
Route::get('/pages', [PageController::class, 'index'])->name('pages.index');
Route::get('/pages/{slug}', [PageController::class, 'show'])->name('pages.show');

// Google Places lookup for the admin zone map's search box.
//
// Admin-only and behind the same role check the panel itself uses:
// without that this is an open, unmetered geocoding service running on
// our Google bill. The key stays server-side — see PlaceLookupController.
Route::middleware(['auth', 'role:admin'])
    ->prefix('admin/places')
    ->name('admin.places.')
    ->group(function () {
        Route::get('/autocomplete', [PlaceLookupController::class, 'autocomplete'])
            ->name('autocomplete');

        Route::get('/details', [PlaceLookupController::class, 'details'])
            ->name('details');
    });
