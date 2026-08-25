{{--
    Leaflet + Leaflet.draw polygon editor.

    Leaflet itself is vendored locally (see AdminPanelProvider's asset
    registration); only the raster tiles are fetched remotely, from the
    configurable URL in config/map.php.

    State is an array of {lat, lng} objects. The lat/lng swap into WKT happens
    server-side in Zone::polygonExpression() and nowhere else.
--}}
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
        <div
            x-ref="map"
            style="height: {{ $getHeight() }}px"
            class="w-full rounded-lg border border-gray-300 dark:border-gray-600 z-0"
        ></div>

        <div class="flex items-center justify-between text-sm">
            <span
                x-show="pointCount === 0"
                class="text-gray-500 dark:text-gray-400"
            >
                Use the polygon tool on the left to draw this zone's boundary. A rough
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
    Alpine.data('polygonMap', ({ state, tileUrl, attribution, maxZoom, defaultView, disabled }) => ({
        state,
        disabled,
        map: null,
        layer: null,
        pointCount: 0,

        init() {
            this.map = L.map(this.$refs.map).setView(
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

            // Filament renders the form inside a panel that sizes after paint;
            // without this the map draws into a zero-height box and shows grey.
            setTimeout(() => this.map.invalidateSize(), 200);
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
