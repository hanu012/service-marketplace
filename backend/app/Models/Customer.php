<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Customer profile, 1:1 with a user carrying role = customer.
 *
 * Every field is optional: SPEC section 4.1 asks only for email and password
 * to sign up, and location is captured later from GPS or a pincode fallback
 * (section 4.2).
 */
class Customer extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'user_id',
        'phone',
        'latitude',
        'longitude',
        'pincode',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(Favorite::class);
    }

    /**
     * Shared by VendorSearchResource and VendorDetailResource so
     * "is this vendor favorited" is defined once, not duplicated per
     * resource.
     */
    public function hasFavorited(int $vendorId): bool
    {
        return $this->favorites()->where('vendor_id', $vendorId)->exists();
    }

    public function reports(): HasMany
    {
        return $this->hasMany(Report::class);
    }
}
