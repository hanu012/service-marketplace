<?php

namespace App\Http\Requests\Customer;

use Illuminate\Foundation\Http\FormRequest;

/**
 * What a customer may change about their own record — name and phone.
 *
 * Email is the login identity and stays admin-only, same as for salesmen
 * (UpdateSalesmanProfileRequest). Both fields are `sometimes`, so the app
 * can PATCH one without resending the other.
 */
class UpdateCustomerProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Route is role:customer and the controller only touches
        // $request->user()->customer — there is no id to tamper with.
        return $this->user()?->customer !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            // Nullable: customers.phone is optional, so clearing it is a
            // legitimate edit rather than a validation error.
            'phone' => ['sometimes', 'nullable', 'string', 'max:20', 'regex:/^[0-9+\-\s]{6,20}$/'],
        ];
    }
}
