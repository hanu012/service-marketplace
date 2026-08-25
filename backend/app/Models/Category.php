<?php

namespace App\Models;

use App\Models\Concerns\PreventsDeletionWhileSubscribed;
use App\Models\Concerns\TracksFileDisk;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    use HasFactory;
    use PreventsDeletionWhileSubscribed;
    use TracksFileDisk;

    protected $fillable = [
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

    public function subcategories(): HasMany
    {
        return $this->hasMany(Subcategory::class);
    }

    public function subscriptionItemType(): string
    {
        return 'category';
    }

    /**
     * Subcategories cascade at the database level when a category is deleted,
     * which never fires their own model events. So a category is also blocked
     * when any of its subcategories are subscribed to — otherwise deleting
     * the parent is a way around the child's guard.
     *
     * @return array<int, array{type: string, ids: array<int, int>}>
     */
    protected function additionalSubscriptionReferences(): array
    {
        return [[
            'type' => 'subcategory',
            'ids' => $this->subcategories()->pluck('id')->all(),
        ]];
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
