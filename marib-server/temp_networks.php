<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$controller = $app->make(App\Http\Controllers\Wifi\AdminModerationController::class);
$request = Illuminate\Http\Request::create('/wifi-cabin/api/networks','GET');
$request->setUserResolver(function() {
    return App\Models\User::find(1);
});
$response = $controller->networks($request);
echo json_encode($response->toArray($request), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE);
