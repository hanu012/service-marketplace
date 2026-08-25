<?php

namespace App\Models;

use App\Models\Concerns\RecordsAuditLog;
use App\Models\Concerns\TracksFileDisk;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Vendor profile, 1:1 with a user carrying role = vendor.
 *
 * Lifecycle (SPEC section 7):
 *   draft -> pending_payment -> pending_verification (self-registered only)
 *         -> active -> grace -> expired
 *
 * An admin creating a vendor here starts it at `draft`: there is no
 * subscription yet, which is the same position the salesman flow is in before
 * payment (SPEC section 2.2). `pending_verification` is explicitly for
 * self-registered vendors only.
 *
 * `is_suspended` is a separate admin flag for policy violations, independent
 * of subscription dates.
 */
class Vendor extends Model
{
    use HasFactory;
    use RecordsAuditLog;
    use SoftDeletes;
    use TracksFileDisk;

    protected $fillable = [
        'user_id',
        'business_name',
        'owner_name',
        'phone',
        'address',
        'latitude',
        'longitude',
        'status',
        'is_suspended',
        'shop_photo_path',
        'id_proof_type',
        'id_proof_path',
        'disk',
        'created_by_salesman_id',
        'verified_at',
        'verified_by',
        'rejection_reason',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
            'is_suspended' => 'boolean',
            'verified_at' => 'datetime',
            'rating_avg' => 'decimal:2',
            'rating_count' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * A vendor carries TWO files - shop photo and ID proof - against ONE
     * `disk` column, unlike Category which has a single icon.
     *
     * One column is honest here because both KYC files are written by the
     * same upload request to the same disk, and the R2 migration should move
     * a row's files together anyway: a vendor whose shop photo is on R2 while
     * its ID proof is still local is a state nobody benefits from.
     *
     * The trait's single-column contract is satisfied by naming the primary
     * file, and the stamping override below covers either path being set.
     */
    public function fileDiskPathColumn(): string
    {
        return 'shop_photo_path';
    }

    /**
     * Both KYC files, so the disk is stamped whichever one is uploaded.
     *
     * This declaration is the whole of it — TracksFileDisk checks every
     * column listed here. There is deliberately no bespoke boot hook on this
     * model: an earlier version had one, which is fragile twice over. It has
     * to be hand-written for each multi-file model (Phase 4's vendor
     * self-service KYC would need its own copy), and naming it wrongly fails
     * silently, since Eloquent only auto-calls `boot{TraitName}` and
     * `booted()`.
     *
     * @return array<int, string>
     */
    public function fileDiskPathColumns(): array
    {
        return ['shop_photo_path', 'id_proof_path'];
    }

    public function createdBySalesman(): BelongsTo
    {
        return $this->belongsTo(Salesman::class, 'created_by_salesman_id');
    }

    public function verifiedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'verified_by');
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }

    /**
     * Rows, not customers — `favoritedBy()` would be misleading if it
     * returned Favorite records, so the name says exactly what it holds.
     */
    public function favorites(): HasMany
    {
        return $this->hasMany(Favorite::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(Report::class);
    }

    /**
     * Portfolio uploads (SPEC section 3 item 5, task 4.5) — photos/videos
     * of completed work, quota-capped by the active subscription's plan.
     */
    public function media(): MorphMany
    {
        return $this->morphMany(Media::class, 'mediable');
    }

    /**
     * The subscription the vendor dashboard and services-management screens
     * both key off (task 4.2/4.4) — active and not yet past its end date.
     * Not a relation: it needs a `where`/`latest` beyond what a plain
     * `hasOne` expresses, same reasoning `scopeActive()` needing the
     * subscription-currency check documents.
     */
    public function currentActiveSubscription(): ?Subscription
    {
        return $this->subscriptions()
            ->where('status', 'active')
            ->where('end_date', '>=', now())
            ->with('plan.quota')
            ->latest('end_date')
            ->first();
    }

    /**
     * Visible to customers only when active and not suspended — and, per
     * SPEC section 4.4, only alongside an unexpired subscription, which the
     * matching query adds.
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active')->where('is_suspended', false);
    }

    /**
     * The admin verification queue (SPEC section 5.8) — self-registered
     * vendors awaiting Approve/Reject.
     */
    public function scopePendingVerification($query)
    {
        return $query->where('status', 'pending_verification');
    }
}
