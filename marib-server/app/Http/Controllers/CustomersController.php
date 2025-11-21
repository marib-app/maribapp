<?php

namespace App\Http\Controllers;

use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\BootstrapTableService;
use App\Services\ResponseService;
use App\Services\WalletService;
use App\Services\PaymentFulfillmentService;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;
use RuntimeException;



class CustomersController extends Controller {
    public function __construct(
        private readonly PaymentFulfillmentService $paymentFulfillmentService,
        private readonly WalletService $walletService
    ) {
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['customer-list', 'customer-update']);
        $packages = Package::all()->where('status', 1);

        $itemListingPackage = $packages->filter(function ($data) {
            return $data->type == "item_listing";
        });

        $advertisementPackage = $packages->filter(function ($data) {
            return $data->type == "advertisement";
        });

        return view('customer.index', compact('packages', 'itemListingPackage', 'advertisementPackage'));
    }

    public function update(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('customer-update');
            User::where('id', $request->id)->update(['status' => $request->status]);
            $message = $request->status ? "Customer Activated Successfully" : "Customer Deactivated Successfully";
            ResponseService::successResponse($message);
        } catch (Throwable) {
            ResponseService::errorRedirectResponse('Something Went Wrong ');
        }
    }

    public function list(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('customer-list');
            $offset = $request->offset ?? 0;
            $limit = $request->limit ?? 10;
            $sort = $request->sort ?? 'id';
            $order = $request->order ?? 'DESC';

            if ($request->notification_list) {
                $sql = User::role('User')
                    ->orderBy($sort, $order)
                    ->withCount('fcm_tokens as fcm_tokens_count');
            } else {
                $sql = User::role('User')->orderBy($sort, $order)->withCount('items')->withTrashed();
            }

            if (!empty($request->search)) {
                $sql = $sql->search($request->search);
            }
            $requestedAccountType = $this->resolveAccountTypeFilter($request->account_type ?? null);

            if ($requestedAccountType !== null) {
                $sql->where('account_type', $requestedAccountType);
            }
            
            // لا نستبعد الحسابات التجارية قيد المراجعة من لوحة العملاء
            $shouldEnforceVerificationFilter = $requestedAccountType === null
                || $requestedAccountType === User::ACCOUNT_TYPE_CUSTOMER
                || $requestedAccountType === User::ACCOUNT_TYPE_REAL_ESTATE;

            if ($shouldEnforceVerificationFilter) {
                $sql->where(function($query) {
                    $query->whereNotNull('email_verified_at')
                          ->orWhere('is_verified', 1);
                });
            }

            if ($request->filled('email_verified_at')) {
                if ($request->email_verified_at == '1') {
                    $sql->whereNotNull('email_verified_at');
                } else {
                    $sql->whereNull('email_verified_at');
                }
            }

            $total = $sql->count();
            $sql->skip($offset)->take($limit);
            $result = $sql->get();
            
            $bulkData = array();
            $bulkData['total'] = $total;
            $rows = array();
            $no = 1;
            foreach ($result as $row) {
                $tempRow = $row->toArray();
                $tempRow['no'] = $no++;
                $tempRow['status'] = empty($row->deleted_at);

                if (config('app.demo_mode')) {
                    if (!empty($row->mobile)) {
                        $tempRow['mobile'] = substr($row->mobile, 0, 3) . str_repeat('*', (strlen($row->mobile) - 5)) . substr($row->mobile, -2);
                    }

                    if (!empty($row->email)) {
                        $tempRow['email'] = substr($row->email, 0, 3) . '****' . substr($row->email, strpos($row->email, "@"));
                    }
                }

                $tempRow['operate'] = BootstrapTableService::button(
                    'fa fa-cart-plus',
                    route('customer.assign.package', $row->id),
                    ['btn-outline-danger', 'assign_package'],
                    [
                        'title'          => __("Assign Package"),
                        "data-bs-target" => "#assignPackageModal",
                        "data-bs-toggle" => "modal"
                    ]
                );
                
                $tempRow['operate'] .= ' ' . BootstrapTableService::button(
                    'fa fa-info-circle',
                    '#',
                    ['btn-outline-primary', 'edit-additional-info'],
                    [
                        'title' => __("معلومات إضافية"),
                    ]
                );
                
                $rows[] = $tempRow;
            }

            $bulkData['rows'] = $rows;
            return response()->json($bulkData);
        } catch (\Throwable $th) {
            \Log::error('Error in customer list: ' . $th->getMessage());
            \Log::error($th->getTraceAsString());
            return response()->json(['error' => $th->getMessage()], 500);
        }
    }

    /**
     * عرض تفاصيل العميل المحدد.
     * طريقة متوافقة مع resource controllers
     */
    public function show($id) {
        try {
            ResponseService::noPermissionThenSendJson('customer-list');
            $user = User::with(['items', 'orders'])->findOrFail($id);
            return view('customer.show', compact('user'));
        } catch (\Throwable $th) {
            \Log::error('Error in customer show: ' . $th->getMessage());
            return back()->with('error', 'حدث خطأ أثناء عرض العميل: ' . $th->getMessage());
        }
    }

    public function showDetails($id)
    {
        ResponseService::noPermissionThenSendJson('customer-list');
        
        $user = User::with(['items', 'orders'])->findOrFail($id);
        
        return view('customer.show', compact('user'));
    }

    public function assignPackage(Request $request) {
        $validator = Validator::make($request->all(), [
            'package_id'      => 'required',
            'payment_gateway' => 'required|in:cash,cheque,wallet',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            DB::beginTransaction();
            ResponseService::noPermissionThenSendJson('customer-list');
            $user = User::find($request->user_id);
            if (empty($user)) {
                ResponseService::errorResponse('User is not Active');
            }
            $package = Package::findOrFail($request->package_id);
            $paymentGateway = $request->payment_gateway;
            $walletIdempotencyKey = $paymentGateway === 'wallet'
                ? $this->buildAdminWalletIdempotencyKey($user->id, $package->id)
                : null;

            $transaction = $paymentGateway === 'wallet'
                ? $this->findOrCreateAdminWalletTransaction($user->id, $package, $walletIdempotencyKey)
                : PaymentTransaction::create([
                    'user_id'         => $user->id,
                    'amount'          => $package->final_price,
                    'payment_gateway' => $paymentGateway,
                    'payment_status'  => 'pending',
                ]);

            $options = [
                'payment_gateway' => $paymentGateway,
            ];

            if ($paymentGateway === 'wallet' && $walletIdempotencyKey) {
                $walletTransaction = $this->ensureAdminWalletDebit(
                    $transaction,
                    $user,
                    $package,
                    $walletIdempotencyKey
                );

                $options['wallet_transaction'] = $walletTransaction;
                $options['meta']['wallet'] = [
                    'transaction_id' => $walletTransaction->getKey(),
                    'balance_after' => (float) $walletTransaction->balance_after,
                    'idempotency_key' => $walletTransaction->idempotency_key,
                ];
            }

            $result = $this->paymentFulfillmentService->fulfill(
                $transaction,
                Package::class,
                $package->id,
                $user->id,
                $options
            );

            if ($result['error']) {
                throw new RuntimeException($result['message']);
            }


            DB::commit();
            ResponseService::successResponse('Package assigned to user Successfully');
        } catch (RuntimeException $runtimeException) {
            DB::rollBack();
            ResponseService::errorResponse($runtimeException->getMessage());

        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "CustomersController --> assignPackage");
            ResponseService::errorResponse();
        }
    }


    private function buildAdminWalletIdempotencyKey(int $userId, int $packageId): string
    {
        return sprintf('wallet:admin-package:%d:%d', $userId, $packageId);
    }

    private function findOrCreateAdminWalletTransaction(int $userId, Package $package, string $idempotencyKey): PaymentTransaction
    {
        $transaction = PaymentTransaction::query()
            ->where('payment_gateway', 'wallet')
            ->where('order_id', $idempotencyKey)
            ->lockForUpdate()
            ->first();

        if ($transaction) {
            $transaction->forceFill([
                'user_id' => $userId,
                'amount' => $package->final_price,
                'payable_type' => Package::class,
                'payable_id' => $package->id,
            ])->save();

            return $transaction->fresh();
        }

        return PaymentTransaction::create([
            'user_id' => $userId,
            'amount' => $package->final_price,
            'payment_gateway' => 'wallet',
            'order_id' => $idempotencyKey,
            'payment_status' => 'pending',
            'payable_type' => Package::class,
            'payable_id' => $package->id,
            'meta' => [
                'wallet' => [
                    'idempotency_key' => $idempotencyKey,
                ],
            ],
        ]);
    }

    private function ensureAdminWalletDebit(PaymentTransaction $transaction, User $user, Package $package, string $idempotencyKey): WalletTransaction
    {
        $walletTransactionId = data_get($transaction->meta, 'wallet.transaction_id');

        if ($walletTransactionId) {
            $walletTransaction = WalletTransaction::query()
                ->whereKey($walletTransactionId)
                ->lockForUpdate()
                ->first();

            if ($walletTransaction) {
                return $walletTransaction;
            }
        }

        try {
            return $this->walletService->debit($user, $idempotencyKey, (float) $package->final_price, [
                'payment_transaction' => $transaction,
                'meta' => [
                    'context' => 'admin_package_assignment',
                    'package_id' => $package->id,
                ],
            ]);
        } catch (RuntimeException $runtimeException) {
            if (str_contains(strtolower($runtimeException->getMessage()), 'insufficient wallet balance')) {
                DB::rollBack();
                ResponseService::errorResponse('Recharge required');
            }

            $walletTransaction = WalletTransaction::query()
                ->where('idempotency_key', $idempotencyKey)
                ->whereHas('account', static function ($query) use ($user) {
                    $query->where('user_id', $user->id);
                })
                ->lockForUpdate()
                ->first();

            if (!$walletTransaction) {
                throw $runtimeException;
            }

            return $walletTransaction;
        }
    }


    public function updateAdditionalInfo(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('customer-update');
            
            $user = User::findOrFail($request->user_id);
            
            // Actualizar ubicación
            $user->location = $request->location;
            
            // Procesar información de contacto adicional
            $additionalContacts = [];
            $contactLabels = $request->contact_labels ?? [];
            $contactValues = $request->contact_values ?? [];
            
            for ($i = 0; $i < count($contactLabels); $i++) {
                if (!empty($contactLabels[$i]) && !empty($contactValues[$i])) {
                    $additionalContacts[$contactLabels[$i]] = $contactValues[$i];
                }
            }
            
            // تحويل معلومات الاتصال إلى هيكل additional_info الجديد
            $additionalInfo = $user->additional_info ?? [
                'addresses' => [],
                'categories' => [],
                'place_names' => [],
                'contact_info' => []
            ];
            
            $additionalInfo['contact_info'] = array_merge(
                $additionalInfo['contact_info'],
                $additionalContacts
            );
            
            $user->additional_info = $additionalInfo;
            
            // Procesar información de pago
            $paymentInfo = [];
            $paymentLabels = $request->payment_labels ?? [];
            $paymentValues = $request->payment_values ?? [];
            
            for ($i = 0; $i < count($paymentLabels); $i++) {
                if (!empty($paymentLabels[$i]) && !empty($paymentValues[$i])) {
                    $paymentInfo[$paymentLabels[$i]] = $paymentValues[$i];
                }
            }
            
            $user->payment_info = !empty($paymentInfo) ? $paymentInfo : null;
            
            $user->save();
            
            ResponseService::successResponse('تم تحديث المعلومات الإضافية بنجاح');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "CustomersController --> updateAdditionalInfo");
            ResponseService::errorResponse();
        }
    }

    private function resolveAccountTypeFilter($raw): ?int
    {
        if ($raw === null || $raw === '') {
            return null;
        }

        if (is_numeric($raw)) {
            $value = (int) $raw;

            return $value > 0 ? $value : null;
        }

        $map = [
            'individual' => User::ACCOUNT_TYPE_CUSTOMER,
            'customer' => User::ACCOUNT_TYPE_CUSTOMER,
            'real_estate' => User::ACCOUNT_TYPE_REAL_ESTATE,
            'estate' => User::ACCOUNT_TYPE_REAL_ESTATE,
            'business' => User::ACCOUNT_TYPE_SELLER,
            'seller' => User::ACCOUNT_TYPE_SELLER,
        ];

        $key = strtolower(trim((string) $raw));

        return $map[$key] ?? null;
    }
}
