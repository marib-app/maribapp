<?php

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Redirector;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class Handler extends ExceptionHandler
{
    /**
     * A list of exception types with their corresponding custom log levels.
     *
     * @var array<class-string<\Throwable>, \Psr\Log\LogLevel::*>
     */
    protected $levels = [
        //
    ];

    /**
     * A list of the exception types that are not reported.
     *
     * @var array<int, class-string<\Throwable>>
     */
    protected $dontReport = [
        //
    ];

    /**
     * A list of the inputs that are never flashed to the session on validation exceptions.
     *
     * @var array<int, string>
     */
    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    /**
     * Register the exception handling callbacks for the application.
     *
     * @return void
     */
    public function register()
    {
        $this->reportable(function (Throwable $e) {
            //
        });





        $this->renderable(function (PaymentUnderReviewException $exception, Request $request): JsonResponse|RedirectResponse|Redirector {
            $message = trans('payment_under_review');

            $payload = [
                'error' => true,
                'message' => $message,
                'code' => 'payment_under_review',
            ];

            if ($exception->manualPaymentRequestId !== null) {
                $payload['manual_payment_request_id'] = $exception->manualPaymentRequestId;
                $payload['manual_payment_review_url'] = route('payment-requests.review', $exception->manualPaymentRequestId);
            }

            if ($request->expectsJson()) {
                return response()->json($payload, Response::HTTP_CONFLICT);
            }

            $flashMessage = $message;

            if ($exception->manualPaymentRequestId !== null) {
                $flashMessage = trans('payment_under_review_with_reference', [
                    'id' => $exception->manualPaymentRequestId,
                    'url' => $payload['manual_payment_review_url'] ?? '#',
                ]);
            }

            return redirect()->back()->withInput()->with('error', $flashMessage);
        });


    }
}
