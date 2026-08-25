<?php

namespace App\Filament\Resources\ZoneResource\Pages;

use App\Filament\Resources\ZoneResource;
use App\Models\Zone;
use Filament\Resources\Pages\CreateRecord;

class CreateZone extends CreateRecord
{
    protected static string $resource = ZoneResource::class;

    /**
     * Swaps the map's {lat, lng} points for the geometry expression.
     *
     * `polygon` is a spatial column, so it cannot be assigned as a plain
     * value — it has to go through ST_GeomFromText. Zone::polygonExpression()
     * handles that, including the lat/lng to lng/lat swap WKT requires.
     */
    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $points = $data['polygon_points'] ?? [];
        unset($data['polygon_points']);

        $data['polygon'] = Zone::polygonExpression($points);

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
