<?php

namespace App\Console\Commands;

use App\Models\Subscription;
use App\Services\PushNotificationService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * SPEC section 5.12's expiry reminders (T-15/T-7/T-1, BUILD_PLAN 7.2)
 * — distinct from subscriptions:process-expiry (task 7.1), which
 * moves lifecycle status. This command only sends a heads-up while a
 * subscription is still `active`; Grace has its own, different
 * messaging and isn't touched here.
 *
 * Idempotency: each threshold gets its own nullable
 * reminder_sent_tN_at column on `subscriptions` (same "timestamp on
 * the owning row, set once" idiom as leads.review_requested_at,
 * task 4.8) — NOT tracked via the `notifications` dispatch log, which
 * still gets a row per send regardless, for a different purpose
 * (audit/visibility, not "have we already done this").
 */
class SendSubscriptionExpiryReminders extends Command
{
    protected $signature = 'subscriptions:send-expiry-reminders';

    protected $description = 'Send a one-time push reminder at T-15/T-7/T-1 days before an active subscription expires.';

    /**
     * @var array<int, string>
     */
    private const THRESHOLDS = [
        15 => 'reminder_sent_t15_at',
        7 => 'reminder_sent_t7_at',
        1 => 'reminder_sent_t1_at',
    ];

    public function handle(PushNotificationService $notifications): int
    {
        $today = Carbon::today();
        $totals = [];

        foreach (self::THRESHOLDS as $days => $column) {
            $totals[$days] = $this->sendForThreshold($notifications, $days, $column, $today);
        }

        $summary = collect($totals)
            ->map(fn (int $count, int $days) => "T-{$days}: {$count}")
            ->implode('. ');

        $this->info($summary.'.');

        return self::SUCCESS;
    }

    private function sendForThreshold(
        PushNotificationService $notifications,
        int $days,
        string $column,
        Carbon $today,
    ): int {
        $count = 0;

        Subscription::query()
            ->where('status', 'active')
            ->whereNull($column)
            ->where('end_date', '>=', $today)
            ->where('end_date', '<=', $today->copy()->addDays($days))
            ->chunkById(100, function ($subscriptions) use (&$count, $notifications, $days, $column) {
                foreach ($subscriptions as $subscription) {
                    $notifications->notifySubscriptionExpiring($subscription, $days);
                    $subscription->update([$column => now()]);
                    $count++;
                }
            });

        return $count;
    }
}
