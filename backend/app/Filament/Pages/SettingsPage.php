<?php

namespace App\Filament\Pages;

use App\Models\Setting;
use App\Support\Languages;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Facades\Auth;

/**
 * Settings (SPEC section 5 item 17) — a single fixed-key edit page,
 * not a Resource: there is no create/delete, only 5 named values to
 * change. The first form-only custom Filament Page in this app
 * (LeadsAnalytics/CommissionPayouts are custom Pages too, but both
 * use HasTable; this one has no table at all, just HasForms).
 *
 * force_update_version and maintenance_mode are edited here but
 * DELIBERATELY NOT ENFORCED anywhere yet — grepped the whole repo
 * (backend + mobile/): no API middleware gate, no Flutter check of
 * either value at all. Confirmed by SettingController's and
 * SettingSeeder's own docblocks saying the same. This page makes
 * them admin-editable, not functional — flagged in the form's own
 * helper text so an admin using the panel isn't misled, not just in
 * this comment.
 */
class SettingsPage extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationLabel = 'Settings';

    protected static ?string $navigationGroup = 'System';

    protected static string $view = 'filament.pages.settings-page';

    /**
     * @var array<string, mixed>|null
     */
    public ?array $data = [];

    /**
     * The 5 keys SPEC section 5.17 names. Fixed, not dynamically
     * discovered from the settings table — a new key needs a
     * deliberate addition here, not an automatic appearance on this
     * page.
     *
     * @var array<int, string>
     */
    private const KEYS = [
        // free_grants_per_salesman_month and grace_period_days are left off
        // the page on purpose (client request). They are still enforced at
        // their stored values; leaving them out of this list is what keeps
        // Save from overwriting them with nulls.
        'free_trial_max_days',
        'force_update_version',
        'maintenance_mode',
        'enabled_languages',
    ];

    public static function canAccess(): bool
    {
        return Auth::user()?->can('viewAny', Setting::class) ?? false;
    }

    public function mount(): void
    {
        $this->form->fill([
            'free_trial_max_days' => Setting::get('free_trial_max_days'),
            'force_update_version' => Setting::get('force_update_version'),
            'maintenance_mode' => Setting::get('maintenance_mode', false),
            'enabled_languages' => Languages::enabled(),
        ]);
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('Subscriptions')
                    ->description('Enforced when a salesman grants a free trial.')
                    ->schema([
                        TextInput::make('free_trial_max_days')
                            ->label('Maximum free trial length (days)')
                            ->numeric()
                            ->minValue(1)
                            ->required(),
                    ])
                    ->columns(3),

                Section::make('App')
                    ->description('Minimum app version and maintenance mode are not enforced anywhere yet — editable here ahead of that work. Enabled languages is live.')
                    ->schema([
                        TextInput::make('force_update_version')
                            ->label('Minimum app version')
                            ->required()
                            ->maxLength(255)
                            ->rule('regex:/^\d+\.\d+\.\d+$/')
                            ->helperText('x.y.z format. Not enforced by any app yet.'),

                        Toggle::make('maintenance_mode')
                            ->label('Maintenance mode')
                            ->helperText('Not enforced by any app yet.'),

                        CheckboxList::make('enabled_languages')
                            ->label('Enabled languages')
                            ->options(Languages::SUPPORTED)
                            // English is the fallback for every missing
                            // translation, so it cannot be switched off.
                            ->disableOptionWhen(fn (string $value): bool => $value === Languages::ENGLISH)
                            ->columns(3)
                            ->helperText('Offered in each app under Profile → Language. English is always on. Someone using a language you switch off is moved back to English.')
                            ->columnSpanFull(),
                    ])
                    ->columns(2),
            ])
            ->statePath('data');
    }

    public function save(): void
    {
        abort_unless(Auth::user()?->can('update', Setting::class), 403);

        $data = $this->form->getState();

        $settings = Setting::query()->whereIn('key', self::KEYS)->get()->keyBy('key');

        foreach (self::KEYS as $key) {
            $setting = $settings->get($key);

            // Missing row (never seeded) or explicitly excluded from
            // the admin UI (is_editable = false) — skip rather than
            // create one or silently overwrite a deploy-only value.
            if ($setting === null || ! $setting->is_editable) {
                continue;
            }

            // A real Eloquent update() per row, not a mass
            // query-builder update — RecordsAuditLog only fires on
            // the former, and settings changes are exactly the kind
            // of governance-sensitive edit SPEC section 5.14 wants
            // logged.
            $setting->update([
                'value' => $this->stringify($data[$key] ?? null, $setting->type),
            ]);
        }

        Notification::make()
            ->title('Settings saved')
            ->success()
            ->send();
    }

    private function stringify(mixed $value, string $type): ?string
    {
        if ($type === 'boolean') {
            return $value ? 'true' : 'false';
        }

        if ($type === 'json') {
            return json_encode(array_values((array) $value));
        }

        return $value === null ? null : (string) $value;
    }
}
