<?php

namespace App\Providers\Filament;

use App\Http\Middleware\RolesMiddleware;
use Filament\Enums\ThemeMode;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\AuthenticateSession;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Pages;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Assets\Css;
use Filament\Support\Assets\Js;
use Filament\Support\Colors\Color;
use Filament\Support\Facades\FilamentAsset;
use Filament\Widgets;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    /**
     * Leaflet is vendored from node_modules rather than pulled from a CDN, so
     * no third-party script executes inside an authenticated admin session and
     * the panel keeps working without internet access for its own code. Only
     * the basemap tiles are remote — see config/map.php.
     *
     * Run `php artisan filament:assets` after `npm install` to publish these
     * into public/js/filament and public/css/filament.
     */
    public function boot(): void
    {
        FilamentAsset::register([
            Css::make('leaflet', base_path('node_modules/leaflet/dist/leaflet.css')),
            Css::make('leaflet-draw', base_path('node_modules/leaflet-draw/dist/leaflet.draw.css')),
            Js::make('leaflet', base_path('node_modules/leaflet/dist/leaflet.js')),
            Js::make('leaflet-draw', base_path('node_modules/leaflet-draw/dist/leaflet.draw.js')),
        ]);
    }

    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login()
            ->brandName('Service Marketplace')

            // Dark by default, per CLAUDE.md. Left switchable rather than
            // forced so an admin working in daylight is not stuck with it.
            ->defaultThemeMode(ThemeMode::Dark)

            // Single accent colour. Slate as the gray ramp keeps dark surfaces
            // at slate-900 (#0f172a) rather than pure black, and teal stays
            // clear of the red/amber that Filament reserves for destructive
            // and warning states.
            ->colors([
                'primary' => Color::Teal,
                'gray' => Color::Slate,
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->pages([
                Pages\Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\\Filament\\Widgets')
            ->widgets([
                Widgets\AccountWidget::class,
            ])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,

                // Belt and braces alongside User::canAccessPanel(). Filament
                // calls canAccessPanel() itself; this makes the role rule
                // explicit in the route stack too, using the same middleware
                // the API routes use.
                RolesMiddleware::class.':admin',
            ]);
    }
}
