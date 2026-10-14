<?php

namespace App\Policies;

/**
 * Category module permissions (SPEC section 5.16).
 *
 * No delete method: SPEC section 10 / the RESTRICT foreign key mean these are
 * deactivated, never hard-deleted. Filament fails closed on a missing policy
 * method, so the absence itself denies any delete attempt.
 */
class CategoryPolicy extends AdminModulePolicy
{
    protected function module(): string
    {
        // "categories", not the naive Category + s. This must match the
        // prefix used in App\Enums\Permission exactly — a mismatch silently
        // denies everything for this module, since hasPermission() then
        // compares against a string nothing grants.
        return 'categories';
    }
}
