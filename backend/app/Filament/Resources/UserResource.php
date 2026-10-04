<?php

namespace App\Filament\Resources;

use App\Enums\ApprovalStatus;
use App\Enums\Permission;
use App\Enums\UserRole;
use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use App\Models\Vendor;
use App\Services\VendorVerificationService;
use Filament\Forms\Components\Actions as FormActions;
use Filament\Forms\Components\Actions\Action as FormAction;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Fieldset;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TrashedFilter;
use Filament\Tables\Table;
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
 * Accounts created here are approved at creation: the admin filling in the
 * form is the vetting, so sending the account to the pending queue would
 * only ask them to approve their own work.
 *
 * This list is also where self-registered accounts are let in. Admin
 * approval is the single gate on an account (SPEC section 3.1) — there is
 * no email verification and the platform sends no mail at all, so the
 * Approve action here is the only thing that makes a signup usable.
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

                    TextInput::make('region')
                        ->label('Assigned region')
                        ->maxLength(255)
                        ->helperText('Free text, e.g. "Ahmedabad · Gujarat". Shown on the salesman\'s profile screen.'),

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

            static::vendorVerificationSection(),

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

    /**
     * Verification, on the Account tab beside the vendor fields it judges.
     *
     * This used to be a sidebar entry of its own ("Vendor Verification"),
     * then briefly a tab; both meant deciding on a vendor while their
     * details were on a different screen. The decision and the thing
     * being decided now sit together.
     *
     * Only rendered for a saved vendor user — on the create form there is
     * no vendor row to approve yet, and the role select can still change.
     *
     * Both actions go through VendorVerificationService, the same path
     * the API and the (still-registered) VendorVerificationResource use:
     * it moves the vendor's status AND the owning user's approval in one
     * transaction, so a second hand-rolled status write here would be the
     * thing that lets the two drift apart.
     */
    private static function vendorVerificationSection(): Section
    {
        return Section::make('Verification')
            // Keyed so the header actions are addressable — a Section has
            // no state path of its own for tests to reach them by.
            ->key('vendorVerification')
            ->description('Approve or reject this vendor. Approving also lets the account into the app.')
            // Keyed off the saved record alone, not the role select: only
            // a vendor has a vendor row, so the row's existence already
            // says everything the role check would, and it does not
            // depend on whether the select's live state is the enum or
            // its string value.
            ->visible(fn (?User $record): bool => $record?->vendor !== null)
            ->columns(2)
            ->schema([
                Placeholder::make('vendor_status')
                    ->label('Current status')
                    ->content(fn (?User $record): string => match ($record?->vendor?->status) {
                        'active' => 'Active — visible to customers',
                        'rejected' => 'Rejected',
                        'pending_verification' => 'Awaiting verification',
                        'pending_payment' => 'Awaiting payment',
                        'draft' => 'Draft — not submitted',
                        default => '—',
                    }),

                Placeholder::make('vendor_id_proof')
                    ->label('ID proof')
                    ->content(fn (?User $record): string => $record?->vendor?->id_proof_type === null
                        ? 'Not provided'
                        : ucfirst($record->vendor->id_proof_type)),

                Placeholder::make('vendor_rejection_reason')
                    ->label('Rejection reason')
                    ->columnSpanFull()
                    ->visible(fn (?User $record): bool => $record?->vendor?->status === 'rejected')
                    ->content(fn (?User $record): string => $record?->vendor?->rejection_reason ?? '—'),

                // No link out to the vendor page here: the KYC documents
                // and the plan/quota breakdown are the "More info" tab
                // beside this one, so the admin never leaves the user.

                // An Actions component rather than the Section's own
                // headerActions: header actions are not reachable through
                // Component::getAction(), so nothing could test them.
                FormActions::make([
                    FormAction::make('approveVendor')
                    ->label('Approve')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('Approve this vendor?')
                    ->modalDescription('The vendor becomes active and visible to customers immediately, and the account is let into the app.')
                    ->visible(fn (?User $record): bool => $record?->vendor !== null
                        && $record->vendor->status !== 'active'
                        && (Auth::user()?->can('verify', Vendor::class) ?? false))
                    ->action(function (?User $record) {
                        app(VendorVerificationService::class)->approve($record->vendor, Auth::user());

                        Notification::make()->title('Vendor approved')->success()->send();
                    }),

                FormAction::make('rejectVendor')
                    ->label('Reject')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->modalHeading('Reject this vendor?')
                    ->form([
                        Textarea::make('reason')
                            ->label('Rejection reason')
                            ->helperText('Shown to the vendor in the app.')
                            ->required()
                            ->maxLength(1000),
                    ])
                    ->visible(fn (?User $record): bool => $record?->vendor !== null
                        && $record->vendor->status !== 'rejected'
                        && (Auth::user()?->can('verify', Vendor::class) ?? false))
                    ->action(function (?User $record, array $data) {
                        app(VendorVerificationService::class)
                            ->reject($record->vendor, Auth::user(), $data['reason']);

                        Notification::make()->title('Vendor rejected')->danger()->send();
                    }),
                ])->key('vendorDecision')->columnSpanFull(),
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

                TextColumn::make('approval_status')
                    ->label('Approval')
                    ->badge()
                    ->sortable()
                    ->formatStateUsing(fn (ApprovalStatus $state): string => $state->label())
                    ->color(fn (ApprovalStatus $state): string => $state->color())
                    // The rejection reason is the first thing anyone asks
                    // about, so it is on the row rather than a click away.
                    ->description(fn (User $record): ?string => $record->isRejected()
                        ? $record->approval_note
                        : null),

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

                // Defaulted to Pending is tempting but wrong — an admin
                // opening Users to find a specific person would see an
                // empty table and think the account was gone. The pending
                // queue is surfaced by the navigation badge instead.
                SelectFilter::make('approval_status')
                    ->label('Approval')
                    ->options(collect(ApprovalStatus::cases())->mapWithKeys(
                        fn (ApprovalStatus $status) => [$status->value => $status->label()]
                    )),

                TrashedFilter::make(),
            ])
            ->actions([
                \Filament\Tables\Actions\EditAction::make(),

                // The approval gate (SPEC section 3.1). This is the only way
                // a self-registered account becomes usable — there is no
                // emailed verification link any more.
                \Filament\Tables\Actions\Action::make('approve')
                    ->label('Approve')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('Approve this account?')
                    ->modalDescription(
                        'They will be able to use the app immediately, on every '
                        .'device they are already signed in on.'
                    )
                    ->visible(fn (User $record): bool => ! $record->isApproved())
                    ->action(function (User $record): void {
                        $record->recordApprovalDecision(
                            ApprovalStatus::Approved,
                            auth()->user(),
                        );
                    }),

                // Rejection takes a reason because the app shows it to the
                // user — a rejection with no explanation generates a support
                // call that the admin then has to answer anyway.
                \Filament\Tables\Actions\Action::make('reject')
                    ->label('Reject')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (User $record): bool => ! $record->isRejected())
                    ->form([
                        Textarea::make('approval_note')
                            ->label('Reason')
                            ->helperText('Shown to the user in the app.')
                            ->required()
                            ->maxLength(500),
                    ])
                    ->action(function (User $record, array $data): void {
                        $record->recordApprovalDecision(
                            ApprovalStatus::Rejected,
                            auth()->user(),
                            $data['approval_note'],
                        );
                    }),

                // The whole recovery path for a forgotten password. There is
                // no emailed reset link — the platform sends no mail — so
                // without this an account locked out of its own password
                // would have to be deleted and recreated, releasing and
                // re-taking the email on the unique index.
                //
                // must_change_password is set so the admin-chosen value
                // cannot become the user's permanent password;
                // RequirePasswordChange then blocks the API until they pick
                // their own.
                \Filament\Tables\Actions\Action::make('resetPassword')
                    ->label('Reset password')
                    ->icon('heroicon-o-key')
                    ->color('gray')
                    ->requiresConfirmation()
                    ->modalHeading('Issue a new temporary password?')
                    ->modalDescription(
                        'Their current password stops working immediately. The new one '
                        .'is shown once, here, and cannot be recovered afterwards.'
                    )
                    ->modalSubmitActionLabel('Reset password')
                    ->visible(fn (User $record): bool => ! $record->isTombstoned())
                    ->action(function (User $record): void {
                        $temporary = User::generateTemporaryPassword();

                        // forceFill because password is hashed by the cast,
                        // and must_change_password is not fillable.
                        $record->forceFill([
                            'password' => $temporary,
                            'must_change_password' => true,
                        ])->save();

                        Notification::make()
                            ->title('Temporary password for '.$record->name)
                            ->body(
                                '**'.$temporary.'**'
                                ."\n\nShare it with them now — this is the only time "
                                .'it is shown.'
                            )
                            ->persistent()
                            ->success()
                            ->actions([
                                \Filament\Notifications\Actions\Action::make('copy')
                                    ->label('Copy password')
                                    ->color('gray')
                                    ->extraAttributes([
                                        'x-on:click' => 'window.navigator.clipboard.writeText('
                                            .json_encode($temporary).')',
                                    ]),
                            ])
                            ->send();
                    }),
            ])
            ->bulkActions([
                // Bulk approve only. There is no bulk reject on purpose:
                // rejecting requires a reason that is shown to the user, and
                // one reason pasted across a mixed selection is worse than
                // no reason at all.
                \Filament\Tables\Actions\BulkAction::make('approve')
                    ->label('Approve')
                    ->icon('heroicon-o-check-badge')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('Approve selected accounts?')
                    ->modalDescription(
                        'Each one will be able to use the app immediately. Accounts '
                        .'that are already approved are skipped.'
                    )
                    ->deselectRecordsAfterCompletion()
                    ->action(function (Collection $records): void {
                        $admin = auth()->user();

                        foreach ($records as $record) {
                            if ($record->isApproved()) {
                                continue;
                            }

                            $record->recordApprovalDecision(ApprovalStatus::Approved, $admin);
                        }
                    }),

                // Bulk delete, deliberately harder to trigger than the
                // per-row one on the Edit page: a checkbox selection is easy
                // to get wrong, and deleting a user releases their email for
                // reuse and force-signs them out everywhere. The type-to-
                // confirm field is on top of Filament's own confirmation
                // modal, not instead of it. UserPolicy::delete() is still
                // re-checked per record here — a custom BulkAction does not
                // auto-authorize the way DeleteBulkAction does — so admin
                // accounts (unless you're a super-admin) and your own
                // account are silently skipped rather than deleted.
                \Filament\Tables\Actions\BulkAction::make('deleteSelected')
                    ->label('Delete selected')
                    ->icon('heroicon-o-trash')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('Delete selected users?')
                    ->modalDescription(
                        'This releases each account\'s email/phone for reuse, force-signs '
                        .'them out on every device, and cannot be undone as a batch. Admin '
                        .'accounts and your own account are always skipped.'
                    )
                    ->modalSubmitActionLabel('Delete')
                    ->form([
                        TextInput::make('confirmation')
                            ->label('Type DELETE to confirm')
                            ->required()
                            ->rule('in:DELETE')
                            ->validationMessages(['in' => 'Type DELETE exactly, in capitals, to confirm.']),
                    ])
                    ->deselectRecordsAfterCompletion()
                    ->action(function (Collection $records): void {
                        $deleted = 0;
                        $skipped = 0;

                        foreach ($records as $record) {
                            if (Auth::user()?->can('delete', $record)) {
                                $record->delete();
                                $deleted++;
                            } else {
                                $skipped++;
                            }
                        }

                        Notification::make()
                            ->title($skipped > 0
                                ? "Deleted {$deleted}, skipped {$skipped} (admin/self accounts are never bulk-deleted)."
                                : "Deleted {$deleted} user(s).")
                            ->success()
                            ->send();
                    }),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->withoutGlobalScopes([SoftDeletingScope::class]);
    }

    /**
     * How many accounts are waiting on a decision.
     *
     * Signups are invisible otherwise — nothing else tells an admin someone
     * registered, now that no mail goes out and approval is the only way in
     * (SPEC section 3.1). A user left pending because nobody noticed cannot
     * use the product at all.
     *
     * Excludes soft-deleted rows, which getEloquentQuery() would otherwise
     * include here and inflate the count with accounts nobody can act on.
     */
    public static function getNavigationBadge(): ?string
    {
        $pending = static::getEloquentQuery()
            ->whereNull('deleted_at')
            ->where('approval_status', ApprovalStatus::Pending)
            ->count();

        return $pending > 0 ? (string) $pending : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'warning';
    }

    /**
     * The tabs on a user's page: Account, then Media.
     *
     * People used to list Vendors, Vendor Verification and Media
     * Moderation as separate sidebar entries, which split one subject —
     * a person, their vendor record, and the content they uploaded —
     * across three screens with nothing but an id to carry between them.
     *
     * The vendor record is NOT a tab of its own: its fields and its
     * verification both live in the Account tab, next to the account they
     * belong to (see the Vendor profile fieldset and
     * vendorVerificationSection). Only the uploads are separate, because
     * a moderation queue is a list of its own and does not belong inside
     * a form.
     *
     * The Media tab hides itself for non-vendor roles — an empty one on a
     * salesman reads as missing data rather than as not applicable.
     *
     * @return array<int, class-string>
     */
    public static function getRelations(): array
    {
        return [
            UserResource\RelationManagers\VendorDetailsRelationManager::class,
            UserResource\RelationManagers\PortfolioMediaRelationManager::class,
        ];
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
