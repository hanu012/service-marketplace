<?php

namespace App\Filament\Resources;

use App\Filament\Resources\VendorVerificationResource\Pages;
use App\Models\Vendor;
use App\Services\VendorVerificationService;
use Filament\Forms\Components\Textarea;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

/**
 * Vendor Verification Queue (SPEC section 5.8).
 *
 * A dedicated queue, not a general vendor management list — the base query
 * below is load-bearing, not a toggleable filter. General vendor CRUD
 * (SPEC section 5.2) doesn't exist yet and is separate scope.
 *
 * No Create page and no Delete action: vendors are never created or deleted
 * through this queue, only transitioned between pending_verification and
 * active/rejected. Same "the omission is the enforcement" shape
 * CategoryResource documents for master data, applied here because it's
 * simply outside this resource's job, not a SPEC-mandated restriction.
 */
class VendorVerificationResource extends Resource
{
    protected static ?string $model = Vendor::class;

    protected static ?string $navigationIcon = 'heroicon-o-shield-check';

    protected static ?string $navigationLabel = 'Vendor Verification';

    protected static ?string $modelLabel = 'vendor verification';

    protected static ?string $navigationGroup = 'People';

    protected static ?string $recordTitleAttribute = 'business_name';

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->pendingVerification();
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Section::make('Business details')
                ->columns(2)
                ->schema([
                    TextEntry::make('business_name'),
                    TextEntry::make('owner_name'),
                    TextEntry::make('phone'),
                    TextEntry::make('user.email')->label('Email'),
                    TextEntry::make('address')->columnSpanFull(),
                ]),

            Section::make('KYC documents')
                ->columns(2)
                ->schema([
                    ImageEntry::make('shop_photo_path')
                        ->label('Shop photo')
                        ->getStateUsing(fn (Vendor $record): ?string => $record->fileUrl())
                        ->placeholder('Not provided'),

                    TextEntry::make('id_proof_link')
                        ->label('ID proof')
                        // Not rendered as an image: an ID proof upload isn't
                        // guaranteed to be an image (could be a PDF), unlike
                        // the shop photo.
                        ->getStateUsing(fn (Vendor $record): string => $record->id_proof_type
                            ? ucfirst($record->id_proof_type)
                            : 'Not provided')
                        ->url(fn (Vendor $record): ?string => $record->id_proof_path
                            ? $record->fileUrl($record->id_proof_path)
                            : null)
                        ->openUrlInNewTab(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at')
            ->columns([
                TextColumn::make('business_name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('owner_name')
                    ->searchable(),

                TextColumn::make('phone')
                    ->searchable(),

                TextColumn::make('user.email')
                    ->label('Email')
                    ->searchable(),

                TextColumn::make('id_proof_type')
                    ->label('ID proof')
                    ->badge()
                    ->placeholder('Not provided'),

                TextColumn::make('created_at')
                    ->label('Submitted')
                    ->dateTime()
                    ->sortable(),
            ])
            ->actions([
                ViewAction::make(),
                static::approveAction(),
                static::rejectAction(),
            ])
            ->bulkActions([
                // No bulk approve/reject — each decision needs its own
                // look at the KYC docs.
            ])
            ->emptyStateHeading('Nothing to verify')
            ->emptyStateDescription('Self-registered vendors land here once they subscribe (SPEC section 3.2).');
    }

    public static function approveAction(): Action
    {
        return Action::make('approve')
            ->label('Approve')
            ->icon('heroicon-o-check-circle')
            ->color('success')
            ->visible(fn (): bool => Auth::user()?->can('verify', Vendor::class) ?? false)
            ->requiresConfirmation()
            ->modalHeading('Approve this vendor?')
            ->modalDescription('The vendor becomes active and visible to customers immediately.')
            ->action(function (Vendor $record) {
                app(VendorVerificationService::class)->approve($record, Auth::user());

                Notification::make()
                    ->title('Vendor approved')
                    ->success()
                    ->send();
            });
    }

    public static function rejectAction(): Action
    {
        return Action::make('reject')
            ->label('Reject')
            ->icon('heroicon-o-x-circle')
            ->color('danger')
            ->visible(fn (): bool => Auth::user()?->can('verify', Vendor::class) ?? false)
            ->modalHeading('Reject this vendor?')
            ->form([
                Textarea::make('reason')
                    ->label('Rejection reason')
                    ->required()
                    ->maxLength(1000),
            ])
            ->action(function (Vendor $record, array $data) {
                app(VendorVerificationService::class)->reject($record, Auth::user(), $data['reason']);

                Notification::make()
                    ->title('Vendor rejected')
                    ->danger()
                    ->send();
            });
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListVendorVerifications::route('/'),
            'view' => Pages\ViewVendorVerification::route('/{record}'),
        ];
    }
}
