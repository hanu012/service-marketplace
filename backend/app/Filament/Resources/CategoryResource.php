<?php

namespace App\Filament\Resources;

use App\Filament\Forms\Components\TranslatableInput;
use App\Filament\Resources\CategoryResource\Pages;
use App\Filament\Resources\CategoryResource\RelationManagers\SubcategoriesRelationManager;
use App\Filament\Support\RecordStatus;
use App\Models\Category;
use App\Models\Subcategory;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Forms\Set;
use Filament\Infolists\Components\ImageEntry;
use Filament\Infolists\Components\Section;
use Filament\Infolists\Components\TextEntry;
use Filament\Infolists\Infolist;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action as TableAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
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
 *
 * Status is changed only through RecordStatus's "Change status" action (with
 * a reason), never a one-click toggle — see RecordStatus.
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
            TranslatableInput::make('name', 'Name', function (string $language) {
                $input = TextInput::make($language)->maxLength(255);

                if ($language !== 'en') {
                    return $input;
                }

                return $input
                    ->live(onBlur: true)
                    // Only fill the slug while creating: changing it later
                    // would break any link already published against it.
                    ->afterStateUpdated(function (string $operation, $state, Set $set) {
                        if ($operation === 'create') {
                            $set('../slug', Str::slug((string) $state));
                        }
                    });
            }, required: true),

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

            // Only the starting status. After creation it changes through
            // "Change status", which asks for a reason — hidden (not
            // disabled) so it is not part of the edit form's state at all.
            Toggle::make('is_active')
                ->label('Active')
                ->default(true)
                ->hiddenOn('edit')
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
            // A row click opens the read-only view, not the edit form, so
            // looking at a record can never change it by accident.
            ->recordUrl(null)
            ->recordAction('view')
            ->columns([
                ImageColumn::make('icon')
                    ->label('')
                    ->circular(),

                TextColumn::make('name')
                    ->searchable(query: \App\Support\TranslatableColumn::search('name'))
                    ->sortable(query: \App\Support\TranslatableColumn::sort('name'))
                    ->weight('bold')
                    ->description(fn (Category $record): string => $record->slug),

                TextColumn::make('subcategories_count')
                    ->counts('subcategories')
                    ->label('Subcategories')
                    ->badge(),

                // Shows why delete is not on offer, and makes the cost of
                // deactivating visible before an admin changes the status.
                TextColumn::make('in_use')
                    ->label('In use')
                    ->state(fn (Category $record): int => $record->countSubscriptionReferences())
                    ->badge()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->formatStateUsing(fn (int $state): string => $state === 0
                        ? 'Not used'
                        : $state.' '.Str::plural('subscription', $state))
                    ->tooltip('Subscription selections referencing this category or its subcategories.'),

                RecordStatus::column(),

                TextColumn::make('created_at')
                    ->label('Added on')
                    ->dateTime('d M Y, H:i')
                    ->sortable()
                    ->toggleable(),

                TextColumn::make('updated_at')
                    ->label('Last modified')
                    ->dateTime('d M Y, H:i')
                    ->sortable()
                    ->toggleable(),
            ])
            ->actions([
                static::viewAction(),
                EditAction::make(),
                RecordStatus::configure(TableAction::make('changeStatus'), fn (Category $record): string => static::statusEffects($record)),
                // No DeleteAction — see the class docblock and SPEC section 10.
            ])
            ->bulkActions([
                // No DeleteBulkAction either.
            ])
            ->emptyStateHeading('No categories yet')
            ->emptyStateDescription('Categories are the top level of the service tree. Add one to get started.');
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Section::make('Basic details')
                ->collapsible()
                ->columns(4)
                ->schema([
                    TextEntry::make('name_en')
                        ->label('Name (English)')
                        ->state(fn (Category $record): ?string => $record->getTranslation('name', 'en', false) ?: null)
                        ->weight('bold'),
                    TextEntry::make('name_hi')
                        ->label('Name (Hindi)')
                        ->state(fn (Category $record): ?string => $record->getTranslation('name', 'hi', false) ?: null)
                        ->placeholder('—'),
                    TextEntry::make('name_gu')
                        ->label('Name (Gujarati)')
                        ->state(fn (Category $record): ?string => $record->getTranslation('name', 'gu', false) ?: null)
                        ->placeholder('—'),
                    RecordStatus::entry(),
                    TextEntry::make('slug'),
                    TextEntry::make('sort_order')->label('Display order'),
                    ImageEntry::make('icon')->circular()->placeholder('No icon'),
                ]),

            Section::make('Subcategories')
                ->collapsible()
                ->schema([
                    TextEntry::make('subcategory_list')
                        ->label('')
                        ->state(fn (Category $record): array => $record->subcategories()
                            ->orderBy('sort_order')
                            ->get()
                            ->map(fn (Subcategory $subcategory): string => $subcategory->name
                                .($subcategory->is_active ? '' : ' (inactive)'))
                            ->all())
                        ->badge()
                        ->placeholder('No subcategories yet.'),
                ]),

            Section::make('Usage')
                ->collapsible()
                ->schema([
                    TextEntry::make('in_use')
                        ->label('Subscription selections')
                        ->state(fn (Category $record): string => static::usageLabel($record->countSubscriptionReferences()))
                        ->helperText('Selections on vendor subscriptions that reference this category or its subcategories.'),
                ]),

            RecordStatus::recordSection(),
        ]);
    }

    /** View popup with an Edit button in its footer, next to Close. */
    public static function viewAction(): ViewAction
    {
        return ViewAction::make()
            ->modalHeading(fn (Category $record): string => $record->name)
            ->extraModalFooterActions(fn (ViewAction $action): array => [
                $action->makeModalAction('edit')
                    ->label('Edit')
                    ->icon('heroicon-o-pencil-square')
                    ->color('primary')
                    ->url(static::getUrl('edit', ['record' => $action->getRecord()])),
            ]);
    }

    public static function statusEffects(Category $record): string
    {
        return 'Active: shown in the customer app and selectable by salesmen and vendors. '
            .'Inactive: hidden from the apps together with all its subcategories. '
            .static::usageLabel($record->countSubscriptionReferences())
            .' reference it — existing subscriptions keep running either way.';
    }

    private static function usageLabel(int $count): string
    {
        return $count === 0 ? 'No subscription selections' : $count.' subscription '.Str::plural('selection', $count);
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
