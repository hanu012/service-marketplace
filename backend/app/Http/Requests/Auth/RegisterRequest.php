<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255'],

            // Not scoped withoutTrashed(): the users table carries a real
            // unique index on email that soft-deleted rows still occupy, so
            // validation has to match the constraint the database enforces.
            'email' => ['required', 'string', 'email:rfc', 'max:255', Rule::unique('users', 'email')],

            'password' => ['required', 'confirmed', Password::defaults()],
            'device_name' => ['required', 'string', 'max:255'],

            // SPEC section 1: only vendors and customers may self-register.
            // Admin and salesman accounts are created by an admin, so those
            // roles must never be accepted here.
            'role' => ['required', 'string', Rule::in(['vendor', 'customer'])],

            // vendors.business_name and vendors.phone are NOT NULL (phone
            // also unique) — a self-registered vendor needs both to get a
            // real Vendor row, not just a users row. Absent/ignored for a
            // customer registration. owner_name is NOT a separate field:
            // it is just `name`, same as the salesman-led flow already
            // treats the two as the same value (VendorDraftService).
            'business_name' => ['required_if:role,vendor', 'string', 'max:255'],

            // Not scoped withoutTrashed(): Rule::unique queries the raw
            // table, not through Vendor's SoftDeletes global scope, so a
            // trashed row's phone is already caught — same reasoning as
            // the email rule above.
            'phone' => ['required_if:role,vendor', 'string', 'max:20', Rule::unique('vendors', 'phone')],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'role.in' => 'Only vendor and customer accounts can be self-registered.',
        ];
    }
}
