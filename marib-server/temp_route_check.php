<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$request = Illuminate\Http\Request::create('/api/get-featured-section','GET');
$response = $kernel->handle($request);
http_response_code($response->getStatusCode());
echo $response->getStatusCode(),"\n";
echo $response->getContent(),"\n";
$kernel->terminate($request,$response);
