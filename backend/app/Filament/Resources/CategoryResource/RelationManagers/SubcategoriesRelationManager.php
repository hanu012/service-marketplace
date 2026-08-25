<?php

namespace App\Filament\Resources\CategoryResource\RelationManagers;

use App\Models\Subcategory;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Set;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Actions\CreateAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
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

            Toggle::make('is_active')
                ->default(true)
                ->helperText('Inactive subcategories are hidden from the apps but keep their existing subscriptions.'),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('name')
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->columns([
                ImageColumn::make('icon')
                    ->label('')
                    ->circular(),

                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('slug')
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Subcategory $record): int => $record->countSubscriptionReferences())
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->formatStateUsing(fn (int $state): string => $state === 0
                        ? 'Not used'
                        : $state.' '.Str::plural('subscription', $state)),

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
            ->headerActions([
                CreateAction::make(),
            ])
            ->actions([
                EditAction::make(),
                // No DeleteAction — SPEC section 10.
            ])
            ->bulkActions([
                // No DeleteBulkAction.
            ])
            ->modifyQueryUsing(fn (Builder $query) => $query->orderBy('sort_order'))
            ->emptyStateHeading('No subcategories yet')
            ->emptyStateDescription('Vendors are matched to customers at this level, so every category needs at least one.');
    }
}
