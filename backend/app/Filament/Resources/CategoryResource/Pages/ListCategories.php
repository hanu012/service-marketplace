<?php

namespace App\Filament\Resources\CategoryResource\Pages;

use App\Filament\Resources\CategoryResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\HtmlString;

class ListCategories extends ListRecords
{
    protected static string $resource = CategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    /**
     * States the no-delete rule where an admin would otherwise go looking for
     * the missing button, and gives the reason rather than just the rule.
     */
    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'Categories are <strong>deactivated, not deleted</strong>. '
            .'Subscriptions record the categories they bought, so removing one '
            .'would leave vendors paying for a service that no longer resolves. '
            .'Switch <em>Active</em> off to hide a category from the apps — '
            .'existing subscriptions keep working.'
        );
    }
}
