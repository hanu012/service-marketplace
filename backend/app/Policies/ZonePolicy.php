<?php

namespace App\Policies;

/**
 * Zone module permissions (SPEC section 5.16).
 *
 * No delete method: SPEC section 10 / the RESTRICT foreign key mean these are
 * deactivated, never hard-deleted. Filament fails closed on a missing policy
 * method, so the absence itself denies any delete attempt.
 */
class ZonePolicy extends AdminModulePolicy
{
    protected function module(): string
    {
        return 'zones';
    }
}
