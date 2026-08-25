<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class ResendVerificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        // The email is only required when the caller is not authenticated —
        // a signed-in user resending for themselves need not repeat it.
        return [
            'email' => [
                $this->user() ? 'nullable' : 'required',
                'string',
                'email:rfc',
                'max:255',
            ],
        ];
    }
}
