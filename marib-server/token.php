<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
echo App\Models\User::find(1)->createToken('dev')->plainTextToken, PHP_EOL;
