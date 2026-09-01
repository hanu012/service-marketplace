<?php

namespace App\Filament\Resources;

use App\Enums\Permission;
use App\Enums\UserRole;
use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Fieldset;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Resources\Resource;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
use Illuminate\Auth\Events\Verified;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\SoftDeletingScope;
use Illuminate\Support\Facades\Auth;

/**
 * User management for all four roles (SPEC section 5.2).
 *
 * THIS IS THE ADMIN-CREATES-DIRECTLY PATH, and is deliberately not bound by
 * the self-registration restriction. SPEC section 1 forbids salesmen from
 * signing themselves up, which is enforced on the API by RegisterRequest
 * limiting `role` to vendor|customer. That rule governs public registration.
 * An admin working in this panel may create any of the four roles — which is
 * exactly what section 5.2 asks for. Both rules are pinned by tests so
 * neither drifts into the other.
 *
 * Accounts created here are marked email-verified at creation: the admin
 * vouches for them, so there is no address to confirm. That is the behaviour
 * User::requiresEmailVerification() already documents.
 */
class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationGroup = 'People';

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Section::make('Account')
                ->columns(2)
                ->schema([
                    TextInput::make('name')
                        ->required()
                        ->maxLength(255),

                    TextInput::make('email')
                        ->email()
                        ->required()
                        ->maxLength(255)
                        // Deliberately NOT scoped withoutTrashed(): the unique
                        // index on users.email covers trashed rows too, so
                        // exempting them here would let validation pass and
                        // then fail at the database. A genuinely released
                        // address does not collide anyway — deletion
                        // tombstones the row, so the original is no longer
                        // held by anything. Same reasoning as RegisterRequest.
                        ->unique(ignoreRecord: true)
                        ->helperText('Becomes the login. Must be reachable — password resets go here.'),

                    Select::make('role')
                        ->options(collect(UserRole::cases())->mapWithKeys(
                            fn (UserRole $role) => [$role->value => ucfirst($role->value)]
                        ))
                        ->required()
                        ->live()
                        // Fixed after creation: changing it would strand the
                        // profile row and anything hanging off it, and there
                        // is no sane migration from vendor to customer.
                        ->disabled(fn (string $operation): bool => $operation !== 'create')
                        // Dehydrated ONLY on create. A bare ->dehydrated()
                        // overrides Filament's default of excluding disabled
                        // fields from the save, which made `disabled` purely
                        // cosmetic on edit: a crafted Livewire submission
                        // could still set role, and a customer could be
                        // promoted to admin — bypassing UserPolicy::create(),
                        // which restricts making admins to super-admins.
                        // Verified exploitable before this fix.
                        //
                        // Same round-trip hole as the permissions field, which
                        // is why that one uses visible() rather than
                        // disabled(). See CLAUDE.md's Filament conventions.
                        ->dehydrated(fn (string $operation): bool => $operation === 'create')
                        ->helperText(fn (string $operation): string => $operation === 'create'
                            ? 'Cannot be changed later — the profile below depends on it.'
                            : 'Role cannot be changed after creation.'),

                    // SPEC section 5.16: sub-admins scoped to specific modules.
                    //
                    // visible(), not disabled(): a disabled field still
                    // round-trips through the request, and Filament would
                    // save a value injected into the payload. Hiding it keeps
                    // it out of the schema entirely for anyone who is not a
                    // super-admin — which is the whole escalation guard.
                    CheckboxList::make('permissions')
                        ->options(collect(Permission::grouped())
                            ->flatMap(fn (array $abilities) => $abilities)
                            ->all())
                        ->descriptions(collect(Permission::cases())
                            ->mapWithKeys(fn (Permission $p) => [$p->value => $p->value])
                            ->all())
                        ->columns(2)
                        ->columnSpanFull()
                        ->visible(fn (): bool => Auth::user()?->isSuperAdmin() ?? false)
                        ->helperText(
                            'Only applies to admins. Leave empty for no access — permissions '
                            .'fail closed. A super-admin is stored as the single wildcard "*" '
                            .'and is not settable here; grant that in the database deliberately.'
                        )
                        ->hidden(fn (Get $get): bool => $get('role') !== UserRole::Admin->value),
                ]),

            // Each profile fieldset is bound with a condition, so switching
            // role on create writes only the matching row. Filament deletes
            // the related record when the condition is false, which stops an
            // orphan profile surviving a role change.
            Fieldset::make('Salesman profile')
                ->relationship('salesman', condition: fn (Get $get): bool => $get('role') === UserRole::Salesman->value)
                ->visible(fn (Get $get): bool => $get('role') === UserRole::Salesman->value)
                ->columns(2)
                ->schema([
                    TextInput::make('employee_code')
                        ->required()
                        ->maxLength(255)
                        ->unique(table: 'salesmen', ignoreRecord: true),

                    TextInput::make('phone')
                        ->tel()
                        ->required()
                        ->maxLength(20)
                        ->unique(table: 'salesmen', ignoreRecord: true),

                    TextInput::make('monthly_target_paise')
                        ->label('Monthly target (paise)')
                        ->numeric()
                        ->default(0)
                        ->helperText('Integer paise. 100000 = ₹1,000.'),

                    TextInput::make('commission_rate_bps')
                        ->label('Commission rate (basis points)')
                        ->numeric()
                        ->default(0)
                        ->helperText('1200 = 12.00%. Integer, so rates never drift.'),

                    Toggle::make('is_active')->default(true),
                ]),

            Fieldset::make('Vendor profile')
                ->relationship('vendor', condition: fn (Get $get): bool => $get('role') === UserRole::Vendor->value)
                ->visible(fn (Get $get): bool => $get('role') === UserRole::Vendor->value)
                ->columns(2)
                ->schema([
                    TextInput::make('business_name')->required()->maxLength(255),
                    TextInput::make('owner_name')->required()->maxLength(255),

                    TextInput::make('phone')
                        ->tel()
                        ->required()
                        ->maxLength(20)
                        // SPEC section 2.2 rejects a duplicate vendor phone
                        // before anything else is saved. It is also the number
                        // behind the customer Call button.
                        ->unique(table: 'vendors', ignoreRecord: true),

                    Select::make('status')
                        ->options([
                            'draft' => 'Draft',
                            'pending_payment' => 'Pending payment',
                            'active' => 'Active',
                            'grace' => 'Grace',
                            'expired' => 'Expired',
                        ])
                        // Draft: an admin-created vendor has no subscription
                        // yet, the same position the salesman flow is in
                        // before payment. pending_verification is absent by
                        // design — SPEC section 7 reserves it for
                        // self-registered vendors.
                        ->default('draft')
                        ->required(),

                    TextInput::make('address')->maxLength(255)->columnSpanFull(),

                    TextInput::make('latitude')->numeric()->step('0.0000001'),
                    TextInput::make('longitude')->numeric()->step('0.0000001'),

                    Toggle::make('is_suspended')
                        ->helperText('Policy violations. Independent of subscription dates.'),
                ]),

            Fieldset::make('Customer profile')
                ->relationship('customer', condition: fn (Get $get): bool => $get('role') === UserRole::Customer->value)
                ->visible(fn (Get $get): bool => $get('role') === UserRole::Customer->value)
                ->columns(2)
                ->schema([
                    TextInput::make('phone')->tel()->maxLength(20),
                    TextInput::make('pincode')->maxLength(10),
                    TextInput::make('latitude')->numeric()->step('0.0000001'),
                    TextInput::make('longitude')->numeric()->step('0.0000001'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('name')->searchable()->sortable(),

                TextColumn::make('email')
                    ->searchable()
                    ->copyable()
                    // A tombstoned address is bookkeeping, not something to
                    // read as a contact.
                    ->formatStateUsing(fn (User $record): string => $record->isTombstoned()
                        ? '(deleted account)'
                        : $record->email)
                    ->description(fn (User $record): ?string => $record->isTombstoned()
                        ? 'was '.$record->original_email
                        : null),

                TextColumn::make('role')
                    ->badge()
                    ->sortable()
                    ->formatStateUsing(fn (UserRole $state): string => ucfirst($state->value))
                    ->color(fn (UserRole $state): string => match ($state) {
                        UserRole::Admin => 'danger',
                        UserRole::Salesman => 'warning',
                        UserRole::Vendor => 'info',
                        UserRole::Customer => 'gray',
                    }),

                IconColumn::make('email_verified_at')
                    ->label('Verified')
                    ->boolean()
                    ->getStateUsing(fn (User $record): bool => $record->hasVerifiedEmail()),

                TextColumn::make('created_at')
                    ->dateTime('d M Y')
                    ->sortable()
                    ->toggleable(),

                TextColumn::make('deleted_at')
                    ->label('Deleted')
                    ->dateTime('d M Y')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('role')
                    ->options(collect(UserRole::cases())->mapWithKeys(
                        fn (UserRole $role) => [$role->value => ucfirst($role->value)]
                    )),

                TrashedFilter::make(),
            ])
            ->actions([
                \Filament\Tables\Actions\EditAction::make(),

                // Manual stand-in for the emailed verification link — used
                // while bypass_email_verification is on (Settings page) or
                // any time an admin needs to unblock a stuck self-signup.
                \Filament\Tables\Actions\Action::make('verifyEmail')
                    ->label('Verify email')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (User $record): bool => ! $record->hasVerifiedEmail())
                    ->action(function (User $record): void {
                        if ($record->markEmailAsVerified()) {
                            event(new Verified($record));
                        }
                    }),
            ])
            ->bulkActions([
                // No bulk delete: each deletion rewrites an email address and
                // revokes tokens, which is not something to do to a checkbox
                // selection by accident.
                \Filament\Tables\Actions\BulkAction::make('verifyEmail')
                    ->label('Verify email')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->deselectRecordsAfterCompletion()
                    ->action(function (Collection $records): void {
                        foreach ($records as $record) {
                            if ($record->markEmailAsVerified()) {
                                event(new Verified($record));
                            }
                        }
                    }),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->withoutGlobalScopes([SoftDeletingScope::class]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
