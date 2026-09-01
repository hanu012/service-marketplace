<?php

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
