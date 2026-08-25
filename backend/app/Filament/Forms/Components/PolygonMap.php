<?php

namespace App\Filament\Forms\Components;

use Filament\Forms\Components\Field;

/**
 * Leaflet + Leaflet.draw polygon editor.
 *
 * State is an array of `['lat' => float, 'lng' => float]` points — explicit
 * keys rather than bare pairs, so the lat/lng order cannot be transposed on
 * the way to Zone::polygonExpression(). See the coordinate-order note there.
 *
 * The ring is stored open (no repeated closing point); closing is WKT's
 * concern and happens in the model.
 */
class PolygonMap extends Field
{
    protected string $view = 'filament.forms.components.polygon-map';

    protected int|\Closure|null $height = null;

    public function height(int|\Closure $height): static
    {
        $this->height = $height;

        return $this;
    }

    public function getHeight(): int
    {
        return $this->evaluate($this->height) ?? 420;
    }

    public function getTileUrl(): string
    {
        return (string) config('map.tile_url');
    }

    public function getTileAttribution(): string
    {
        return (string) config('map.tile_attribution');
    }

    public function getMaxZoom(): int
    {
        return (int) config('map.max_zoom', 19);
    }

    /**
     * Where the map opens when there is nothing drawn yet.
     *
     * Named getMapCenter, not getDefaultView: Filament's ViewComponent already
     * declares getDefaultView(): ?string for the Blade view name, and
     * overriding it with a different return type is a fatal error.
     *
     * @return array{lat: float, lng: float, zoom: int}
     */
    public function getMapCenter(): array
    {
        return [
            'lat' => (float) config('map.default_latitude'),
            'lng' => (float) config('map.default_longitude'),
            'zoom' => (int) config('map.default_zoom'),
        ];
    }
}
