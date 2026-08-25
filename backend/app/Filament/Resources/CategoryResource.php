<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CategoryResource\Pages;
use App\Filament\Resources\CategoryResource\RelationManagers\SubcategoriesRelationManager;
use App\Models\Category;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Set;
use Filament\Resources\Resource;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Support\Str;

/**
 * Category master data (SPEC section 5.7).
 *
 * NOT the same class as App\Http\Resources\CategoryResource, which is the API
 * transformer. Same short name, different namespaces — never import both into
 * one file without aliasing.
 *
 * NO DELETE ACTION, deliberately. See SPEC section 10: subscription_items
 * stores selections in one table with an item_type enum, so item_id carries
 * no foreign key and a hard delete would orphan every subscription row that
 * bought this category. Deactivating is the only removal path. The model's
 * PreventsDeletionWhileSubscribed guard backs this at the data layer for any
 * caller that bypasses the panel.
 */
class CategoryResource extends Resource
{
    protected static ?string $model = Category::class;

    protected static ?string $navigationIcon = 'heroicon-o-squares-2x2';

    protected static ?string $navigationGroup = 'Master Data';

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('name')
                ->required()
                ->maxLength(255)
                ->live(onBlur: true)
                // Only fill the slug while creating: changing it later would
                // break any link already published against the old value.
                ->afterStateUpdated(function (string $operation, $state, Set $set) {
                    if ($operation === 'create') {
                        $set('slug', Str::slug((string) $state));
                    }
                }),

            TextInput::make('slug')
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true)
                ->helperText('Used in URLs and by the apps. Changing it breaks existing links.'),

            FileUpload::make('icon')
                ->image()
                ->imageEditor()
                ->directory('category-icons')
                ->maxSize(1024)
                ->helperText('Shown in the customer browse grid.'),

            Toggle::make('is_active')
                ->default(true)
                ->helperText('Inactive categories are hidden from the apps but keep their existing subscriptions.'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            // Drag-to-reorder writes sort_order. Filament disables other
            // sorting while reorder mode is on, which is what we want.
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
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('subcategories_count')
                    ->counts('subcategories')
                    ->label('Subcategories')
                    ->badge(),

                // Shows why delete is not on offer, and makes the cost of
                // deactivating visible before an admin flips the toggle.
                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Category $record): int => $record->countSubscriptionReferences())
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->formatStateUsing(fn (int $state): string => $state === 0
                        ? 'Not used'
                        : $state.' '.Str::plural('subscription', $state))
                    ->tooltip('Subscription selections referencing this category or its subcategories.'),

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
                // No DeleteAction — see the class docblock and SPEC section 10.
            ])
            ->bulkActions([
                // No DeleteBulkAction either.
            ])
            ->emptyStateHeading('No categories yet')
            ->emptyStateDescription('Categories are the top level of the service tree. Add one to get started.');
    }

    public static function getRelations(): array
    {
        return [
            SubcategoriesRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListCategories::route('/'),
            'create' => Pages\CreateCategory::route('/create'),
            'edit' => Pages\EditCategory::route('/{record}/edit'),
        ];
    }
}
