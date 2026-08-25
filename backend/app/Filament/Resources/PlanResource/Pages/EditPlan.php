<?php

namespace App\Filament\Resources\PlanResource\Pages;

use App\Filament\Resources\PlanResource;
use App\Models\Plan;
use Filament\Resources\Pages\EditRecord;

class EditPlan extends EditRecord
{
    protected static string $resource = PlanResource::class;

    protected function getHeaderActions(): array
    {
        // No DeleteAction — subscriptions.plan_id is ON DELETE RESTRICT, so
        // the database refuses anyway. See PlanResource's docblock.
        return [];
    }

    /**
     * Same conversion as CreatePlan — see the note there.
     */
    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data['price_paise'] = Plan::rupeesToPaise($data['price_rupees'] ?? 0);
        unset($data['price_rupees']);

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
