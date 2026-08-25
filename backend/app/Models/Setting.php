<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Admin-editable settings (SPEC section 5.17), key-value with a declared
 * type so callers can read a typed value without re-parsing `value` (raw
 * text) themselves every time.
 *
 * Phase 3's salesman flow reads its business rules from here rather than
 * hardcoding them — see the settings migration for the full documented key
 * list.
 */
class Setting extends Model
{
    protected $fillable = [
        'key',
        'value',
        'type',
        'group',
        'label',
        'description',
        'is_editable',
    ];

    protected function casts(): array
    {
        return [
            'is_editable' => 'boolean',
        ];
    }

    /**
     * Reads a setting, cast per its declared `type`. Returns $default when
     * the key is missing entirely — this is the common path in a freshly
     * seeded or partially seeded environment, not an error.
     */
    public static function get(string $key, mixed $default = null): mixed
    {
        $setting = static::query()->where('key', $key)->first();

        if ($setting === null || $setting->value === null) {
            return $default;
        }

        return match ($setting->type) {
            'integer' => (int) $setting->value,
            'boolean' => filter_var($setting->value, FILTER_VALIDATE_BOOLEAN),
            'json' => json_decode($setting->value, true),
            default => $setting->value,
        };
    }
}
