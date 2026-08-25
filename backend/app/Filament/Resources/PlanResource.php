<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PlanResource\Pages;
use App\Models\Plan;
use Filament\Forms\Components\Fieldset;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Set;
use Filament\Resources\Resource;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Columns\ViewColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Number;
use Illuminate\Support\Str;

/**
 * Subscription plans and their quotas (SPEC section 5.4).
 *
 * NO DELETE ACTION — but for a different reason than categories, subcategories
 * and zones. SPEC section 10 covers those three because subscription_items
 * carries no foreign key. Plans are referenced by subscriptions.plan_id, which
 * IS a real foreign key with ON DELETE RESTRICT: the database already refuses,
 * so a delete action would only ever surface a raw integrity error. Deactivate
 * instead — existing subscriptions keep running, the plan stops being offered.
 *
 * The quota is edited inside this form rather than as its own resource: it is
 * 1:1 with the plan and meaningless apart from it.
 */
class PlanResource extends Resource
{
    protected static ?string $model = Plan::class;

    protected static ?string $navigationIcon = 'heroicon-o-credit-card';

    protected static ?string $navigationGroup = 'Master Data';

    protected static ?int $navigationSort = 3;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Section::make('Plan')
                ->columns(2)
                ->schema([
                    TextInput::make('name')
                        ->required()
                        ->maxLength(255)
                        ->live(onBlur: true)
                        ->afterStateUpdated(function (string $operation, $state, Set $set) {
                            if ($operation === 'create') {
                                $set('slug', Str::slug((string) $state));
                            }
                        }),

                    TextInput::make('slug')
                        ->required()
                        ->maxLength(255)
                        ->unique(ignoreRecord: true)
                        ->helperText('Used by the apps. Changing it breaks existing references.'),

                    // Rupees in the field, paise in the column. The conversion
                    // lives in Plan::rupeesToPaise(), which parses the decimal
                    // as a string rather than multiplying a float — Rs 1.15
                    // would otherwise store as 114 paise. See the note there.
                    TextInput::make('price_rupees')
                        ->label('Price')
                        ->prefix('₹')
                        ->required()
                        ->numeric()
                        ->minValue(0)
                        ->step('0.01')
                        ->helperText('Stored as integer paise. Enter rupees, e.g. 999.00')
                        // Stays dehydrated so it reaches mutateFormDataBefore*,
                        // which converts it to price_paise and unsets it. With
                        // dehydrated(false) the hook receives nothing and the
                        // price silently saves as 0.
                        ->afterStateHydrated(function (TextInput $component, ?Plan $record) {
                            $component->state($record?->priceInRupees() ?? '0.00');
                        }),

                    TextInput::make('duration_days')
                        ->label('Duration (days)')
                        ->required()
                        ->numeric()
                        ->minValue(1)
                        ->helperText('The server computes end_date as start + this many days.'),

                    Textarea::make('description')
                        ->rows(2)
                        ->columnSpanFull(),

                    Toggle::make('is_active')
                        ->default(true)
                        ->helperText('Inactive plans are hidden from new subscriptions. Existing ones keep running.'),
                ]),

            Fieldset::make('Quota')
                // 1:1 hasOne — Filament creates or updates the plan_quotas row
                // alongside the plan, inside the same save.
                ->relationship('quota')
                ->columns(3)
                ->schema([
                    TextInput::make('max_categories')->label('Max categories')
                        ->required()->numeric()->minValue(0)->default(1),

                    TextInput::make('max_subcategories')->label('Max subcategories')
                        ->required()->numeric()->minValue(0)->default(1),

                    TextInput::make('max_zones')->label('Max zones')
                        ->required()->numeric()->minValue(0)->default(1),

                    TextInput::make('max_photos')->label('Max photos')
                        ->required()->numeric()->minValue(0)->default(5),

                    TextInput::make('max_videos')->label('Max videos')
                        ->required()->numeric()->minValue(0)->default(0),

                    TextInput::make('priority_rank')
                        ->label('Priority rank')
                        ->required()->numeric()->minValue(0)->default(0)
                        ->helperText('Higher ranks first in customer search, before rating and recency.'),
                ]),

            // Add-on unit pricing (SPEC section 3 item 6 / section 6, task
            // 4.7) — "+2 categories" without changing the base plan. Kept
            // in the SAME Fieldset/relationship('quota') as the limits
            // above, not a second one — two Fieldsets both mapped to the
            // same hasOne relationship risk fighting over which one's
            // save wins. Entered directly in paise, unlike the plan's own
            // price field above — a deliberate simplification (no
            // rupees-conversion hook added for these five fields); see
            // PROGRESS.md's task 4.7 entry.
            Fieldset::make('Add-on pricing (paise per unit)')
                ->relationship('quota')
                ->columns(3)
                ->schema([
                    TextInput::make('addon_price_per_category_paise')
                        ->label('Per category')
                        ->required()->numeric()->minValue(0)->default(0),

                    TextInput::make('addon_price_per_subcategory_paise')
                        ->label('Per subcategory')
                        ->required()->numeric()->minValue(0)->default(0),

                    TextInput::make('addon_price_per_zone_paise')
                        ->label('Per zone')
                        ->required()->numeric()->minValue(0)->default(0),

                    TextInput::make('addon_price_per_photo_paise')
                        ->label('Per photo')
                        ->required()->numeric()->minValue(0)->default(0),

                    TextInput::make('addon_price_per_video_paise')
                        ->label('Per video')
                        ->required()->numeric()->minValue(0)->default(0),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable()
                    ->description(fn (Plan $record): ?string => $record->description),

                TextColumn::make('price_paise')
                    ->label('Price')
                    ->sortable()
                    ->formatStateUsing(fn (int $state): string => Number::currency($state / 100, 'INR'))
                    ->description(fn (Plan $record): string => 'per '.$record->duration_days.' days'),

                ViewColumn::make('quota')
                    ->label('Quota')
                    ->view('filament.tables.columns.quota-card'),

                // Active is the operationally useful number; the all-time
                // total is what ON DELETE RESTRICT actually blocks on, so it
                // is shown whenever it differs — a plan reading "0 active"
                // with 51 expired is still undeletable, and deactivating it
                // still affects those customers' renewals.
                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Plan $record): string => static::inUseLabel($record))
                    ->badge()
                    ->color(fn (Plan $record): string => $record->activeSubscriptionCount() > 0 ? 'success' : 'gray')
                    ->tooltip('Subscriptions currently running on this plan, and the all-time total.'),

                ToggleColumn::make('is_active')
                    ->label('Active'),
            ])
            ->filters([
                TernaryFilter::make('is_active')
                    ->label('Active')
                    ->placeholder('All')
                    ->trueLabel('Active only')
                    ->falseLabel('Inactive only'),
            ])
            ->actions([
                \Filament\Tables\Actions\EditAction::make(),
                // No DeleteAction — see the class docblock.
            ])
            ->bulkActions([
                // No DeleteBulkAction either.
            ])
            ->emptyStateHeading('No plans yet')
            ->emptyStateDescription('A plan sets what a vendor may select and for how long. Add one before onboarding vendors.');
    }

    /**
     * "3 active" when that is the whole story, "3 active / 51 all time" when
     * history differs.
     */
    public static function inUseLabel(Plan $plan): string
    {
        $active = $plan->activeSubscriptionCount();
        $total = $plan->totalSubscriptionCount();

        if ($total === 0) {
            return 'Not used';
        }

        if ($active === $total) {
            return $active.' active';
        }

        return $active.' active / '.$total.' all time';
    }

    public static function getEloquentQuery(): Builder
    {
        // The quota card reads it per row; eager-load rather than N+1.
        return parent::getEloquentQuery()->with('quota');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPlans::route('/'),
            'create' => Pages\CreatePlan::route('/create'),
            'edit' => Pages\EditPlan::route('/{record}/edit'),
        ];
    }
}
