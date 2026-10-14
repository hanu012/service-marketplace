<?php

namespace App\Filament\Widgets;

use Filament\Widgets\AccountWidget;

/**
 * Filament's account widget, full width and without its Sign out button —
 * signing out stays in the user menu (top-right avatar).
 */
class WelcomeWidget extends AccountWidget
{
    protected static string $view = 'filament.widgets.welcome-widget';

    protected int|string|array $columnSpan = 'full';
}
