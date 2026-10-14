<?php

namespace App\Filament\Resources\CategoryResource\RelationManagers;

use App\Filament\Forms\Components\TranslatableInput;
use App\Filament\Support\RecordStatus;
use App\Models\Subcategory;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Set;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Actions\Action as TableAction;
use Filament\Tables\Actions\CreateAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;

/**
 * Subcategories, managed inside the parent category (SPEC section 5.7).
 *
 * This is the level vendor matching actually happens at (SPEC section 4.4) —
 * a vendor who does AC gas filling may not do AC installation.
 *
 * NO DELETE ACTION, per SPEC section 10. Same reasoning as the parent:
 * subscription_items.item_id carries no foreign key, so a hard delete orphans
 * paid-for selections. Deactivate instead.
 */
class SubcategoriesRelationManager extends RelationManager
{
    protected static string $relationship = 'subcategories';

    protected static ?string $recordTitleAttribute = 'name';

    public function form(Form $form): Form
    {
        return $form->schema([
            TranslatableInput::make('name', 'Name', function (string $language) {
                $input = TextInput::make($language)->maxLength(255);

                if ($language !== 'en') {
                    return $input;
                }

                return $input
                    ->live(onBlur: true)
                    ->afterStateUpdated(function (string $operation, $state, Set $set) {
                        if ($operation === 'create') {
                            $set('../slug', Str::slug((string) $state));
                        }
                    });
            }, required: true),

            TextInput::make('slug')
                ->required()
                ->maxLength(255)
                // Slugs only need to be unique within their parent category,
                // matching the composite unique index on the table.
                ->unique(
                    modifyRuleUsing: fn ($rule) => $rule->where('category_id', $this->getOwnerRecord()->getKey()),
                    ignoreRecord: true,
                )
                ->helperText('Unique within this category.'),

            FileUpload::make('icon')
                ->image()
                ->imageEditor()
                ->directory('subcategory-icons')
                ->maxSize(1024),

            Select::make('service_type')
                ->label('Service type')
                ->options(static::serviceTypes())
                ->native(false)
                ->helperText("Backs the filter chips on the customer app's subcategory screen. Leave blank if none fit."),

            Toggle::make('is_popular')
                ->label('Popular')
                ->helperText('Shows a "Popular" badge and surfaces this service first on the customer app.'),

            // Starting status only; afterwards it goes through "Change
            // status". Hidden on edit, not disabled — see CategoryResource.
            Toggle::make('is_active')
                ->label('Active')
                ->default(true)
                ->hiddenOn('edit')
                ->helperText('Inactive subcategories are hidden from the apps but keep their existing subscriptions.'),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('name')
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->recordAction('view')
            ->columns([
                ImageColumn::make('icon')
                    ->label('')
                    ->circular(),

                TextColumn::make('name')
                    ->searchable(query: \App\Support\TranslatableColumn::search('name'))
                    ->sortable(query: \App\Support\TranslatableColumn::sort('name'))
                    ->weight('bold')
                    ->description(fn (Subcategory $record): string => $record->slug),

                TextColumn::make('service_type')
                    ->label('Type')
                    ->badge()
                    ->placeholder('—')
                    ->formatStateUsing(fn (?string $state): string => $state === null ? '—' : ucfirst($state)),

                IconColumn::make('is_popular')
                    ->label('Popular')
                    ->boolean(),

                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Subcategory $record): int => $record->countSubscriptionReferences())
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->formatStateUsing(fn (int $state): string => $state === 0
                        ? 'Not used'
                        : $state.' '.Str::plural('subscription', $state)),

                RecordStatus::column(),

                TextColumn::make('updated_at')
                    ->label('Last modified')
                    ->dateTime('d M Y, H:i')
                    ->sortable()
                    ->toggleable(),
            ])
            ->headerActions([
                CreateAction::make(),
            ])
            ->actions([
                ViewAction::make()
                    ->modalHeading(fn (Subcategory $record): string => $record->name),
                EditAction::make(),
                RecordStatus::configure(
                    TableAction::make('changeStatus'),
                    fn (Subcategory $record): string => static::statusEffects($record),
                )
                    // Subcategory has no policy of its own; changing one is
                    // editing its category, so that is the permission asked.
                    ->authorize(fn (): bool => Auth::user()?->can('update', $this->getOwnerRecord()) ?? false),
                // No DeleteAction — SPEC section 10.
            ])
            ->bulkActions([
                // No DeleteBulkAction.
            ])
            ->modifyQueryUsing(fn (Builder $query) => $query->orderBy('sort_order'))
            ->emptyStateHeading('No subcategories yet')
            ->emptyStateDescription('Vendors are matched to customers at this level, so every category needs at least one.');
    }

    public function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Section::make('Basic details')
                ->collapsible()
                ->columns(4)
                ->schema([
                    TextEntry::make('name_en')
                        ->label('Name (English)')
                        ->state(fn (Subcategory $record): ?string => $record->getTranslation('name', 'en', false) ?: null)
                        ->weight('bold'),
                    TextEntry::make('name_hi')
                        ->label('Name (Hindi)')
                        ->state(fn (Subcategory $record): ?string => $record->getTranslation('name', 'hi', false) ?: null)
                        ->placeholder('—'),
                    TextEntry::make('name_gu')
                        ->label('Name (Gujarati)')
                        ->state(fn (Subcategory $record): ?string => $record->getTranslation('name', 'gu', false) ?: null)
                        ->placeholder('—'),
                    RecordStatus::entry(),
                    TextEntry::make('category.name')->label('Category'),
                    TextEntry::make('slug'),
                    TextEntry::make('service_type')
                        ->label('Service type')
                        ->formatStateUsing(fn (?string $state): string => static::serviceTypes()[$state] ?? '—')
                        ->placeholder('—'),
                    IconEntry::make('is_popular')->label('Popular')->boolean(),
                    TextEntry::make('sort_order')->label('Display order'),
                    ImageEntry::make('icon')->circular()->placeholder('No icon'),
                ]),

            Section::make('Usage')
                ->collapsible()
                ->schema([
                    TextEntry::make('in_use')
                        ->label('Subscription selections')
                        ->state(fn (Subcategory $record): string => $record->countSubscriptionReferences() === 0
                            ? 'Not used'
                            : $record->countSubscriptionReferences().' '.Str::plural('subscription', $record->countSubscriptionReferences()))
                        ->helperText('Vendor subscriptions that include this service.'),
                ]),

            RecordStatus::recordSection(),
        ]);
    }

    /** @return array<string, string> */
    private static function serviceTypes(): array
    {
        return [
            'installation' => 'Installation',
            'repair' => 'Repair',
            'maintenance' => 'Maintenance',
        ];
    }

    private static function statusEffects(Subcategory $record): string
    {
        $count = $record->countSubscriptionReferences();

        return 'Active: customers can find vendors for it, and salesmen and vendors can select it. '
            .'Inactive: hidden from the apps and from vendor detail pages. '
            .($count === 0 ? 'No subscriptions include it.' : $count.' '.Str::plural('subscription', $count).' include it — they keep running either way.');
    }
}
