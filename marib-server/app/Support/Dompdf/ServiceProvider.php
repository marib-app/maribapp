<?php

namespace Barryvdh\DomPDF;

use Illuminate\Support\ServiceProvider as BaseServiceProvider;

class ServiceProvider extends BaseServiceProvider
{
    public function register(): void
    {
        $this->app->singleton('dompdf.wrapper', function () {
            return new PDF();
        });
    }

    public function provides(): array
    {
        return ['dompdf.wrapper'];
    }
}