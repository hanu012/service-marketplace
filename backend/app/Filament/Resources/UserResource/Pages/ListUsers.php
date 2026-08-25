<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\HtmlString;

class ListUsers extends ListRecords
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make()->label('New user'),
        ];
    }

    public function getSubheading(): ?HtmlString
    {
        return new HtmlString(
            'Creating a user generates a <strong>temporary password shown once</strong> — '
            .'copy it before dismissing the notification, because it cannot be recovered. '
            .'Accounts created here are marked email-verified, since you are vouching for them. '
            .'<strong>Deleting releases the email address</strong> so the person can sign up '
            .'again, signs out all their devices, and keeps their history; it can be undone '
            .'from the account page unless someone else has since taken the address.'
        );
    }
}
