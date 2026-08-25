<?php

namespace App\Filament\Resources\PlanResource\Pages;

use App\Filament\Resources\PlanResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\HtmlString;

class ListPlans extends ListRecords
{
    protected static string $resource = PlanResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'Plans are <strong>deactivated, not deleted</strong> — every subscription '
            .'records the plan it was sold on, so removing one would break the history '
            .'behind renewals, commissions and revenue reporting. Switch <em>Active</em> '
            .'off to stop offering a plan; subscriptions already on it keep running to '
            .'their expiry. <strong>Editing a price never changes what past customers '
            .'were charged</strong> — price and duration are copied onto each '
            .'subscription at purchase.'
        );
    }
}
