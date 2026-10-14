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

    /*
    |--------------------------------------------------------------------------
    | Place search
    |--------------------------------------------------------------------------
    |
    | Google Places backs the zone map's search box, so an admin can type
    | an address and jump to it. Google is used rather than OpenStreetMap's
    | Nominatim because it knows individual buildings and apartment blocks
    | that OSM does not — the difference between finding a named apartment
    | and having to settle for the suburb around it. Nominatim also matches
    | a pasted address literally, returning nothing at all when one
    | component is unknown to it.
    |
    | The key is used SERVER-SIDE ONLY, proxied through
    | PlaceLookupController. It is never rendered into the admin page: a
    | Places key is billable, and one sitting in HTML is one anybody can
    | lift and spend. That proxy is admin-only for the same reason.
    |
    | Leave empty and the search box is hidden — the map still draws and
    | the polygon tools still work, there is simply nothing to search with.
    |
    */

    'google_api_key' => env('GOOGLE_MAPS_API_KEY'),

    /*
    | Biases results towards one country, as an ISO 3166-1 alpha-2 code.
    | Empty searches worldwide.
    */

    'geocode_country' => env('MAP_GEOCODE_COUNTRY', 'in'),

];
