<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ReviewResource\Pages;
use App\Models\Review;
use App\Services\ReviewModerationService;
use Filament\Forms\Components\Textarea;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

/**
 * Review Management (SPEC section 5 item 6, task 5.5) — hide/unhide,
 * view vendor replies, a fraud-signal filter.
 *
 * A table, not a grid: reviews are text, unlike MediaModerationResource's
 * images/video. Every review is shown, not just a "pending" subset —
 * this is a management/browse list, not a triage queue, since admins
 * need to see and unhide already-hidden reviews too.
 *
 * No Create/Edit/Delete pages: admin never authors, edits, or deletes a
 * review — only hides/unhides one via the actions below. Same "the
 * omission is the enforcement" shape as MediaModerationResource.
 */
class ReviewResource extends Resource
{
    protected static ?string $model = Review::class;

    protected static ?string $navigationIcon = 'heroicon-o-star';

    protected static ?string $navigationLabel = 'Reviews';

    protected static ?string $modelLabel = 'review';

    protected static ?string $navigationGroup = 'People';

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['customer.user', 'vendor', 'lead']);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('customer.user.name')
                    ->label('Customer')
                    ->searchable(),

                TextColumn::make('vendor.business_name')
                    ->label('Vendor')
                    ->weight('bold')
                    ->searchable(),

                TextColumn::make('rating')
                    ->formatStateUsing(fn (int $state): string => str_repeat('★', $state).str_repeat('☆', 5 - $state)),

                TextColumn::make('comment')
                    ->wrap()
                    ->limit(100)
                    ->placeholder('—'),

                TextColumn::make('vendor_reply')
                    ->label('Vendor reply')
                    ->wrap()
                    ->limit(100)
                    ->placeholder('—'),

                IconColumn::make('is_hidden')
                    ->label('Hidden')
                    ->boolean(),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('is_hidden')
                    ->label('Visibility')
                    ->placeholder('All')
                    ->trueLabel('Hidden only')
                    ->falseLabel('Visible only'),

                // SPEC section 5 item 6's fraud signal: a review created
                // more than 30 days after its own lead. The write path
                // (StoreReviewRequest) already rejects this at creation
                // time, so a match here means something bypassed it —
                // seeded data, a bug, or direct DB manipulation — worth
                // an admin's attention, not a normal filtering need.
                Filter::make('lead_older_than_30_days')
                    ->label('Lead older than 30 days (fraud signal)')
                    ->query(fn (Builder $query): Builder => $query->whereHas(
                        'lead',
                        fn (Builder $lead) => $lead->whereRaw(
                            'leads.created_at < reviews.created_at - INTERVAL 30 DAY'
                        )
                    )),
            ])
            ->actions([
                static::hideAction(),
                static::unhideAction(),
            ])
            ->bulkActions([
                // No bulk hide/unhide — each review needs its own look,
                // same stance MediaModerationResource takes on approve/
                // reject.
            ])
            ->emptyStateHeading('No reviews yet');
    }

    public static function hideAction(): Action
    {
        return Action::make('hide')
            ->label('Hide')
            ->icon('heroicon-o-eye-slash')
            ->color('danger')
            ->visible(fn (Review $record): bool => ! $record->is_hidden && (Auth::user()?->can('hide', Review::class) ?? false))
            ->modalHeading('Hide this review?')
            ->modalDescription('It stops appearing on the vendor\'s public detail page and no longer counts toward their rating.')
            ->form([
                Textarea::make('reason')
                    ->label('Reason')
                    ->required()
                    ->maxLength(1000),
            ])
            ->action(function (Review $record, array $data) {
                app(ReviewModerationService::class)->hide($record, Auth::user(), $data['reason']);

                Notification::make()->title('Review hidden')->success()->send();
            });
    }

    public static function unhideAction(): Action
    {
        return Action::make('unhide')
            ->label('Unhide')
            ->icon('heroicon-o-eye')
            ->color('success')
            ->visible(fn (Review $record): bool => $record->is_hidden && (Auth::user()?->can('hide', Review::class) ?? false))
            ->requiresConfirmation()
            ->modalHeading('Unhide this review?')
            ->action(function (Review $record) {
                app(ReviewModerationService::class)->unhide($record);

                Notification::make()->title('Review unhidden')->success()->send();
            });
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListReviews::route('/'),
        ];
    }
}
