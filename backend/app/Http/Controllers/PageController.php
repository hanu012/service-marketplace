<?php

namespace App\Http\Controllers;

use App\Models\CmsPage;
use Illuminate\Support\Str;
use Illuminate\View\View;

/**
 * Public CMS pages (SPEC section 5 item 13) — the actual web page an
 * app store reviewer or user can open in a browser. Deliberately NOT
 * under the Api namespace: this returns Blade/HTML, not JSON.
 */
class PageController extends Controller
{
    public function index(): View
    {
        $pages = CmsPage::published()->orderBy('title')->get();

        return view('pages.index', ['pages' => $pages]);
    }

    public function show(string $slug): View
    {
        $page = CmsPage::published()->where('slug', $slug)->firstOrFail();

        return view('pages.show', [
            'page' => $page,
            'html' => Str::markdown((string) $page->body),
        ]);
    }
}
