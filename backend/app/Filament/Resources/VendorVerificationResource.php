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

    /**
     * Hidden from the sidebar: approve/reject now live on the Vendor tab
     * of the owning user's page, where the KYC documents being judged are
     * already on screen. The resource stays registered so its pages,
     * policy and tests continue to back that tab.
     */
    public static function shouldRegisterNavigation(): bool
    {
        return false;
    }

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
                    // This is the screen the approve/reject decision is made
                    // on, so both documents are shown as images and both
                    // click through to the full-size original — the
                    // thumbnail is not big enough to check an ID against a
                    // business name.
                    ImageEntry::make('shop_photo_path')
                        ->label('Shop photo')
                        ->getStateUsing(fn (Vendor $record): ?string => $record->fileUrl())
                        ->url(fn (Vendor $record): ?string => $record->fileUrl())
                        ->openUrlInNewTab()
                        ->tooltip('Open full size')
                        ->placeholder('Not provided'),

                    // Previously a text link reading just "Aadhaar", on the
                    // grounds that an ID proof might be a PDF. It cannot be:
                    // StoreKycRequest validates `id_proof` as
                    // `image|mimes:jpg,jpeg,png,webp`, the same rule the
                    // shop photo gets. Showing the document inline is the
                    // difference between reviewing it and taking its word.
                    ImageEntry::make('id_proof_path')
                        ->label('ID proof')
                        ->getStateUsing(fn (Vendor $record): ?string => $record->fileUrl($record->id_proof_path))
                        ->url(fn (Vendor $record): ?string => $record->fileUrl($record->id_proof_path))
                        ->openUrlInNewTab()
                        ->tooltip('Open full size')
                        ->placeholder('Not provided'),

                    TextEntry::make('id_proof_type')
                        ->label('ID proof type')
                        ->badge()
                        ->formatStateUsing(fn (?string $state): string => $state === null
                            ? 'Not provided'
                            : ucfirst($state))
                        ->placeholder('Not provided'),
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
