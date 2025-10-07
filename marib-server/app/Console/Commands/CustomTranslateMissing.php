<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;
use Stichoza\GoogleTranslate\GoogleTranslate;

class CustomTranslateMissing extends Command
{
    protected $signature   = 'custom:translate-missing {type : web|panel|json|app} {locale=ar} {--all}';
    protected $description = 'Translate i18n files. Default locale=ar. Use --all to retranslate all keys.';

    public function handle(): int
    {
        $type   = strtolower($this->argument('type'));
        $locale = strtolower($this->argument('locale') ?? 'ar');
        $forceAll = (bool)$this->option('all');

        $map = [
            'web'   => ['base' => 'en_web.json', 'dst' => "{$locale}_web.json"],
            'panel' => ['base' => 'en.json',     'dst' => "{$locale}.json"],
            'json'  => ['base' => 'en.json',     'dst' => "{$locale}.json"], // alias
            'app'   => ['base' => 'en_app.json', 'dst' => "{$locale}_app.json"],
        ];
        if (!isset($map[$type])) {
            $this->error('Invalid type. Allowed: web, panel, json, app');
            return self::FAILURE;
        }

        $base = lang_path($map[$type]['base']);
        $dst  = lang_path($map[$type]['dst']);

        if (!File::exists($base)) {
            $this->error("Base file not found: {$base}");
            return self::FAILURE;
        }
        if (!File::exists(dirname($dst))) {
            File::makeDirectory(dirname($dst), 0775, true);
        }
        if (!File::exists($dst)) {
            File::put($dst, "{}");
        }

        $baseData = json_decode(File::get($base), true) ?: [];
        $dstData  = json_decode(File::get($dst),  true) ?: [];

        // ما سيُترجم
        $todo = [];
        foreach ($baseData as $key => $en) {
            if ($forceAll || !array_key_exists($key, $dstData) || $dstData[$key] === '') {
                $todo[$key] = $en;
            }
        }
        if (empty($todo)) {
            $this->info('No keys to translate.');
            return self::SUCCESS;
        }

        $srcLocale = config('auto-translate.base_locale', 'en');
        $tr = new GoogleTranslate();
        $tr->setSource($srcLocale);
        $tr->setTarget($locale);
        // لو لزم تجاوز SSL مؤقتاً:
        // $tr->setOptions(['verify' => false]);

        $count = 0;
        foreach ($todo as $key => $text) {
            try {
                $dstData[$key] = $tr->translate($text);
                $count++;
                usleep(120000); // خفض المعدل
            } catch (\Throwable $e) {
                $this->error("Translate failed for '{$key}': ".$e->getMessage());
                $dstData[$key] = $dstData[$key] ?? $text;
            }
        }

        File::put($dst, json_encode($dstData, JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT));
        $this->info("Done: {$type} → {$locale}. Translated: {$count} key(s).");
        return self::SUCCESS;
    }
}
