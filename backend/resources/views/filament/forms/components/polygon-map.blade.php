{{--
    Leaflet + Leaflet.draw polygon editor.

    Leaflet itself is vendored locally (see AdminPanelProvider's asset
    registration); only the raster tiles and the geocoder are fetched
    remotely, from the configurable URLs in config/map.php. No CDN scripts
    — CLAUDE.md rules those out for this panel.

    State is an array of {lat, lng} objects. The lat/lng swap into WKT happens
    server-side in Zone::polygonExpression() and nowhere else.
--}}
{{--
    Fullscreen sizing lives here rather than in Alpine state: the browser
    applies :fullscreen itself, so the map cannot be left at a stale size
    if a transition is interrupted or Escape is pressed.
--}}
<style>
    .zone-map-wrapper:fullscreen {
        width: 100vw;
        height: 100vh;
        border-radius: 0;
    }

    .zone-map-wrapper:fullscreen > div {
        height: 100% !important;
        border-radius: 0;
        border: 0;
    }
</style>

<x-dynamic-component :component="$getFieldWrapperView()" :field="$field">
    <div
        wire:ignore
        x-data="polygonMap({
            state: $wire.$entangle('{{ $getStatePath() }}'),
            tileUrl: @js($getTileUrl()),
            attribution: @js($getTileAttribution()),
            maxZoom: @js($getMaxZoom()),
            defaultView: @js($getMapCenter()),
            disabled: @js($isDisabled()),
        })"
        x-init="init()"
        class="space-y-2"
    >
        @if ($hasPlaceSearch())
            {{--
                A plain input above the map rather than a Leaflet control:
                the map's corners are already spoken for by the zoom, draw
                and view controls, and a Tailwind-styled field here matches
                the rest of the form.
            --}}
            <div class="relative" style="z-index: 1200">
                <div class="flex gap-2">
                    <div class="relative flex-1">
                        <input
                            type="text"
                            x-model="searchQuery"
                            x-on:input="onQueryInput()"
                            x-on:keydown.enter.prevent="searchPlace()"
                            x-on:keydown.escape="searchResults = []"
                            placeholder="Search a place to jump to — building, road, area or pincode"
                            class="block w-full rounded-lg border-gray-300 bg-white py-2 pl-9 pr-3 text-sm shadow-sm placeholder:text-gray-400 focus:border-primary-500 focus:ring-1 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-200 dark:placeholder:text-gray-500"
                        />
                        <svg
                            class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400"
                            fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"
                        >
                            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-4.35-4.35M17 11a6 6 0 11-12 0 6 6 0 0112 0z" />
                        </svg>
                    </div>

                    <button
                        type="button"
                        x-on:click="searchPlace()"
                        x-bind:disabled="isSearching"
                        class="rounded-lg bg-primary-600 px-4 py-2 text-sm font-medium text-white hover:bg-primary-500 disabled:opacity-60"
                    >
                        <span x-show="! isSearching">Search</span>
                        <span x-show="isSearching" x-cloak>Searching…</span>
                    </button>
                </div>

                {{--
                    Results sit over the map, so a long list never pushes it
                    down. The z-index is inline and high on purpose: Leaflet
                    puts its panes and controls at 400-1000, and no Tailwind
                    build scans this file, so an arbitrary z-[…] class would
                    never be generated.
                --}}
                <ul
                    x-show="searchResults.length > 0"
                    x-cloak
                    x-on:click.outside="searchResults = []"
                    style="z-index: 1200"
                    class="absolute mt-1 max-h-60 w-full overflow-auto rounded-lg border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-gray-800"
                >
                    <template x-for="place in searchResults" :key="place.id">
                        <li>
                            <button
                                type="button"
                                x-on:click="goToPlace(place)"
                                class="block w-full px-3 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-700"
                            >
                                <span
                                    class="block text-sm font-medium text-gray-800 dark:text-gray-100"
                                    x-text="place.main"
                                ></span>
                                <span
                                    x-show="place.secondary"
                                    class="block text-xs text-gray-500 dark:text-gray-400"
                                    x-text="place.secondary"
                                ></span>
                            </button>
                        </li>
                    </template>
                </ul>

                <p
                    x-show="searchError"
                    x-cloak
                    x-text="searchError"
                    class="mt-1 text-sm text-danger-600 dark:text-danger-400"
                ></p>
            </div>
        @endif

        {{--
            The wrapper, not the map element, goes fullscreen — the Leaflet
            controls are children of the map, so taking the map alone would
            leave the search box behind.

            Height is a plain inline style, with fullscreen handled by the
            :fullscreen rule at the top rather than by binding the style.
            Driving the height from Alpine sized the element from stale
            state during the transition, and Leaflet cached that size — the
            map ended up wider than its card and painted over the search box.
        --}}
        <div
            x-ref="wrapper"
            style="z-index: 0"
            class="zone-map-wrapper relative overflow-hidden rounded-lg bg-white dark:bg-gray-900"
        >
            <div
                x-ref="map"
                style="height: {{ $getHeight() }}px"
                class="w-full max-w-full rounded-lg border border-gray-300 dark:border-gray-600 z-0"
            ></div>
        </div>

        <div class="flex items-center justify-between text-sm">
            <span
                x-show="pointCount === 0"
                class="text-gray-500 dark:text-gray-400"
            >
                Use the polygon tool on the right to draw this zone's boundary. A rough
                outline is fine — the zone stays inactive until you switch it on.
            </span>

            <span
                x-show="pointCount > 0"
                x-cloak
                class="text-gray-600 dark:text-gray-300"
            >
                Boundary drawn — <span x-text="pointCount"></span> points.
            </span>

            <button
                type="button"
                x-show="pointCount > 0 && ! disabled"
                x-cloak
                x-on:click="clearPolygon()"
                class="text-danger-600 hover:underline dark:text-danger-400"
            >
                Clear
            </button>
        </div>
    </div>
</x-dynamic-component>

@script
<script>
    Alpine.data('polygonMap', ({
        state,
        tileUrl,
        attribution,
        maxZoom,
        defaultView,
        disabled,
    }) => ({
        state,
        disabled,
        map: null,
        layer: null,
        pointCount: 0,
        searchQuery: '',
        searchResults: [],
        searchError: '',
        isSearching: false,
        marker: null,
        searchDebounce: null,
        searchRequestId: 0,
        sessionToken: null,

        init() {
            this.map = L.map(this.$refs.map, {
                // Zoom stays top-left; the draw toolbar moves to the right
                // below. The two shared a corner before and overlapped.
                zoomControl: true,
            }).setView(
                [defaultView.lat, defaultView.lng],
                defaultView.zoom,
            );

            L.tileLayer(tileUrl, { attribution, maxZoom }).addTo(this.map);

            this.layer = new L.FeatureGroup();
            this.map.addLayer(this.layer);

            this.restoreExisting();

            if (! this.disabled) {
                this.enableDrawing();
            }

            this.addViewControls();

            // Leaving fullscreen by Escape does not fire our button, so the
            // resize has to follow the document's own event. Leaflet caches
            // the container size; without this the map keeps whatever size
            // it had on the other side of the transition.
            this.onFullscreenChange = () => {
                setTimeout(() => this.map.invalidateSize(), 120);
            };
            document.addEventListener('fullscreenchange', this.onFullscreenChange);

            // Filament renders the form inside a panel that sizes after paint;
            // without this the map draws into a zero-height box and shows grey.
            setTimeout(() => this.map.invalidateSize(), 200);
        },

        destroy() {
            document.removeEventListener('fullscreenchange', this.onFullscreenChange);
        },

        restoreExisting() {
            const points = this.state ?? [];

            if (! Array.isArray(points) || points.length < 3) {
                this.pointCount = 0;
                return;
            }

            const polygon = L.polygon(points.map((p) => [p.lat, p.lng]));
            this.layer.addLayer(polygon);
            this.pointCount = points.length;
            this.map.fitBounds(polygon.getBounds(), { padding: [20, 20] });
        },

        enableDrawing() {
            this.map.addControl(new L.Control.Draw({
                // Top-right: the zoom buttons own the top-left, and stacking
                // both there is what cut the lower icons off the container.
                position: 'topright',
                edit: {
                    featureGroup: this.layer,
                    remove: true,
                },
                draw: {
                    // One boundary per zone: everything else is off.
                    polygon: { allowIntersection: false, showArea: true },
                    polyline: false,
                    rectangle: false,
                    circle: false,
                    circlemarker: false,
                    marker: false,
                },
            }));

            this.map.on(L.Draw.Event.CREATED, (event) => {
                // Replace rather than accumulate — a zone has exactly one ring.
                this.layer.clearLayers();
                this.layer.addLayer(event.layer);
                this.sync();
            });

            this.map.on(L.Draw.Event.EDITED, () => this.sync());
            this.map.on(L.Draw.Event.DELETED, () => this.sync());

            // EDITED only fires when the admin presses Save inside
            // Leaflet.draw's own toolbar. Dragging a handle and then
            // going straight to the form's "Save changes" button
            // therefore saved the OLD boundary with no hint anything had
            // been missed. Syncing per vertex drag makes the form state
            // follow the map, so either button saves what is on screen.
            this.map.on(L.Draw.Event.EDITVERTEX, () => this.sync());
            this.map.on(L.Draw.Event.EDITMOVE, () => this.sync());
            this.map.on(L.Draw.Event.EDITRESIZE, () => this.sync());
            this.map.on(L.Draw.Event.EDITSTOP, () => this.sync());
        },

        /**
         * "My location" and "Fullscreen", bottom-right — clear of the zoom
         * buttons and of the draw toolbar.
         */
        addViewControls() {
            const self = this;
            const ViewControls = L.Control.extend({
                options: { position: 'bottomright' },
                onAdd() {
                    const bar = L.DomUtil.create('div', 'leaflet-bar');

                    const locate = L.DomUtil.create('a', '', bar);
                    locate.href = '#';
                    locate.title = 'Go to my current location';
                    locate.innerHTML = '&#9678;';
                    locate.style.fontSize = '18px';
                    locate.style.textAlign = 'center';

                    const full = L.DomUtil.create('a', '', bar);
                    full.href = '#';
                    full.title = 'Toggle fullscreen';
                    full.innerHTML = '&#9974;';
                    full.style.fontSize = '16px';
                    full.style.textAlign = 'center';

                    // Without this a click on the control also pans the map
                    // underneath it.
                    L.DomEvent.disableClickPropagation(bar);
                    L.DomEvent.on(locate, 'click', L.DomEvent.preventDefault)
                        .on(locate, 'click', () => self.goToCurrentLocation());
                    L.DomEvent.on(full, 'click', L.DomEvent.preventDefault)
                        .on(full, 'click', () => self.toggleFullscreen());

                    return bar;
                },
            });

            this.map.addControl(new ViewControls());
        },

        async toggleFullscreen() {
            try {
                if (document.fullscreenElement === this.$refs.wrapper) {
                    await document.exitFullscreen();
                } else {
                    await this.$refs.wrapper.requestFullscreen();
                }
            } catch (error) {
                // Refused (permissions policy, or an unsupported browser) —
                // the map is still perfectly usable at its normal size.
                this.searchError = 'Fullscreen is not available in this browser.';
            }
        },

        goToCurrentLocation() {
            if (! navigator.geolocation) {
                this.searchError = 'This browser cannot report a location.';
                return;
            }

            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.searchError = '';
                    this.map.setView(
                        [position.coords.latitude, position.coords.longitude],
                        15,
                    );
                    this.dropMarker(
                        position.coords.latitude,
                        position.coords.longitude,
                        'You are here',
                    );
                },
                () => {
                    // Browsers only expose geolocation on a secure origin.
                    // localhost counts; a plain-HTTP LAN address does not,
                    // which is the usual reason this fails in development.
                    this.searchError =
                        'Could not get your location. Allow location access, and note that browsers only offer it over HTTPS or on localhost.';
                },
                { enableHighAccuracy: true, timeout: 10000 },
            );
        },

        /** Debounced typeahead — fires as the admin types. */
        onQueryInput() {
            clearTimeout(this.searchDebounce);
            this.searchError = '';

            if (this.searchQuery.trim().length < 2) {
                this.searchResults = [];
                return;
            }

            this.searchDebounce = setTimeout(() => this.searchPlace(), 300);
        },

        async searchPlace() {
            const term = this.searchQuery.trim();

            this.searchError = '';

            if (term.length < 2) {
                this.searchResults = [];
                return;
            }

            // One token per typing session: Google bills a session as a
            // single autocomplete plus the one Details lookup for the
            // prediction actually chosen, rather than per keystroke.
            this.sessionToken ??= crypto.randomUUID();

            const requestId = ++this.searchRequestId;
            this.isSearching = true;

            try {
                const url = new URL(@js(route('admin.places.autocomplete')));
                url.searchParams.set('q', term);
                url.searchParams.set('session', this.sessionToken);

                const response = await fetch(url, {
                    headers: { 'Accept': 'application/json' },
                });

                // A newer keystroke has issued a newer request; this is stale.
                if (requestId !== this.searchRequestId) {
                    return;
                }

                if (! response.ok) {
                    throw new Error(response.statusText);
                }

                const body = await response.json();

                if (body.error) {
                    this.searchResults = [];
                    this.searchError = body.error;
                    return;
                }

                this.searchResults = body.predictions ?? [];

                if (this.searchResults.length === 0) {
                    this.searchError = 'No places matched that search.';
                }
            } catch (error) {
                if (requestId !== this.searchRequestId) {
                    return;
                }

                this.searchResults = [];
                this.searchError = 'Place search is unavailable right now.';
            } finally {
                if (requestId === this.searchRequestId) {
                    this.isSearching = false;
                }
            }
        },

        /**
         * Resolve the chosen prediction and fly to it.
         *
         * Predictions carry no coordinates — Google only returns those
         * from a Details lookup, billed separately — so the request is
         * made for the one the admin actually picked, not for all six.
         */
        async goToPlace(prediction) {
            this.searchResults = [];
            this.searchError = '';
            this.isSearching = true;

            try {
                const url = new URL(@js(route('admin.places.details')));
                url.searchParams.set('place_id', prediction.id);

                if (this.sessionToken) {
                    url.searchParams.set('session', this.sessionToken);
                }

                const response = await fetch(url, {
                    headers: { 'Accept': 'application/json' },
                });

                if (! response.ok) {
                    throw new Error(response.statusText);
                }

                const body = await response.json();

                if (body.error || ! body.place) {
                    this.searchError = body.error ?? 'Could not look that place up.';
                    return;
                }

                const place = body.place;

                // Google's own viewport where it has one, so picking a
                // suburb frames the suburb while picking a building zooms
                // right in — a fixed zoom would be wrong for one of them.
                if (place.viewport) {
                    this.map.fitBounds(
                        [[place.viewport.south, place.viewport.west],
                         [place.viewport.north, place.viewport.east]],
                        { padding: [20, 20], maxZoom: 18 },
                    );
                } else {
                    this.map.setView([place.lat, place.lng], 17);
                }

                this.dropMarker(place.lat, place.lng, place.label || prediction.label);
                this.searchQuery = place.label || prediction.label;
            } catch (error) {
                this.searchError = 'Could not look that place up.';
            } finally {
                // The session ends with the selection; the next search
                // starts a new one.
                this.sessionToken = null;
                this.isSearching = false;
            }
        },

        /**
         * A pin marking where the map was sent. Deliberately not part of
         * [this.layer] — that group is the zone boundary and is what gets
         * saved; a search pin must never end up in the polygon.
         */
        dropMarker(lat, lng, label) {
            if (this.marker) {
                this.map.removeLayer(this.marker);
            }

            this.marker = L.marker([lat, lng]).addTo(this.map);

            if (label) {
                this.marker.bindPopup(label).openPopup();
            }
        },

        sync() {
            const layers = this.layer.getLayers();

            if (layers.length === 0) {
                this.state = [];
                this.pointCount = 0;
                return;
            }

            // getLatLngs() returns an array of rings; a simple polygon has one.
            const ring = layers[0].getLatLngs()[0] ?? [];

            this.state = ring.map((latLng) => ({ lat: latLng.lat, lng: latLng.lng }));
            this.pointCount = this.state.length;
        },

        clearPolygon() {
            this.layer.clearLayers();
            this.sync();
        },
    }));
</script>
@endscript
