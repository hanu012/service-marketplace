<?php

namespace App\Models;

use App\Models\Concerns\PreventsDeletionWhileSubscribed;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Query\Expression;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

/**
 * A geographic zone (SPEC section 8). Self-referencing: a main zone such as
 * Ahmedabad contains sub-zones like Gota, Ranip and Sola.
 *
 * The `polygon` column is raw geometry. Always write it through
 * ST_GeomFromText(..., 4326) — MariaDB 10.4 cannot declare the SRID on the
 * column, so it only exists on the values. See the zones migration.
 */
class Zone extends Model
{
    use HasFactory;
    use PreventsDeletionWhileSubscribed;

    protected $fillable = [
        'parent_id',
        'name',
        'slug',
        'polygon',
        'pincode',
        'is_active',
    ];

    /**
     * Geometry is binary and meaningless to the app layer; it is only ever
     * used inside spatial SQL. Hiding it keeps it out of API responses and
     * out of accidental JSON casts.
     */
    protected $hidden = ['polygon'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(Zone::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(Zone::class, 'parent_id');
    }

    public function subscriptionItemType(): string
    {
        return 'zone';
    }

    /**
     * A zone with no children — the only kind that matches or counts against
     * quota (SPEC section 8, leaf-only matching). Parent zones exist for
     * navigation and grouping.
     */
    public function isLeaf(): bool
    {
        return ! $this->children()->exists();
    }

    /**
     * Every zone beneath this one, at any depth.
     *
     * Walks level by level rather than recursing per node, so the whole
     * subtree costs one query per level instead of one per zone. The seen-set
     * also stops a cycle (a zone somehow made its own ancestor) from looping
     * forever — `parent_id` has no constraint preventing that.
     *
     * @return array<int, int>
     */
    public function descendantIds(): array
    {
        $found = [];
        $frontier = [$this->getKey()];

        while ($frontier !== []) {
            $children = static::query()
                ->whereIn('parent_id', $frontier)
                ->whereNotIn('id', $found)
                ->pluck('id')
                ->all();

            if ($children === []) {
                break;
            }

            $found = array_merge($found, $children);
            $frontier = $children;
        }

        return $found;
    }

    /**
     * A parent's "in use" count includes every descendant's subscriptions.
     *
     * SPEC section 8: deactivating a busy parent silently drops every
     * descendant out of matching, because effective active status is
     * `own is_active AND (no parent OR parent.is_active)`. So the parent's own
     * row being unreferenced says nothing about the damage — the warning has
     * to reflect the subtree. Same pattern as Category counting its
     * subcategories.
     *
     * @return array<int, array{type: string, ids: array<int, int>}>
     */
    protected function additionalSubscriptionReferences(): array
    {
        return [[
            'type' => 'zone',
            'ids' => $this->descendantIds(),
        ]];
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * Adds the polygon back as WKT, since selecting the raw geometry column
     * returns binary that is useless to the app layer.
     */
    public function scopeWithPolygonWkt($query)
    {
        return $query->addSelect(['*'])
            ->selectRaw('ST_AsText(polygon) as polygon_wkt');
    }

    /**
     * Builds the SQL expression that writes this zone's boundary.
     *
     * COORDINATE ORDER — the one thing to get right in this file.
     *
     * WKT is "lng lat" (X then Y). Leaflet hands back lat/lng, and GeoJSON
     * uses [lng, lat]. Swapping them produces a polygon that is still
     * geometrically valid and still saves without error — it just sits in the
     * Gulf of Guinea instead of Ahmedabad, and nothing complains until a
     * customer search silently matches no vendors.
     *
     * So the swap happens here and nowhere else. Input is an array of points
     * with explicit keys, never bare pairs, so a caller cannot transpose them
     * by accident.
     *
     * SQL SAFETY: the returned expression carries no caller-supplied string.
     * Every coordinate is validated as a number and re-formatted with
     * sprintf, so the WKT handed to ST_GeomFromText contains only digits,
     * signs, dots, commas, spaces and parentheses.
     *
     * @param  array<int, array{lat: float|string, lng: float|string}>  $points
     *
     * @throws \InvalidArgumentException
     */
    public static function polygonExpression(array $points): Expression
    {
        return DB::raw("ST_GeomFromText('".static::polygonWktFrom($points)."', 4326)");
    }

    /**
     * Validates a ring and renders it as WKT.
     *
     * @param  array<int, array{lat: float|string, lng: float|string}>  $points
     *
     * @throws \InvalidArgumentException
     */
    public static function polygonWktFrom(array $points): string
    {
        $points = array_values($points);

        if (count($points) < 3) {
            throw new InvalidArgumentException(
                'A zone boundary needs at least 3 distinct points.'
            );
        }

        $ring = [];

        foreach ($points as $index => $point) {
            if (! isset($point['lat'], $point['lng']) || ! is_numeric($point['lat']) || ! is_numeric($point['lng'])) {
                throw new InvalidArgumentException(
                    "Point {$index} is missing a numeric lat/lng."
                );
            }

            $lat = (float) $point['lat'];
            $lng = (float) $point['lng'];

            if ($lat < -90 || $lat > 90) {
                throw new InvalidArgumentException("Latitude {$lat} is out of range.");
            }

            if ($lng < -180 || $lng > 180) {
                throw new InvalidArgumentException("Longitude {$lng} is out of range.");
            }

            // "lng lat" — X then Y. See the note above.
            $ring[] = sprintf('%.8F %.8F', $lng, $lat);
        }

        // A WKT ring must close: last point identical to the first. Leaflet
        // does not repeat it, so close it here rather than asking every
        // caller to remember.
        if ($ring[0] !== end($ring)) {
            $ring[] = $ring[0];
        }

        return 'POLYGON(('.implode(',', $ring).'))';
    }

    /**
     * Turns stored WKT back into points for the map field.
     *
     * @return array<int, array{lat: float, lng: float}>
     */
    public static function pointsFromWkt(?string $wkt): array
    {
        if ($wkt === null || ! preg_match('/^POLYGON\(\((.*)\)\)$/i', trim($wkt), $matches)) {
            return [];
        }

        $points = [];

        foreach (explode(',', $matches[1]) as $pair) {
            $parts = preg_split('/\s+/', trim($pair));

            if (count($parts) < 2 || ! is_numeric($parts[0]) || ! is_numeric($parts[1])) {
                continue;
            }

            // Reverse of the write path: WKT is "lng lat".
            $points[] = ['lat' => (float) $parts[1], 'lng' => (float) $parts[0]];
        }

        // Drop the repeated closing point — the map draws an open ring.
        if (count($points) > 1 && $points[0] == end($points)) {
            array_pop($points);
        }

        return $points;
    }
}
