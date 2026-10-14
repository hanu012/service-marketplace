<?php

namespace App\Filament\Resources\PasswordResetRequestResource\Pages;

use App\Filament\Resources\PasswordResetRequestResource;
use App\Models\PasswordResetRequest;
use Filament\Resources\Components\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;

class ListPasswordResetRequests extends ListRecords
{
    protected static string $resource = PasswordResetRequestResource::class;

    public function getSubheading(): ?string
    {
        return 'People who tapped "Forgot password?" in an app. Reset password issues a temporary one, '
            .'shown once — share it by call or WhatsApp. They must choose their own when they sign in.';
    }

    public function getTabs(): array
    {
        return [
            'pending' => Tab::make('Pending')
                ->badge(PasswordResetRequest::query()->pending()->count())
                ->badgeColor('warning')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', PasswordResetRequest::STATUS_PENDING)),

            'resolved' => Tab::make('Resolved')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', PasswordResetRequest::STATUS_RESOLVED)),

            'all' => Tab::make('All')
                ->badge(PasswordResetRequest::query()->count()),
        ];
    }

    /** Open on the queue that needs action. */
    public function getDefaultActiveTab(): string|int|null
    {
        return 'pending';
    }
}
