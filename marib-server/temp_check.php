<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();
$items = App\Models\VerificationRequest::with('user')->get();
foreach ($items as $item) {
    echo "id={$item->id} status={$item->status} user=" . ($item->user->name ?? 'N/A') . "\n";
}
