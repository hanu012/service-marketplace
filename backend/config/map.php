<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Basemap tiles
    |--------------------------------------------------------------------------
    |
    | Raster tile source for the zone-drawing map in the admin panel. Leaflet
    | itself is vendored locally, but tiles are necessarily fetched from a
    | server — an admin needs to see roads and landmarks to know where a zone
    | actually ends.
    |
    | Defaults to OpenStreetMap's public tile server. That is fine for an
    | admin drawing a few dozen zones, but their tile usage policy does not
    | cover sustained production use. This is configurable precisely so that
    | swap is a config change rather than a code change — see the Before
    | Launch Checklist in PROGRESS.md.
    |
    */

    'tile_url' => env('MAP_TILE_URL', 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),

    'tile_attribution' => env(
        'MAP_TILE_ATTRIBUTION',
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    ),

    'max_zoom' => (int) env('MAP_MAX_ZOOM', 19),

    /*
    |--------------------------------------------------------------------------
    | Default view
    |--------------------------------------------------------------------------
    |
    | Where the map opens when drawing a new zone. Ahmedabad, matching the
    | worked examples in SPEC sections 3.4 and 5.3.
    |
    */

    'default_latitude' => (float) env('MAP_DEFAULT_LAT', 23.0225),
    'default_longitude' => (float) env('MAP_DEFAULT_LNG', 72.5714),
    'default_zoom' => (int) env('MAP_DEFAULT_ZOOM', 11),

];
