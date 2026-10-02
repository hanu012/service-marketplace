<?php

namespace App\Http\Requests\User;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePreferencesRequest extends FormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Restricted to what the apps actually bundle translations for
            // (assets/translations) — accepting an arbitrary tag would let
            // a client set a locale that then falls back silently forever.
            'language' => ['sometimes', 'required', 'string', 'in:en'],
            'enable_notification' => ['sometimes', 'required', 'boolean'],
        ];
    }
}
