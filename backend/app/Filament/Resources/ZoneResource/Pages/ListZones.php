<?php

namespace App\Filament\Resources\ZoneResource\Pages;

use App\Filament\Resources\ZoneResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\HtmlString;

class ListZones extends ListRecords
{
    protected static string $resource = ZoneResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    /**
     * States both rules an admin will otherwise trip over: zones are
     * deactivated rather than deleted, and new zones start as drafts.
     */
    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'Zones are <strong>deactivated, not deleted</strong> — subscriptions record '
            .'the zones they cover, so removing one would leave vendors paying for an '
            .'area that no longer resolves. New zones start as <strong>drafts</strong>: '
            .'draw a rough boundary now, refine it, then switch <em>Active</em> on. '
            .'Only active zones are matched against customer locations.'
        );
    }
}
