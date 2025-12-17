<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$request = new Illuminate\Http\Request();
$request->setUserResolver(function() {
    return App\Models\User::first();
});

$controller = app(App\Http\Controllers\Api\PaymentController::class);
$reflection = new ReflectionClass($controller);
$method = $reflection->getMethod('normalizePaymentMethodForPurpose');
$method->setAccessible(true);

$normalized = $method->invoke($controller, 'manual_bank', 'verification');
echo "normalized=$normalized\n";
