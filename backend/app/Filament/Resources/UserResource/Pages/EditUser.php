<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use App\Models\User;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;
use RuntimeException;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            $this->deleteAction(),
            $this->restoreAction(),
        ];
    }

    /**
     * Deletes through User::deleteWithTombstone() rather than Filament's
     * DeleteAction.
     *
     * A plain soft delete leaves the row holding its email on a unique index
     * that does not exempt trashed rows, so the person could never sign up
     * again (SPEC section 4.10 requires deletion for app store compliance).
     * The tombstone rewrites the address, keeps the original for restore, and
     * revokes every Sanctum token — all in one transaction.
     */
    private function deleteAction(): Action
    {
        return Action::make('deleteWithTombstone')
            ->label('Delete account')
            ->icon('heroicon-o-trash')
            ->color('danger')
            ->visible(fn (User $record): bool => ! $record->trashed())
            ->requiresConfirmation()
            ->modalHeading('Delete this account?')
            ->modalDescription(
                'The account is soft-deleted and its email address is released so the person '
                .'can sign up again. Their leads, reviews and history are preserved. '
                .'All signed-in devices are logged out immediately. This can be undone.'
            )
            ->modalSubmitActionLabel('Delete account')
            ->action(function (User $record) {
                $record->deleteWithTombstone();

                Notification::make()
                    ->title('Account deleted')
                    ->body('The email address has been released and all devices signed out.')
                    ->success()
                    ->send();

                $this->redirect($this->getResource()::getUrl('index'));
            });
    }

    /**
     * Restores the account and puts the original email back.
     *
     * The address may have been claimed by someone else while this account
     * was deleted — releasing it is the whole point of the tombstone — so the
     * restore refuses rather than violating the unique index or silently
     * handing back an account nobody can sign in as.
     */
    private function restoreAction(): Action
    {
        return Action::make('restoreWithOriginalEmail')
            ->label('Restore account')
            ->icon('heroicon-o-arrow-uturn-left')
            ->color('success')
            ->visible(fn (User $record): bool => $record->trashed())
            ->requiresConfirmation()
            ->modalHeading('Restore this account?')
            ->modalDescription(fn (User $record): string => $record->original_email
                ? 'The account is restored and its email set back to '.$record->original_email.'. '
                    .'They will need to reset their password, since all devices were signed out on deletion.'
                : 'The account is restored. No original email was recorded, so it keeps its current address.')
            ->modalSubmitActionLabel('Restore account')
            ->action(function (User $record) {
                try {
                    $record->restoreWithOriginalEmail();
                } catch (RuntimeException $e) {
                    Notification::make()
                        ->title('Could not restore this account')
                        ->body($e->getMessage())
                        ->danger()
                        ->persistent()
                        ->send();

                    return;
                }

                Notification::make()
                    ->title('Account restored')
                    ->body('Email restored to '.$record->fresh()->email.'.')
                    ->success()
                    ->send();

                $this->redirect($this->getResource()::getUrl('edit', ['record' => $record]));
            });
    }

    /**
     * The password field is absent from the form on purpose: an admin cannot
     * read or set an existing password. A forgotten one goes through the
     * email reset flow built in task 0.3.
     */
    protected function mutateFormDataBeforeSave(array $data): array
    {
        unset($data['password']);

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
