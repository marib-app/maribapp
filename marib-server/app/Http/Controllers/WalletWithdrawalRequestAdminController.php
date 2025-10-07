<?php

namespace App\Http\Controllers;

use App\Models\UserFcmToken;
use App\Models\WalletWithdrawalRequest;
use App\Services\NotificationService;
use App\Services\ResponseService;
use App\Services\WalletService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Contracts\View\View;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use RuntimeException;
use Throwable;

class WalletWithdrawalRequestAdminController extends Controller
{
    public function __construct(private readonly WalletService $walletService)
    {
    }



    public function index(Request $request): View
    {
        ResponseService::noPermissionThenRedirect('wallet-manage');

        $statusOptions = [
            WalletWithdrawalRequest::STATUS_PENDING => __('Pending'),
            WalletWithdrawalRequest::STATUS_APPROVED => __('Approved'),
            WalletWithdrawalRequest::STATUS_REJECTED => __('Rejected'),
        ];

        $methodOptions = collect(config('wallet.withdrawals.methods', []))
            ->mapWithKeys(static function (array $method): array {
                $key = (string) ($method['key'] ?? '');

                if ($key === '') {
                    return [];
                }

                $name = __($method['name'] ?? Str::headline(str_replace('_', ' ', $key)));

                return [$key => [
                    'key' => $key,
                    'name' => $name,
                ]];
            })
            ->all();

        $validator = Validator::make($request->all(), [
            'status' => ['nullable', Rule::in(array_keys($statusOptions))],
            'method' => ['nullable', Rule::in(array_keys($methodOptions))],
        ]);

        if ($validator->fails()) {
            return redirect()
                ->route('wallet.withdrawals.index')
                ->withErrors($validator)
                ->withInput();
        }

        $filters = $validator->validated();

        $withdrawalRequests = WalletWithdrawalRequest::query()
            ->with(['account.user'])
            ->latest();

        if (!empty($filters['status'])) {
            $withdrawalRequests->where('status', $filters['status']);
        }

        if (!empty($filters['method'])) {
            $withdrawalRequests->where('preferred_method', $filters['method']);
        }

        $withdrawals = $withdrawalRequests
            ->paginate(20)
            ->withQueryString();

        $statusAggregates = WalletWithdrawalRequest::query()
            ->select('status', DB::raw('COUNT(*) as total_count'), DB::raw('COALESCE(SUM(amount), 0) as total_amount'))
            ->groupBy('status')
            ->get()
            ->mapWithKeys(static function ($row): array {
                return [$row->status => [
                    'count' => (int) $row->total_count,
                    'amount' => (float) $row->total_amount,
                ]];
            });

        $statusSummaries = collect($statusOptions)
            ->map(function (string $label, string $status) use ($statusAggregates) {
                $metrics = $statusAggregates[$status] ?? ['count' => 0, 'amount' => 0.0];

                return [
                    'status' => $status,
                    'label' => $label,
                    'count' => $metrics['count'],
                    'amount' => $metrics['amount'],
                ];
            })
            ->values();

        $totalWithdrawalAmount = $statusAggregates->sum(static fn (array $metrics): float => $metrics['amount']);



        return view('wallet.withdrawals', [
            'withdrawals' => $withdrawals,
            'statusOptions' => $statusOptions,
            'methodOptions' => $methodOptions,
            'filters' => [
                'status' => $filters['status'] ?? null,
                'method' => $filters['method'] ?? null,
            ],
            'currency' => strtoupper(config('app.currency', 'SAR')),
            'statusSummaries' => $statusSummaries,
            'totalWithdrawalAmount' => $totalWithdrawalAmount,

        ]);
    }

    public function approve(Request $request, WalletWithdrawalRequest $withdrawalRequest): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('wallet-manage');

        if (!$withdrawalRequest->isPending()) {
            return $this->redirectWithError(__('This withdrawal request has already been processed.'));
        }

        $validator = Validator::make($request->all(), [
            'review_notes' => ['nullable', 'string', 'max:500'],
        ]);

        if ($validator->fails()) {
            return redirect()->route('wallet.index')->withErrors($validator);
        }

        $validated = $validator->validated();

        try {
            DB::transaction(static function () use ($withdrawalRequest, $validated) {
                $withdrawalRequest->forceFill([
                    'status' => WalletWithdrawalRequest::STATUS_APPROVED,
                    'review_notes' => $validated['review_notes'] ?? null,
                    'reviewed_by' => Auth::id(),
                    'reviewed_at' => now(),
                ])->save();
            });
        } catch (Throwable $throwable) {
            Log::error('WalletWithdrawalRequestAdminController: Failed to approve withdrawal request', [
                'error' => $throwable->getMessage(),
                'request_id' => $withdrawalRequest->getKey(),
            ]);

            return $this->redirectWithError(__('Failed to approve withdrawal request.'));
        }

        $withdrawalRequest->refresh();

        $this->sendStatusNotification($withdrawalRequest);

        return redirect()
            ->route('wallet.index')
            ->with('success', __('Withdrawal request approved successfully.'));
    }

    public function reject(Request $request, WalletWithdrawalRequest $withdrawalRequest): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('wallet-manage');

        if (!$withdrawalRequest->isPending()) {
            return $this->redirectWithError(__('This withdrawal request has already been processed.'));
        }

        $validator = Validator::make($request->all(), [
            'review_notes' => ['nullable', 'string', 'max:500'],
        ]);

        if ($validator->fails()) {
            return redirect()->route('wallet.index')->withErrors($validator);
        }

        $validated = $validator->validated();

        try {
            DB::transaction(function () use ($withdrawalRequest, $validated) {
                $user = $withdrawalRequest->account?->user;

                if (!$user) {
                    throw new RuntimeException('Associated user for the withdrawal request could not be found.');
                }

                $idempotencyKey = $withdrawalRequest->buildIdempotencyKey('reversal');

                $creditTransaction = $this->walletService->credit($user, $idempotencyKey, (float) $withdrawalRequest->amount, [
                    'meta' => [
                        'context' => 'wallet_withdrawal_request_reversal',
                        'withdrawal_request_id' => $withdrawalRequest->getKey(),
                        'original_wallet_transaction_id' => $withdrawalRequest->wallet_transaction_id,
                    ],
                ]);

                $withdrawalRequest->forceFill([
                    'status' => WalletWithdrawalRequest::STATUS_REJECTED,
                    'resolution_transaction_id' => $creditTransaction->getKey(),
                    'review_notes' => $validated['review_notes'] ?? null,
                    'reviewed_by' => Auth::id(),
                    'reviewed_at' => now(),
                ])->save();
            });
        } catch (RuntimeException $runtimeException) {
            Log::warning('WalletWithdrawalRequestAdminController: Withdrawal rejection failed', [
                'error' => $runtimeException->getMessage(),
                'request_id' => $withdrawalRequest->getKey(),
            ]);

            return $this->redirectWithError($runtimeException->getMessage());
        } catch (Throwable $throwable) {
            Log::error('WalletWithdrawalRequestAdminController: Unexpected error while rejecting withdrawal', [
                'error' => $throwable->getMessage(),
                'request_id' => $withdrawalRequest->getKey(),
            ]);

            return $this->redirectWithError(__('Failed to reject withdrawal request.'));
        }

        $withdrawalRequest->refresh();

        $this->sendStatusNotification($withdrawalRequest);

        return redirect()
            ->route('wallet.index')
            ->with('success', __('Withdrawal request rejected successfully.'));
    }

    protected function redirectWithError(string $message): RedirectResponse
    {
        return redirect()->route('wallet.index')->withErrors([
            'withdrawal_request' => $message,
        ]);
    }

    protected function sendStatusNotification(WalletWithdrawalRequest $withdrawalRequest): void
    {
        $user = $withdrawalRequest->account?->user;

        if (!$user) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $user->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($tokens)) {
            return;
        }

        $currency = strtoupper(config('app.currency', 'SAR'));
        $amount = (float) $withdrawalRequest->amount;

        $title = __('Wallet withdrawal request updated');

        $body = match ($withdrawalRequest->status) {
            WalletWithdrawalRequest::STATUS_APPROVED => __('Your withdrawal request for :amount :currency has been approved.', [
                'amount' => number_format($amount, 2),
                'currency' => $currency,
            ]),
            WalletWithdrawalRequest::STATUS_REJECTED => __('Your withdrawal request for :amount :currency has been rejected.', [
                'amount' => number_format($amount, 2),
                'currency' => $currency,
            ]),
            default => __('Your withdrawal request has been updated.'),
        };

        try {
            $response = NotificationService::sendFcmNotification($tokens, $title, $body, 'wallet_withdrawal', [
                'request_id' => $withdrawalRequest->getKey(),
                'status' => $withdrawalRequest->status,
                'amount' => $amount,
                'currency' => $currency,
                'preferred_method' => $withdrawalRequest->preferred_method,
                'wallet_transaction_id' => $withdrawalRequest->wallet_transaction_id,
                'resolution_transaction_id' => $withdrawalRequest->resolution_transaction_id,
                'review_notes' => $withdrawalRequest->review_notes,
            ]);

            if (is_array($response) && ($response['error'] ?? false)) {
                Log::warning('WalletWithdrawalRequestAdminController: FCM responded with an error', [
                    'request_id' => $withdrawalRequest->getKey(),
                    'response' => $response,
                ]);
            }
        } catch (Throwable $throwable) {
            Log::error('WalletWithdrawalRequestAdminController: Failed to send withdrawal notification', [
                'error' => $throwable->getMessage(),
                'request_id' => $withdrawalRequest->getKey(),
            ]);
        }
    }
}