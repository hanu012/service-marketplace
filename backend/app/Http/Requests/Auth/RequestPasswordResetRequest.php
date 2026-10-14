<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class RequestPasswordResetRequest extends FormRequest
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
        return [
            // Deliberately no `exists:users,email`: the response must be the
            // same whether or not the address has an account, or this
            // endpoint becomes a way to test which emails are registered.
            'email' => ['required', 'string', 'email', 'max:255'],
        ];
    }
}
