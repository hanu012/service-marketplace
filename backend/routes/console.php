<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// BUILD_PLAN 7.1 / SPEC section 7 — Active -> Grace -> Expired.
Schedule::command('subscriptions:process-expiry')->daily();

// BUILD_PLAN 7.2 / SPEC section 5.12 — expiry reminders (T-15/T-7/T-1).
Schedule::command('subscriptions:send-expiry-reminders')->daily();
