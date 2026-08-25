<?php

namespace App\Models;

use App\Models\Concerns\PreventsDeletionWhileSubscribed;
use App\Models\Concerns\TracksFileDisk;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The unit vendor matching actually happens on (SPEC section 4.4) — a vendor
 * who does AC gas filling may not do AC installation.
 */
class Subcategory extends Model
{
    use HasFactory;
    use PreventsDeletionWhileSubscribed;
    use TracksFileDisk;

    protected $fillable = [
        'category_id',
        'name',
        'slug',
        'icon',
        'disk',
        'sort_order',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function subscriptionItemType(): string
    {
        return 'subcategory';
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
