<?php

namespace App\Filament\Resources;

use App\Enums\UserRole;
use App\Filament\Resources\PasswordResetRequestResource\Pages;
use App\Models\PasswordResetRequest;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action as TableAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

/**
 * "Forgot password?" requests from the three apps.
 *
 * The platform sends no email, so this is how a locked-out user reaches an
 * admin: the app files a request, it lands here, and "Reset password" issues
 * the same temporary password the Users list does — shown once, to be
 * shared by call or WhatsApp. The user then must set their own on sign-in.
 *
 * Read-only apart from the two actions: requests are created only by the
 * API, never by hand.
 */
class PasswordResetRequestResource extends Resource
{
    protected static ?string $model = PasswordResetRequest::class;

    protected static ?string $navigationIcon = 'heroicon-o-key';

    protected static ?string $navigationGroup = 'People';

    protected static ?string $navigationLabel = 'Reset requests';

    protected static ?string $modelLabel = 'password reset request';

    protected static ?int $navigationSort = 2;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('user.name')
                    ->label('User')
                    ->weight('bold')
                    ->searchable()
                    ->description(fn (PasswordResetRequest $record): ?string => $record->user?->email)
                    ->placeholder('(deleted account)'),

                TextColumn::make('user.role')
                    ->label('App')
                    ->badge()
                    ->formatStateUsing(fn (?UserRole $state): string => match ($state) {
                        UserRole::Salesman => 'Salesman',
                        UserRole::Vendor => 'Vendor',
                        UserRole::Customer => 'Customer',
                        UserRole::Admin => 'Admin',
                        default => '—',
                    }),

                TextColumn::make('phone')
                    ->label('Phone')
                    ->state(fn (PasswordResetRequest $record): ?string => $record->user
                        ? UserResource::profilePhone($record->user)
                        : null)
                    ->copyable()
                    ->placeholder('—'),

                TextColumn::make('created_at')
                    ->label('Requested')
                    ->dateTime('d M Y, H:i')
                    ->description(fn (PasswordResetRequest $record): string => $record->created_at->diffForHumans())
                    ->sortable(),

                TextColumn::make('status')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state))
                    ->color(fn (string $state): string => match ($state) {
                        PasswordResetRequest::STATUS_PENDING => 'warning',
                        PasswordResetRequest::STATUS_RESOLVED => 'success',
                        default => 'gray',
                    }),

                TextColumn::make('resolvedBy.name')
                    ->label('Handled by')
                    ->description(fn (PasswordResetRequest $record): ?string => $record->resolved_at?->format('d M Y, H:i'))
                    ->placeholder('—')
                    ->toggleable(),
            ])
            ->actions([
                TableAction::make('resetPassword')
                    ->label('Reset password')
                    ->icon('heroicon-o-key')
                    ->color('primary')
                    ->requiresConfirmation()
                    ->modalHeading('Issue a new temporary password?')
                    ->modalDescription(
                        'Their current password stops working immediately. The new one is shown '
                        .'once, here — share it by call or WhatsApp. They must set their own when they sign in.'
                    )
                    ->modalSubmitActionLabel('Reset password')
                    ->visible(fn (PasswordResetRequest $record): bool => $record->isPending() && $record->user !== null)
                    ->authorize(fn (PasswordResetRequest $record): bool => Auth::user()?->can('update', $record) ?? false)
                    ->action(function (PasswordResetRequest $record): void {
                        $temporary = $record->user->issueTemporaryPassword(Auth::user());

                        UserResource::sendTemporaryPasswordNotification(
                            $record->user,
                            $temporary,
                            'Share it with them now — this is the only time it is shown.',
                        );
                    }),

                TableAction::make('dismiss')
                    ->label('Dismiss')
                    ->icon('heroicon-o-x-mark')
                    ->color('gray')
                    ->requiresConfirmation()
                    ->modalHeading('Dismiss this request?')
                    ->modalDescription('No password is changed. Use this for duplicates or requests you have already handled another way.')
                    ->visible(fn (PasswordResetRequest $record): bool => $record->isPending())
                    ->authorize(fn (PasswordResetRequest $record): bool => Auth::user()?->can('update', $record) ?? false)
                    ->action(fn (PasswordResetRequest $record) => $record->dismiss(Auth::user())),
            ])
            ->bulkActions([])
            ->emptyStateHeading('No reset requests')
            ->emptyStateDescription('When someone taps "Forgot password?" in an app, their request appears here.');
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user.salesman', 'user.vendor', 'user.customer', 'resolvedBy']);
    }

    public static function getNavigationBadge(): ?string
    {
        $pending = PasswordResetRequest::query()->pending()->count();

        return $pending > 0 ? (string) $pending : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPasswordResetRequests::route('/'),
        ];
    }
}
