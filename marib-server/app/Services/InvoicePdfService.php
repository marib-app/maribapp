<?php

namespace App\Services;

use App\Models\Order;
use Barryvdh\DomPDF\PDF;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Support\Currency;


class InvoicePdfService
{

    private const DEFAULT_VIEW = 'invoices.default';
    private const DEFAULT_FONT = 'Almarai';
    private const REQUIRED_FONTS = [
        'Almarai-Regular.ttf' => 'resources/fonts/Almarai-Regular.ttf',
        'Almarai-Bold.ttf' => 'resources/fonts/Almarai-Bold.ttf',
    ];

    public function __construct(private readonly ViewFactory $viewFactory)
    {
    }


    public function generate(Order $order): string
    {
        $document = $this->renderDocument($order);

        if (! $document->hasPdf()) {
            throw new \RuntimeException('Unable to generate invoice PDF in the current environment.');
        }

        return $document->pdf;
    }

    public function renderDocument(Order $order): InvoiceDocument
    {
        $order->loadMissing(['items', 'user']);
        Carbon::setLocale(app()->getLocale() ?? 'ar');

        $viewData = $this->buildViewPayload($order);
        $html = $this->renderView($viewData, false);

        $pdfContents = null;

        if (app()->bound('dompdf.wrapper')) {
            try {
                $this->ensureFontDirectoryExists();

                /** @var PDF $pdf */
                $pdf = app('dompdf.wrapper');
                $this->callIfCallable($pdf, 'setOptions', [
                    
                    'defaultFont' => self::DEFAULT_FONT,
                    'isHtml5ParserEnabled' => true,
                    'isRemoteEnabled' => true,
                    'fontDir' => storage_path('fonts'),
                    'fontCache' => storage_path('fonts'),
                ]);
                if (is_callable([$pdf, 'loadHTML'])) {
                    $pdf->loadHTML($html);
                } elseif (is_callable([$pdf, 'loadView'])) {
                    $pdf->loadView(self::DEFAULT_VIEW, $viewData);
                }

                $this->callIfCallable($pdf, 'setPaper', 'a4', 'portrait');

                if (is_callable([$pdf, 'output'])) {
                    $output = $pdf->output();
                    $pdfContents = is_string($output) ? $output : null;
                }
            } catch (\Throwable $exception) {
                \Log::warning('invoice.pdf_generation_failed', [
                    'order_id' => $order->getKey(),
                    'message' => $exception->getMessage(),
                ]);
            }
        }

        return new InvoiceDocument(
            fileName: $this->resolveFileName($order),
            html: $html,
            pdf: $pdfContents,
            viewData: $viewData,
        );
    }

    public function renderPreviewHtml(Order $order, ?InvoiceDocument $document = null, array $extra = []): string
    {
        $viewData = $document?->viewData ?? $this->buildViewPayload($order);

        return $this->renderView($viewData, true, $extra);
    }

    /**
     * @return array<string, mixed>
     */
    private function buildViewPayload(Order $order): array
    {

        $order->loadMissing([
            'latestManualPaymentRequest.manualBank',
            'latestPaymentTransaction.manualPaymentRequest.manualBank',
        ]);

        $settings = $this->resolveSettings();

        $company = [
            'name' => $settings['invoice_company_name'] ?? $settings['company_name'] ?? '',
            'address' => $settings['invoice_company_address'] ?? $settings['company_address'] ?? '',
            'tax_id' => $settings['invoice_company_tax_id'] ?? '',
            'email' => $settings['invoice_company_email'] ?? $settings['company_email'] ?? '',
            'phone' => $settings['invoice_company_phone'] ?? $settings['company_tel1'] ?? '',
            'footer_note' => $settings['invoice_footer_note'] ?? '',
            'logo' => $this->resolveLogoDataUri($settings['invoice_logo'] ?? $settings['company_logo'] ?? ''),


        ];

        $summary = [
            'items_total' => (float) ($order->total_amount ?? 0),
            'tax' => (float) ($order->tax_amount ?? 0),
            'discount' => (float) ($order->discount_amount ?? 0),
            'delivery' => (float) ($order->delivery_total ?? 0),
            'final' => (float) ($order->final_amount ?? 0),
        ];

        $items = $order->items->map(function ($item) {
            return [
                'name' => $item->item_name ?? Arr::get($item->item_snapshot, 'name', ''),
                'quantity' => (int) $item->quantity,
                'unit_price' => (float) ($item->price ?? 0),
                'subtotal' => (float) ($item->subtotal ?? 0),
            ];
        })->toArray();


        $paymentStatus = $order->payment_status
            ? (Order::PAYMENT_STATUS_LABELS[$order->payment_status] ?? $order->payment_status)
            : null;

        $paymentLabels = $order->resolvePaymentGatewayLabels();
        $paymentMethod = $paymentLabels['gateway_label']
            ?? ($order->payment_method ?: null);
        $paymentGatewayKey = $paymentLabels['gateway_key'] ?? null;
        $paymentBankName = $paymentLabels['bank_name'] ?? null;


        $currencySymbolSetting = $settings['currency_symbol'] ?? null;
        $currencyCodeSetting = $settings['currency_code']
            ?? $settings['currency']
            ?? $settings['default_currency']
            ?? config('app.currency');
        $currencySymbol = Currency::preferredSymbol($currencySymbolSetting, $currencyCodeSetting);




        return [
            'order' => $order,
            'items' => $items,
            'summary' => $summary,
            'company' => $company,
            'currency' => $currencySymbol,
            'customer' => $order->user,
            'issued_at' => $order->created_at ? Carbon::parse($order->created_at) : null,
            'generated_at' => Carbon::now(),
            'payment' => [

                'method' => $paymentMethod ? __($paymentMethod) : __('غير محدد'),
                'status' => $paymentStatus ? __($paymentStatus) : __('غير محدد'),
                'gateway_key' => $paymentGatewayKey,
                'bank_name' => $paymentBankName,

            ],
            'billing_address' => $order->billing_address ?? Arr::get($order->address_snapshot, 'billing.address'),
            'shipping_address' => $order->shipping_address ?? Arr::get($order->address_snapshot, 'shipping.address'),
            'invoice_number' => $order->invoice_no ?: $order->order_number,

        ];
    }

    private function renderView(array $data, bool $preview, array $extra = []): string
    {
        $payload = array_merge($data, $extra);
        $payload['preview'] = $preview;
        $payload['preview_assets'] = $preview ? $this->buildPreviewAssets() : [];

        return $this->viewFactory->make(self::DEFAULT_VIEW, $payload)->render();
    }

    private function resolveFileName(Order $order): string
    {
        $base = $order->order_number ?: $order->invoice_no ?: $order->getKey();



        $slug = Str::slug((string) $base) ?: (string) $order->getKey();


        return sprintf('invoice-%s.pdf', $slug);
    }


    private function resolveSettings(): array
    {
        $settings = CachingService::getSystemSettings();

        if ($settings instanceof \Illuminate\Support\Collection) {
            return $settings->toArray();
        }

        if (is_array($settings)) {
            return $settings;
        }

        return [];
    }

    private function resolveLogoDataUri(?string $logo): ?string

    {
        if (empty($logo)) {
            return null;
        }



        if (Str::startsWith($logo, 'data:')) {
            return $logo;
        }

        if (Str::startsWith($logo, ['http://', 'https://'])) {
            $path = parse_url($logo, PHP_URL_PATH) ?: '';

            if (Str::startsWith($path, '/storage/')) {
                $relative = ltrim(Str::after($path, '/storage/'), '/');



                if ($relative && Storage::disk(config('filesystems.default'))->exists($relative)) {
                    return $this->encodeStorageImage($relative);
                }
            }


            return $logo;
        }

        if (Str::startsWith($logo, 'assets/')) {
            $filePath = public_path($logo);

            if (is_readable($filePath)) {
                return $this->encodeFileToDataUri($filePath);
            }
        }

        if (Storage::disk(config('filesystems.default'))->exists($logo)) {
            return $this->encodeStorageImage($logo);
        }

        $filePath = public_path($logo);

        if (is_readable($filePath)) {
            return $this->encodeFileToDataUri($filePath);

        }

        return $logo;
    }

    private function ensureFontDirectoryExists(): void
    {
        $fontPath = storage_path('fonts');

        if (! is_dir($fontPath)) {
            mkdir($fontPath, 0755, true);
        }


        $this->ensureDefaultFontsPresent($fontPath);
    }

    private function ensureDefaultFontsPresent(string $fontPath): void
    {
        foreach (self::REQUIRED_FONTS as $fileName => $relativePath) {
            $targetPath = $fontPath . DIRECTORY_SEPARATOR . $fileName;

            if (file_exists($targetPath)) {
                continue;
            }

            $candidates = [
                base_path($relativePath),
                resource_path('fonts' . DIRECTORY_SEPARATOR . $fileName),
            ];

            foreach ($candidates as $candidate) {
                if (is_readable($candidate)) {
                    copy($candidate, $targetPath);
                    break;
                }
            }
        }
    }

    private function callIfCallable(object $target, string $method, ...$arguments): void
    {
        if (! is_callable([$target, $method])) {
            return;
        }

        $target->{$method}(...$arguments);
    }
    private function buildPreviewAssets(): array
    {
        return [
            'font_regular' => $this->resolveFontDataUri('Almarai-Regular.ttf'),
            'font_bold' => $this->resolveFontDataUri('Almarai-Bold.ttf'),
        ];

    }

    private function resolveFontDataUri(string $fileName): ?string
    {
        $paths = [
            storage_path('fonts' . DIRECTORY_SEPARATOR . $fileName),
            resource_path('fonts' . DIRECTORY_SEPARATOR . $fileName),
            base_path('resources/fonts/' . $fileName),
        ];

        foreach ($paths as $path) {
            if (is_readable($path)) {
                return $this->encodeFileToDataUri($path);
            }
        }

        return null;
    }

    private function encodeStorageImage(string $relativePath): ?string
    {
        $disk = Storage::disk(config('filesystems.default'));
        $contents = $disk->get($relativePath);
        $mimeType = $disk->mimeType($relativePath) ?? 'image/png';

        return $this->encodeRawToDataUri($contents, $mimeType);
    }

    private function encodeFileToDataUri(string $filePath): ?string
    {
        $contents = file_get_contents($filePath);
        $mimeType = mime_content_type($filePath) ?: 'image/png';

        return $this->encodeRawToDataUri($contents, $mimeType);
    }

    private function encodeRawToDataUri(string|false $contents, string $mimeType): ?string
    {
        if ($contents === false) {
            return null;
        }

        return sprintf('data:%s;base64,%s', $mimeType, base64_encode($contents));
    }
}