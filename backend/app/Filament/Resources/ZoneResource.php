<?php

namespace App\Filament\Resources;

use App\Filament\Forms\Components\PolygonMap;
use App\Filament\Resources\ZoneResource\Pages;
use App\Models\Zone;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Forms\Set;
use Illuminate\Validation\Rules\Unique;
use Filament\Resources\Resource;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;

/**
 * Zone management (SPEC sections 5.3, 8 and 11).
 *
 * NO DELETE ACTION, per SPEC section 10 — same reasoning as categories:
 * subscription_items.item_id carries no foreign key, so hard-deleting a zone
 * a vendor paid to cover would orphan the row. Deactivating is the only
 * removal path, and PreventsDeletionWhileSubscribed backs it at the data
 * layer for callers outside the panel.
 *
 * DRAFT WORKFLOW (SPEC section 11): polygon is NOT NULL and always indexed,
 * so a zone cannot be saved without a boundary. Zones therefore start
 * inactive — draw a rough outline now, refine it, then switch Active on.
 * Only active zones take part in customer matching.
 */
class ZoneResource extends Resource
{
    protected static ?string $model = Zone::class;

    protected static ?string $navigationIcon = 'heroicon-o-map';

    protected static ?string $navigationGroup = 'Master Data';

    protected static ?int $navigationSort = 2;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Section::make('Zone')
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
                        // Scoped to the parent, matching the composite unique
                        // index on (parent_id, slug): two different cities can
                        // each have a "central" sub-zone.
                        ->unique(
                            modifyRuleUsing: fn (Unique $rule, Get $get) => $rule
                                ->where('parent_id', $get('parent_id')),
                            ignoreRecord: true,
                        )
                        ->helperText('Unique within the parent zone.'),

                    Select::make('parent_id')
                        ->label('Parent zone')
                        ->relationship(
                            name: 'parent',
                            titleAttribute: 'name',
                            // Only top-level zones are offered: SPEC section 8
                            // caps the hierarchy at two levels (city ->
                            // sub-zone). A zone also cannot be its own parent.
                            modifyQueryUsing: fn ($query, ?Zone $record) => $query
                                ->whereNull('parent_id')
                                ->when($record, fn ($q) => $q->whereKeyNot($record->getKey())),
                        )
                        ->searchable()
                        ->preload()
                        ->placeholder('None — this is a main zone')
                        // Filtering the options is UX; these rules are the
                        // enforcement. A Livewire request can carry any id,
                        // so the constraint cannot live in the dropdown alone.
                        ->rules([
                            fn (?Zone $record): \Closure => function (string $attribute, $value, \Closure $fail) use ($record) {
                                if (blank($value)) {
                                    return;
                                }

                                $parent = Zone::find($value);

                                if ($parent === null) {
                                    return;
                                }

                                // Forward direction, as SPEC section 8 states:
                                // the chosen parent must itself be top-level.
                                if ($parent->parent_id !== null) {
                                    $fail(
                                        "\"{$parent->name}\" is already a sub-zone. Zones go two levels deep "
                                        .'(city → sub-zone), so a sub-zone cannot have children of its own.'
                                    );

                                    return;
                                }

                                // Reverse direction: giving a parent to a zone
                                // that already has children would build the
                                // same three-level tree from the other end.
                                if ($record !== null && $record->children()->exists()) {
                                    $fail(
                                        "\"{$record->name}\" already has sub-zones, so it cannot itself become "
                                        .'a sub-zone. Zones go two levels deep (city → sub-zone).'
                                    );
                                }
                            },
                        ])
                        ->helperText('Leave empty for a main zone such as Ahmedabad. Set it for a sub-zone such as Gota. Zones go two levels deep — a sub-zone cannot have sub-zones of its own.'),

                    TextInput::make('pincode')
                        ->maxLength(10)
                        ->helperText('Fallback match when GPS is denied or the location falls outside every polygon.'),
                ]),

            Section::make('Boundary')
                ->description('Draw the zone outline. A rough shape is fine to start — the zone stays inactive until you switch it on.')
                ->schema([
                    PolygonMap::make('polygon_points')
                        ->label('')
                        ->required()
                        ->rules([
                            fn (): \Closure => function (string $attribute, $value, \Closure $fail) {
                                if (! is_array($value) || count($value) < 3) {
                                    $fail('Draw a boundary with at least 3 points.');
                                }
                            },
                        ])
                        ->dehydrated(),
                ]),

            Section::make('Status')
                ->schema([
                    Toggle::make('is_active')
                        // SPEC section 11: zones are drafts until switched on.
                        ->default(false)
                        ->label('Active')
                        ->helperText('Only active zones are matched against customer locations. Leave off while the boundary is still rough.'),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('name')
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('parent.name')
                    ->label('Parent')
                    ->placeholder('Main zone')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('pincode')
                    ->searchable()
                    ->placeholder('—'),

                IconColumn::make('has_boundary')
                    ->label('Boundary')
                    ->state(fn (): bool => true)
                    ->boolean()
                    ->tooltip('Every zone has a boundary — the column is NOT NULL.'),

                // Same purpose as on CategoryResource: shows why no delete is
                // offered, and the cost of deactivating, before the toggle is
                // flipped.
                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Zone $record): int => $record->countSubscriptionReferences())
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->formatStateUsing(fn (int $state): string => $state === 0
                        ? 'Not used'
                        : $state.' '.Str::plural('subscription', $state))
                    // Transitive for parent zones, per SPEC section 8:
                    // deactivating a parent drops every descendant out of
                    // matching, so the count has to reflect the subtree rather
                    // than this row alone.
                    ->tooltip(fn (Zone $record): string => $record->isLeaf()
                        ? 'Subscription selections covering this zone.'
                        : 'Subscription selections covering this zone or any zone beneath it. '
                            .'Deactivating this parent removes all of them from matching.'),

                ToggleColumn::make('is_active')
                    ->label('Active'),
            ])
            ->filters([
                TernaryFilter::make('is_active')
                    ->label('Active')
                    ->placeholder('All')
                    ->trueLabel('Active only')
                    ->falseLabel('Drafts only'),

                SelectFilter::make('parent_id')
                    ->label('Parent zone')
                    ->relationship('parent', 'name')
                    ->searchable()
                    ->preload(),
            ])
            ->actions([
                \Filament\Tables\Actions\EditAction::make(),
                // No DeleteAction — SPEC section 10.
            ])
            ->bulkActions([
                // No DeleteBulkAction either.
            ])
            ->emptyStateHeading('No zones yet')
            ->emptyStateDescription('Zones decide which vendors a customer sees. Draw a main zone first, then its sub-zones.');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZones::route('/'),
            'create' => Pages\CreateZone::route('/create'),
            'edit' => Pages\EditZone::route('/{record}/edit'),
        ];
    }
}
