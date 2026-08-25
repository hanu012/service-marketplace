<?php

namespace App\Filament\Resources\ZoneResource\Pages;

use App\Filament\Resources\ZoneResource;
use App\Models\Zone;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\DB;

class EditZone extends EditRecord
{
    protected static string $resource = ZoneResource::class;

    protected function getHeaderActions(): array
    {
        // No DeleteAction — SPEC section 10.
        return [];
    }

    /**
     * Loads the stored boundary back into the map.
     *
     * Selecting `polygon` through Eloquent returns binary, so it is read as
     * WKT with ST_AsText and parsed back into {lat, lng} points.
     */
    protected function mutateFormDataBeforeFill(array $data): array
    {
        $wkt = DB::table('zones')
            ->selectRaw('ST_AsText(polygon) as wkt')
            ->where('id', $this->getRecord()->getKey())
            ->value('wkt');

        $data['polygon_points'] = Zone::pointsFromWkt($wkt);

        return $data;
    }

    /**
     * Same conversion as CreateZone — see the note there.
     */
    protected function mutateFormDataBeforeSave(array $data): array
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
