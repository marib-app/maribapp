<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('wifi_networks', 'slug')) {
            return;
        }

        Schema::table('wifi_networks', function (Blueprint $table) {
            $table->string('slug')->nullable()->after('name');
        });

        $usedSlugs = [];

        DB::table('wifi_networks')->orderBy('id')->select(['id', 'name'])->chunkById(100, function ($networks) use (&$usedSlugs) {
            foreach ($networks as $network) {
                $base = Str::slug((string) ($network->name ?? ''));

                if ($base === '') {
                    $base = 'network-' . $network->id;
                }

                $base = substr($base, 0, 255);
                $slug = $base;
                $counter = 1;

                while (in_array($slug, $usedSlugs, true)) {
                    $suffix = '-' . $counter++;
                    $slug = substr($base, 0, 255 - strlen($suffix)) . $suffix;
                }

                $usedSlugs[] = $slug;

                DB::table('wifi_networks')->where('id', $network->id)->update([
                    'slug' => $slug,
                ]);
            }
        });

        Schema::table('wifi_networks', function (Blueprint $table) {
            $table->unique('slug');
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('wifi_networks', 'slug')) {
            return;
        }

        Schema::table('wifi_networks', function (Blueprint $table) {
            $table->dropUnique('wifi_networks_slug_unique');
            $table->dropColumn('slug');
        });
    }
};