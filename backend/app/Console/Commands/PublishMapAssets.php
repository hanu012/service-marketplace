<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

/**
 * Copies Leaflet's image folders next to the stylesheets Filament
 * publishes.
 *
 * `filament:assets` copies each registered Css/Js file and nothing else,
 * but leaflet.css and leaflet.draw.css both reference `images/...`
 * relative to themselves. Without the folder beside them every sprite
 * 404s, which shows up as a toolbar of blank white squares rather than
 * as an error — the draw, edit and delete buttons simply have no icons.
 *
 * An Artisan command rather than a copy at boot: this is a one-off
 * deployment step, and a provider that writes to public/ on every
 * request is both wasteful and wrong on a read-only filesystem.
 * Registered in composer.json's post-autoload-dump, right after
 * `filament:upgrade` republishes the stylesheets it pairs with.
 */
class PublishMapAssets extends Command
{
    protected $signature = 'map:publish-assets';

    protected $description = "Copy Leaflet's sprite images next to the published stylesheets";

    /**
     * Source folder => the published stylesheet it belongs to.
     *
     * Filament writes registered assets to public/css/<package>/<id>.css,
     * so the images go in public/css/<package>/images.
     */
    private const SOURCES = [
        'node_modules/leaflet/dist/images' => 'css/app/images',
        'node_modules/leaflet-draw/dist/images' => 'css/app/images',
    ];

    public function handle(): int
    {
        $copied = 0;

        foreach (self::SOURCES as $from => $to) {
            $source = base_path($from);

            if (! File::isDirectory($source)) {
                // npm install has not run. Not fatal: the panel still
                // works, the icons are just missing, and saying so beats
                // failing a deploy over it.
                $this->warn("Skipped {$from} — not installed.");

                continue;
            }

            $destination = public_path($to);
            File::ensureDirectoryExists($destination);

            foreach (File::files($source) as $file) {
                File::copy(
                    $file->getPathname(),
                    $destination.DIRECTORY_SEPARATOR.$file->getFilename()
                );
                $copied++;
            }
        }

        $this->info("Published {$copied} map image(s).");

        return self::SUCCESS;
    }
}
