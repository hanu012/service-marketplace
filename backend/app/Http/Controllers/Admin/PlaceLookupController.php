<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Server-side proxy for Google Places, used by the zone map's search box.
 *
 * The browser never sees the key. A Places key is billable and an
 * unrestricted one rendered into a page is one anybody can lift and
 * spend — so the admin asks us, and we ask Google.
 *
 * Admin-only (see the route's middleware). Without that this would be an
 * open, unmetered geocoding service running on someone else's bill.
 *
 * Two steps, because that is how Google bills it: autocomplete returns
 * predictions with no coordinates, and only the prediction the admin
 * actually picks costs a Details lookup. Resolving every prediction up
 * front would multiply the bill by the length of the list.
 */
class PlaceLookupController extends Controller
{
    private const AUTOCOMPLETE_URL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';

    private const DETAILS_URL = 'https://maps.googleapis.com/maps/api/place/details/json';

    private const TIMEOUT_SECONDS = 8;

    /**
     * Predictions for what the admin has typed so far.
     */
    public function autocomplete(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:200'],
            // Groups a typing session into one billable autocomplete
            // rather than one per keystroke. Supplied by the browser.
            'session' => ['nullable', 'string', 'max:64'],
        ]);

        $key = $this->key();

        if ($key === null) {
            return response()->json(['predictions' => [], 'error' => null]);
        }

        $query = [
            'input' => $validated['q'],
            'key' => $key,
        ];

        if (filled($validated['session'] ?? null)) {
            $query['sessiontoken'] = $validated['session'];
        }

        if (filled(config('map.geocode_country'))) {
            $query['components'] = 'country:'.config('map.geocode_country');
        }

        $response = Http::timeout(self::TIMEOUT_SECONDS)->get(self::AUTOCOMPLETE_URL, $query);

        if ($response->failed()) {
            return $this->unavailable('Place search is unavailable right now.');
        }

        $body = $response->json();
        $status = $body['status'] ?? 'UNKNOWN';

        if (! in_array($status, ['OK', 'ZERO_RESULTS'], true)) {
            // Logged rather than shown: Google's message can name the key
            // and the reason it was refused, which is not for the browser.
            Log::warning('Places autocomplete failed', [
                'status' => $status,
                'message' => $body['error_message'] ?? null,
            ]);

            return $this->unavailable('Place search is unavailable right now.');
        }

        return response()->json([
            'predictions' => collect($body['predictions'] ?? [])
                ->map(fn (array $prediction) => [
                    'id' => $prediction['place_id'] ?? null,
                    'main' => $prediction['structured_formatting']['main_text']
                        ?? $prediction['description']
                        ?? '',
                    'secondary' => $prediction['structured_formatting']['secondary_text'] ?? '',
                    'label' => $prediction['description'] ?? '',
                ])
                ->filter(fn (array $prediction) => filled($prediction['id']))
                ->values()
                ->all(),
            'error' => null,
        ]);
    }

    /**
     * The coordinates behind one prediction, plus the viewport Google
     * suggests for it — so selecting a suburb frames the suburb rather
     * than dropping a fixed zoom on its centre point.
     */
    public function details(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'place_id' => ['required', 'string', 'max:255'],
            'session' => ['nullable', 'string', 'max:64'],
        ]);

        $key = $this->key();

        if ($key === null) {
            return $this->unavailable('Place lookup is not configured.');
        }

        $query = [
            'place_id' => $validated['place_id'],
            'key' => $key,
            // Billed by field group: geometry and the name are all this
            // screen uses.
            'fields' => 'geometry,name,formatted_address',
        ];

        if (filled($validated['session'] ?? null)) {
            $query['sessiontoken'] = $validated['session'];
        }

        $response = Http::timeout(self::TIMEOUT_SECONDS)->get(self::DETAILS_URL, $query);

        if ($response->failed()) {
            return $this->unavailable('Could not look that place up.');
        }

        $body = $response->json();

        if (($body['status'] ?? null) !== 'OK') {
            Log::warning('Place details failed', [
                'status' => $body['status'] ?? 'UNKNOWN',
                'message' => $body['error_message'] ?? null,
            ]);

            return $this->unavailable('Could not look that place up.');
        }

        $geometry = $body['result']['geometry'] ?? [];
        $location = $geometry['location'] ?? null;

        if (! isset($location['lat'], $location['lng'])) {
            return $this->unavailable('That place has no coordinates.');
        }

        return response()->json([
            'place' => [
                'label' => $body['result']['formatted_address']
                    ?? $body['result']['name']
                    ?? '',
                'lat' => (float) $location['lat'],
                'lng' => (float) $location['lng'],
                'viewport' => $this->viewport($geometry['viewport'] ?? null),
            ],
            'error' => null,
        ]);
    }

    /**
     * @return array{south: float, west: float, north: float, east: float}|null
     */
    private function viewport(?array $viewport): ?array
    {
        if (! isset(
            $viewport['southwest']['lat'],
            $viewport['southwest']['lng'],
            $viewport['northeast']['lat'],
            $viewport['northeast']['lng'],
        )) {
            return null;
        }

        return [
            'south' => (float) $viewport['southwest']['lat'],
            'west' => (float) $viewport['southwest']['lng'],
            'north' => (float) $viewport['northeast']['lat'],
            'east' => (float) $viewport['northeast']['lng'],
        ];
    }

    private function key(): ?string
    {
        $key = config('map.google_api_key');

        return filled($key) ? (string) $key : null;
    }

    private function unavailable(string $message): JsonResponse
    {
        return response()->json(['predictions' => [], 'place' => null, 'error' => $message], 200);
    }
}
