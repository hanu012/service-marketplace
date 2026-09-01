<?php

namespace App\Notifications;

use App\Models\Subscription;
use App\Notifications\Channels\FcmChannel;
use Illuminate\Notifications\Notification;

/**
 * SPEC section 5.12's expiry reminders (T-15/T-7/T-1) — new. Sent to
 * the VENDOR. `$daysRemaining` is one of 15/7/1, whichever threshold
 * SendSubscriptionExpiryReminders just crossed for this subscription.
 */
class SubscriptionExpiringNotification extends Notification
{
    public function __construct(private readonly Subscription $subscription, private readonly int $daysRemaining) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return [FcmChannel::class];
    }

    /**
     * @return array<string, mixed>
     */
    public function toFcm(object $notifiable): array
    {
        $days = $this->daysRemaining === 1 ? '1 day' : "{$this->daysRemaining} days";

        return [
            'title' => 'Your plan is expiring soon',
            'body' => "Your subscription expires in {$days}. Renew to stay visible to customers.",
            'type' => 'subscription_expiring',
            'target_app' => 'vendor',
            'data' => ['subscription_id' => $this->subscription->id, 'days_remaining' => $this->daysRemaining],
        ];
    }
}
