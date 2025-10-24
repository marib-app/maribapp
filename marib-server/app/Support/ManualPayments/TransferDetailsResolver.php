<?php

namespace App\Support\ManualPayments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\WalletTransaction;
use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;
use Throwable;

class TransferDetailsResolver implements Arrayable, \JsonSerializable
{
    private function __construct(
        private readonly ?ManualPaymentRequest $manualPaymentRequest,
        private readonly ?PaymentTransaction $paymentTransaction,
        private readonly ?WalletTransaction $walletTransaction,
        private readonly array $row = []
    ) {
    }

    /**
     * @param  ManualPaymentRequest|PaymentTransaction|WalletTransaction|array<mixed>|int|null  $row
     */
    public static function forRow($row): self
    {
        if ($row instanceof ManualPaymentRequest) {
            return self::forManualPaymentRequest($row);
        }

        if ($row instanceof PaymentTransaction) {
            return self::forPaymentTransaction($row);
        }

        if ($row instanceof WalletTransaction) {
            return self::forWalletTransaction($row);
        }

        $manualRequest = null;
        $transaction = null;
        $walletTransaction = null;
        $rowData = is_array($row) ? $row : [];

        if (is_array($row)) {
            $candidate = Arr::get($row, 'manual_payment_request');
            if ($candidate instanceof ManualPaymentRequest) {
                $manualRequest = $candidate;
            }

            if ($manualRequest === null) {
                $candidate = Arr::get($row, 'request');
                if ($candidate instanceof ManualPaymentRequest) {
                    $manualRequest = $candidate;
                }
            }

            $candidate = Arr::get($row, 'payment_transaction');
            if ($candidate instanceof PaymentTransaction) {
                $transaction = $candidate;
            }

            if ($transaction === null) {
                $candidate = Arr::get($row, 'transaction');
                if ($candidate instanceof PaymentTransaction) {
                    $transaction = $candidate;
                }
            }

            $candidate = Arr::get($row, 'wallet_transaction');
            if ($candidate instanceof WalletTransaction) {
                $walletTransaction = $candidate;
            }

            if ($manualRequest === null) {
                $manualRequestId = Arr::get($row, 'manual_payment_request_id');
                if (is_numeric($manualRequestId)) {
                    $manualRequestId = (int) $manualRequestId;
                    if ($manualRequestId > 0) {
                        $manualRequest = ManualPaymentRequest::query()->find($manualRequestId);
                    }
                }
            }

            if ($transaction === null) {
                $transactionId = Arr::get($row, 'payment_transaction_id') ?? Arr::get($row, 'transaction_id');
                if (is_numeric($transactionId)) {
                    $transactionId = (int) $transactionId;
                    if ($transactionId > 0) {
                        $transaction = PaymentTransaction::query()->find($transactionId);
                    }
                }
            }

            if ($walletTransaction === null) {
                $walletTransactionId = Arr::get($row, 'wallet_transaction_id');
                if (is_numeric($walletTransactionId)) {
                    $walletTransactionId = (int) $walletTransactionId;
                    if ($walletTransactionId > 0) {
                        $walletTransaction = WalletTransaction::query()->find($walletTransactionId);
                    }
                }
            }
        }

        return new self($manualRequest, $transaction, $walletTransaction, $rowData);
    }

    public static function forManualPaymentRequest(ManualPaymentRequest $manualPaymentRequest): self
    {
        $manualPaymentRequest->loadMissing([
            'manualBank',
            'paymentTransaction.manualPaymentRequest',
            'paymentTransaction.walletTransaction',
            'payable',
        ]);

        $transaction = $manualPaymentRequest->paymentTransaction instanceof PaymentTransaction
            ? $manualPaymentRequest->paymentTransaction
            : null;

        $walletTransaction = null;
        $payable = $manualPaymentRequest->payable;

        if ($payable instanceof WalletTransaction) {
            $walletTransaction = $payable;
        } elseif ($transaction instanceof PaymentTransaction) {
            $walletTransaction = $transaction->walletTransaction instanceof WalletTransaction
                ? $transaction->walletTransaction
                : null;
        }

        return new self($manualPaymentRequest, $transaction, $walletTransaction);
    }

    public static function forPaymentTransaction(PaymentTransaction $transaction): self
    {
        $transaction->loadMissing(['manualPaymentRequest.manualBank', 'walletTransaction']);

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $walletTransaction = $transaction->walletTransaction instanceof WalletTransaction
            ? $transaction->walletTransaction
            : null;

        return new self($manualRequest, $transaction, $walletTransaction);
    }

    public static function forWalletTransaction(WalletTransaction $walletTransaction): self
    {
        $walletTransaction->loadMissing(['manualPaymentRequest.manualBank', 'paymentTransaction.manualPaymentRequest']);

        $manualRequest = $walletTransaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $walletTransaction->manualPaymentRequest
            : null;

        $transaction = $walletTransaction->paymentTransaction instanceof PaymentTransaction
            ? $walletTransaction->paymentTransaction
            : null;

        return new self($manualRequest, $transaction, $walletTransaction);
    }

    /**
     * @return array{bank_name: ?string, sender_name: ?string, transfer_reference: ?string, note: ?string, receipt_url: ?string, receipt_path: ?string, source: string}

     */
    public function toArray(): array
    {
        $values = [
            'bank_name' => null,
            'sender_name' => null,
            'transfer_reference' => null,
            'note' => null,
            'receipt_url' => null,
            'receipt_path' => null,
        ];

        $sources = [
            'bank_name' => null,
            'sender_name' => null,
            'transfer_reference' => null,
            'note' => null,
            'receipt_url' => null,
            'receipt_path' => null,
        ];

        $apply = function (string $field, $value, string $source, bool $allowMultiline = false) use (&$values, &$sources): void {
            if ($values[$field] !== null) {
                return;
            }

            $normalized = $allowMultiline
                ? $this->normalizeMultiline($value)
                : $this->normalizeString($value);

            if ($field === 'bank_name' && $normalized !== null) {
                $normalized = $this->sanitizeBankName($normalized);
            }

            if ($normalized === null) {
                return;
            }

            $values[$field] = $normalized;
            $sources[$field] = $source;
        };

        $setReceiptUrl = function (?string $url, string $source) use (&$values, &$sources): void {
            if ($values['receipt_url'] !== null) {
                return;
            }

            $normalized = $this->normalizeUrl($url);

            if ($normalized === null) {
                return;
            }

            $values['receipt_url'] = $normalized;
            $sources['receipt_url'] = $source;
        };

        $setReceiptPath = function ($path, $disk, string $source) use (&$values, &$sources, $setReceiptUrl): void {
            $normalizedPath = $this->normalizeString($path);

            if ($normalizedPath === null) {
                return;
            }

            $isUrl = filter_var($normalizedPath, FILTER_VALIDATE_URL) !== false;

            if ($isUrl) {
                $setReceiptUrl($normalizedPath, $source);
            }

            if ($values['receipt_path'] === null && ! $isUrl) {
                $values['receipt_path'] = $normalizedPath;
                $sources['receipt_path'] = $source;
            }

            if (! $isUrl) {
                $resolvedUrl = $this->generateStorageUrl($normalizedPath, $disk);
                $setReceiptUrl($resolvedUrl, $source);
            }
        };


        // Manual payment request data takes precedence.
        if ($this->manualPaymentRequest instanceof ManualPaymentRequest) {
            $meta = $this->manualPaymentRequestMeta();
            $manualBank = $this->manualPaymentRequest->manualBank instanceof ManualBank
                ? $this->manualPaymentRequest->manualBank
                : null;

            $apply('bank_name', $this->manualPaymentRequest->bank_name, 'mpr');
            $apply('bank_name', $manualBank?->name, 'mpr');
            $apply('bank_name', Arr::get($meta, 'manual_bank.name'), 'mpr');
            $apply('bank_name', Arr::get($meta, 'manual_bank.bank_name'), 'mpr');
            $apply('bank_name', Arr::get($meta, 'bank.name'), 'mpr');
            $apply('bank_name', Arr::get($meta, 'bank.bank_name'), 'mpr');

            $transferMeta = Arr::get($meta, 'transfer_details');
            if (! is_array($transferMeta)) {
                $transferMeta = [];
            }

            $apply('sender_name', Arr::get($meta, 'metadata.sender_name'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'metadata.sender'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'sender_name'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'sender'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'manual.sender_name'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'manual.metadata.sender_name'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'manual.metadata.sender'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'transfer.sender_name'), 'mpr');
            $apply('sender_name', Arr::get($meta, 'transfer.sender'), 'mpr');
            $apply('sender_name', Arr::get($transferMeta, 'sender_name'), 'mpr');
            $apply('sender_name', Arr::get($transferMeta, 'sender'), 'mpr');


            $apply('transfer_reference', $this->manualPaymentRequest->reference, 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'metadata.transfer_reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'metadata.transfer_code'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'metadata.transfer_number'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'metadata.reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'manual.transfer_reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'manual.metadata.transfer_reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'manual.metadata.transfer_code'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'manual.metadata.reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_reference'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_code'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_number'), 'mpr');
            $apply('transfer_reference', Arr::get($meta, 'transfer.reference'), 'mpr');
            $apply('transfer_reference', Arr::get($transferMeta, 'transfer_reference'), 'mpr');
            $apply('transfer_reference', Arr::get($transferMeta, 'transfer_code'), 'mpr');
            $apply('transfer_reference', Arr::get($transferMeta, 'transfer_number'), 'mpr');
            $apply('transfer_reference', Arr::get($transferMeta, 'reference'), 'mpr');
            $apply('transfer_reference', $this->manualPaymentRequest->reference, 'mpr');


            $apply('note', $this->manualPaymentRequest->user_note, 'mpr', true);
            $apply('note', Arr::get($meta, 'user_note'), 'mpr', true);
            $apply('note', Arr::get($meta, 'note'), 'mpr', true);
            $apply('note', Arr::get($meta, 'metadata.user_note'), 'mpr', true);
            $apply('note', Arr::get($meta, 'metadata.customer_note'), 'mpr', true);
            $apply('note', Arr::get($meta, 'metadata.note'), 'mpr', true);
            $apply('note', Arr::get($meta, 'metadata.notes'), 'mpr', true);
            $apply('note', Arr::get($meta, 'transfer.note'), 'mpr', true);
            $apply('note', Arr::get($transferMeta, 'note'), 'mpr', true);

            $noteSources = [
                ['note' => $this->manualPaymentRequest->user_note, 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'user_note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'metadata.user_note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'metadata.customer_note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'metadata.note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'metadata.notes'), 'source' => 'mpr_note'],
                ['note' => Arr::get($meta, 'transfer.note'), 'source' => 'mpr_note'],
                ['note' => Arr::get($transferMeta, 'note'), 'source' => 'mpr_note'],
            ];

            foreach ($noteSources as $candidate) {
                if (! is_array($candidate) || ! array_key_exists('note', $candidate)) {
                    continue;
                }

                if ($values['sender_name'] === null) {
                    $extractedSender = $this->extractSenderNameFromNote($candidate['note']);
                    if ($extractedSender !== null) {
                        $apply('sender_name', $extractedSender, $candidate['source'] ?? 'mpr_note');
                    }
                }

                if ($values['transfer_reference'] === null) {
                    $extractedReference = $this->extractTransferReferenceFromNote($candidate['note']);
                    if ($extractedReference !== null) {
                        $apply('transfer_reference', $extractedReference, $candidate['source'] ?? 'mpr_note');
                    }
                }

                if ($values['sender_name'] !== null && $values['transfer_reference'] !== null) {
                    break;
                }
            }

            $receiptMeta = Arr::get($meta, 'receipt');
            if (is_array($receiptMeta)) {
                $setReceiptUrl(Arr::get($receiptMeta, 'url'), 'mpr');
                if ($values['receipt_url'] === null || $values['receipt_path'] === null) {
                    $setReceiptPath(
                        Arr::get($receiptMeta, 'path'),
                        Arr::get($receiptMeta, 'disk'),
                        'mpr'
                    );
                }
            }

            $setReceiptUrl(Arr::get($meta, 'receipt_url'), 'mpr');
            $setReceiptUrl(Arr::get($meta, 'transfer.receipt_url'), 'mpr');
            $setReceiptUrl(Arr::get($meta, 'transfer_details.receipt_url'), 'mpr');
            $setReceiptUrl(Arr::get($transferMeta, 'receipt_url'), 'mpr');
            $setReceiptPath(Arr::get($meta, 'receiptPath'), Arr::get($meta, 'receipt.disk'), 'mpr');
            $setReceiptPath(Arr::get($meta, 'transfer.receipt_path'), Arr::get($meta, 'transfer.receipt_disk'), 'mpr');
            $setReceiptPath(Arr::get($meta, 'transfer.receiptPath'), Arr::get($meta, 'transfer.receipt.disk'), 'mpr');
            $setReceiptPath(
                Arr::get($meta, 'transfer_details.receipt_path'),
                Arr::get($meta, 'transfer_details.receipt_disk') ?? Arr::get($meta, 'transfer_details.disk'),
                'mpr'
            );
            $setReceiptPath(
                Arr::get($transferMeta, 'receipt_path'),
                Arr::get($transferMeta, 'receipt_disk') ?? Arr::get($transferMeta, 'disk'),
                'mpr'
            );


            if ($values['receipt_url'] === null) {
                $setReceiptPath(
                    $this->manualPaymentRequest->receipt_path,
                    'public',
                    'mpr'
                );
            }

            $attachments = Arr::get($meta, 'attachments');
            if ($values['receipt_url'] === null && is_iterable($attachments)) {
                foreach ($attachments as $attachment) {
                    if (! is_array($attachment)) {
                        continue;
                    }

                    $setReceiptUrl(Arr::get($attachment, 'url'), 'mpr');

                    if ($values['receipt_url'] !== null) {
                        break;
                    }

                    $attachmentPath = Arr::get($attachment, 'path');
                    $attachmentDisk = Arr::get($attachment, 'disk');
                    $setReceiptPath($attachmentPath, $attachmentDisk, 'mpr');

                    if ($values['receipt_url'] !== null) {
                        break;
                    }
                }
            }
        }

        // Payment transaction metadata and columns.
        if ($this->paymentTransaction instanceof PaymentTransaction) {
            $meta = $this->transactionMeta();

            $apply('bank_name', Arr::get($meta, 'manual_bank.name'), 'tx_meta');
            $apply('bank_name', Arr::get($meta, 'manual_bank.bank_name'), 'tx_meta');
            $apply('bank_name', Arr::get($meta, 'manual.bank.name'), 'tx_meta');
            $apply('bank_name', Arr::get($meta, 'manual.bank.bank_name'), 'tx_meta');
            $apply('bank_name', Arr::get($meta, 'payload.bank_name'), 'tx_meta');
            $apply('bank_name', Arr::get($meta, 'payload.manual_bank_name'), 'tx_meta');

            $apply('sender_name', Arr::get($meta, 'manual.metadata.sender_name'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'manual.metadata.sender'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'manual.sender_name'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'manual.sender'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'payload.sender_name'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'transfer.sender_name'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'transfer.sender'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'transfer_details.sender_name'), 'tx_meta');
            $apply('sender_name', Arr::get($meta, 'transfer_details.sender'), 'tx_meta');


            $apply('transfer_reference', Arr::get($meta, 'manual.metadata.transfer_reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'manual.metadata.transfer_code'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'manual.transfer_reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'manual.transfer_number'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'manual.reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'payload.transfer_reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_code'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_number'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer.reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_reference'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_code'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_number'), 'tx_meta');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.reference'), 'tx_meta');



            $apply('note', Arr::get($meta, 'manual.note'), 'tx_meta', true);
            $apply('note', Arr::get($meta, 'manual.user_note'), 'tx_meta', true);
            $apply('note', Arr::get($meta, 'manual.metadata.note'), 'tx_meta', true);
            $apply('note', Arr::get($meta, 'manual.metadata.notes'), 'tx_meta', true);
            $apply('note', Arr::get($meta, 'transfer.note'), 'tx_meta', true);
            $apply('note', Arr::get($meta, 'transfer_details.note'), 'tx_meta', true);


            $transactionNoteSources = [
                ['note' => Arr::get($meta, 'manual.note'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'manual.user_note'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'manual.metadata.note'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'manual.metadata.notes'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'metadata.note'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'metadata.notes'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'transfer.note'), 'source' => 'tx_meta_note'],
                ['note' => Arr::get($meta, 'transfer_details.note'), 'source' => 'tx_meta_note'],
            ];

            foreach ($transactionNoteSources as $candidate) {
                if (! is_array($candidate) || ! array_key_exists('note', $candidate)) {
                    continue;
                }

                if ($values['sender_name'] === null) {
                    $extractedSender = $this->extractSenderNameFromNote($candidate['note']);
                    if ($extractedSender !== null) {
                        $apply('sender_name', $extractedSender, $candidate['source'] ?? 'tx_meta');
                    }
                }

                if ($values['transfer_reference'] === null) {
                    $extractedReference = $this->extractTransferReferenceFromNote($candidate['note']);
                    if ($extractedReference !== null) {
                        $apply('transfer_reference', $extractedReference, $candidate['source'] ?? 'tx_meta');
                    }
                }

                if ($values['sender_name'] !== null && $values['transfer_reference'] !== null) {
                    break;
                }
            }

            $receiptMeta = Arr::get($meta, 'receipt');
            if (is_array($receiptMeta)) {
                $setReceiptUrl(Arr::get($receiptMeta, 'url'), 'tx_meta');
                if ($values['receipt_url'] === null || $values['receipt_path'] === null) {
                    $setReceiptPath(
                        Arr::get($receiptMeta, 'path'),
                        Arr::get($receiptMeta, 'disk'),
                        'tx_meta'
                    );
                }
            }

            $setReceiptUrl(Arr::get($meta, 'receipt_url'), 'tx_meta');
            $setReceiptUrl(Arr::get($meta, 'transfer.receipt_url'), 'tx_meta');
            $setReceiptUrl(Arr::get($meta, 'transfer_details.receipt_url'), 'tx_meta');

            if ($values['receipt_url'] === null) {
                $attachments = Arr::get($meta, 'attachments');
                if (is_iterable($attachments)) {
                    foreach ($attachments as $attachment) {
                        if (! is_array($attachment)) {
                            continue;
                        }

                        $setReceiptUrl(Arr::get($attachment, 'url'), 'tx_meta');

                        if ($values['receipt_url'] !== null) {
                            break;
                        }

                        $attachmentPath = Arr::get($attachment, 'path');
                        $attachmentDisk = Arr::get($attachment, 'disk');
                        $setReceiptPath($attachmentPath, $attachmentDisk, 'tx_meta');

                        if ($values['receipt_url'] !== null) {
                            break;
                        }
                    }
                }
            }

            if ($values['receipt_url'] === null) {
                $setReceiptPath($this->paymentTransaction->receipt_path, 'public', 'tx_columns');
            }

            $setReceiptPath(Arr::get($meta, 'transfer.receipt_path'), Arr::get($meta, 'transfer.receipt_disk'), 'tx_meta');
            $setReceiptPath(Arr::get($meta, 'transfer.receiptPath'), Arr::get($meta, 'transfer.receipt.disk'), 'tx_meta');
            $setReceiptPath(
                Arr::get($meta, 'transfer_details.receipt_path'),
                Arr::get($meta, 'transfer_details.receipt_disk') ?? Arr::get($meta, 'transfer_details.disk'),
                'tx_meta'
            );

            if ($values['transfer_reference'] === null) {
                $apply('transfer_reference', $this->paymentTransaction->payment_id, 'tx_columns');
                $apply('transfer_reference', $this->paymentTransaction->payment_signature, 'tx_columns');
            }
        }

        if ($values['receipt_url'] === null && isset($this->row['receipt_url'])) {
            $setReceiptUrl($this->row['receipt_url'], 'tx_columns');
        }

        if ($values['receipt_url'] === null && isset($this->row['receipt_path'])) {
            $setReceiptPath($this->row['receipt_path'], 'public', 'tx_columns');
        }

        if ($this->walletTransaction instanceof WalletTransaction) {
            $meta = $this->walletTransactionMeta();

            $apply('bank_name', Arr::get($meta, 'manual_bank.name'), 'wallet_tx');
            $apply('bank_name', Arr::get($meta, 'manual_bank.bank_name'), 'wallet_tx');
            $apply('bank_name', Arr::get($meta, 'bank.name'), 'wallet_tx');
            $apply('bank_name', Arr::get($meta, 'bank.bank_name'), 'wallet_tx');
            $apply('bank_name', Arr::get($meta, 'payload.bank_name'), 'wallet_tx');

            $apply('sender_name', Arr::get($meta, 'metadata.sender_name'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'metadata.sender'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'sender_name'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'transfer.sender_name'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'transfer.sender'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'transfer_details.sender_name'), 'wallet_tx');
            $apply('sender_name', Arr::get($meta, 'transfer_details.sender'), 'wallet_tx');

            $apply('transfer_reference', Arr::get($meta, 'metadata.transfer_reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'metadata.reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer_reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_code'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer.transfer_number'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer.reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_reference'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_code'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.transfer_number'), 'wallet_tx');
            $apply('transfer_reference', Arr::get($meta, 'transfer_details.reference'), 'wallet_tx');

            $apply('note', Arr::get($meta, 'metadata.note'), 'wallet_tx', true);
            $apply('note', Arr::get($meta, 'note'), 'wallet_tx', true);
            $apply('note', Arr::get($meta, 'transfer.note'), 'wallet_tx', true);
            $apply('note', Arr::get($meta, 'transfer_details.note'), 'wallet_tx', true);


            $walletNoteSources = [
                ['note' => Arr::get($meta, 'metadata.note'), 'source' => 'wallet_note'],
                ['note' => Arr::get($meta, 'note'), 'source' => 'wallet_note'],
                ['note' => Arr::get($meta, 'transfer.note'), 'source' => 'wallet_note'],
                ['note' => Arr::get($meta, 'transfer_details.note'), 'source' => 'wallet_note'],
            ];

            foreach ($walletNoteSources as $candidate) {
                if (! is_array($candidate) || ! array_key_exists('note', $candidate)) {
                    continue;
                }

                if ($values['sender_name'] === null) {
                    $extractedSender = $this->extractSenderNameFromNote($candidate['note']);
                    if ($extractedSender !== null) {
                        $apply('sender_name', $extractedSender, $candidate['source'] ?? 'wallet_tx');
                    }
                }

                if ($values['transfer_reference'] === null) {
                    $extractedReference = $this->extractTransferReferenceFromNote($candidate['note']);
                    if ($extractedReference !== null) {
                        $apply('transfer_reference', $extractedReference, $candidate['source'] ?? 'wallet_tx');
                    }
                }

                if ($values['sender_name'] !== null && $values['transfer_reference'] !== null) {
                    break;
                }
            }

            $receiptMeta = Arr::get($meta, 'receipt');
            if (is_array($receiptMeta)) {
                $setReceiptUrl(Arr::get($receiptMeta, 'url'), 'wallet_tx');
                if ($values['receipt_url'] === null || $values['receipt_path'] === null) {
                    $setReceiptPath(
                        Arr::get($receiptMeta, 'path'),
                        Arr::get($receiptMeta, 'disk'),
                        'wallet_tx'
                    );
                }
            }

            $setReceiptUrl(Arr::get($meta, 'receipt_url'), 'wallet_tx');
            $setReceiptUrl(Arr::get($meta, 'transfer.receipt_url'), 'wallet_tx');
            $setReceiptUrl(Arr::get($meta, 'transfer_details.receipt_url'), 'wallet_tx');

            $setReceiptPath(Arr::get($meta, 'transfer.receipt_path'), Arr::get($meta, 'transfer.receipt_disk'), 'wallet_tx');
            $setReceiptPath(Arr::get($meta, 'transfer.receiptPath'), Arr::get($meta, 'transfer.receipt.disk'), 'wallet_tx');
            $setReceiptPath(
                Arr::get($meta, 'transfer_details.receipt_path'),
                Arr::get($meta, 'transfer_details.receipt_disk') ?? Arr::get($meta, 'transfer_details.disk'),
                'wallet_tx'
            );
        }

        if (isset($this->row['transfer_details']) && is_array($this->row['transfer_details'])) {
            $transferDetails = $this->row['transfer_details'];
            $apply('sender_name', Arr::get($transferDetails, 'sender_name'), 'row');
            $apply('sender_name', Arr::get($transferDetails, 'sender'), 'row');
            $apply('transfer_reference', Arr::get($transferDetails, 'transfer_reference'), 'row');
            $apply('transfer_reference', Arr::get($transferDetails, 'transfer_code'), 'row');
            $apply('transfer_reference', Arr::get($transferDetails, 'transfer_number'), 'row');
            $apply('transfer_reference', Arr::get($transferDetails, 'reference'), 'row');
            $apply('note', Arr::get($transferDetails, 'note'), 'row', true);
            $setReceiptUrl(Arr::get($transferDetails, 'receipt_url'), 'row');
            $setReceiptPath(Arr::get($transferDetails, 'receipt_path'), Arr::get($transferDetails, 'receipt_disk'), 'row');


        }

        if ($values['bank_name'] === null) {
            $apply('bank_name', Arr::get($this->row, 'bank_name'), 'tx_columns');
            $apply('bank_name', Arr::get($this->row, 'manual_bank_name'), 'tx_columns');
        }

        if ($values['sender_name'] === null) {
            $apply('sender_name', Arr::get($this->row, 'sender_name'), 'tx_columns');
        }

        if ($values['transfer_reference'] === null) {
            $apply('transfer_reference', Arr::get($this->row, 'transfer_reference'), 'tx_columns');
            $apply('transfer_reference', Arr::get($this->row, 'reference'), 'tx_columns');
        }

        if ($values['note'] === null) {
            $apply('note', Arr::get($this->row, 'note'), 'tx_columns', true);
        }


        if ($values['sender_name'] === null || $values['transfer_reference'] === null) {
            $rowNoteCandidate = Arr::get($this->row, 'note');

            if ($values['sender_name'] === null) {
                $rowSender = $this->extractSenderNameFromNote($rowNoteCandidate);
                if ($rowSender !== null) {
                    $apply('sender_name', $rowSender, 'tx_columns');
                }
            }

            if ($values['transfer_reference'] === null) {
                $rowReference = $this->extractTransferReferenceFromNote($rowNoteCandidate);
                if ($rowReference !== null) {
                    $apply('transfer_reference', $rowReference, 'tx_columns');
                }
            }
        }



        $resolvedSource = 'tx_meta';
        foreach (['mpr', 'tx_meta', 'tx_columns', 'wallet_tx', 'row'] as $candidate) {
            if (in_array($candidate, $sources, true)) {
                $resolvedSource = $candidate;
                break;
            }
        }

        return [
            'bank_name' => $values['bank_name'],
            'sender_name' => $values['sender_name'],
            'transfer_reference' => $values['transfer_reference'],
            'note' => $values['note'],
            'receipt_url' => $values['receipt_url'],
            'receipt_path' => $values['receipt_path'],
            'source' => $resolvedSource,
        ];
    }

    public function jsonSerialize(): array
    {
        return $this->toArray();
    }

    private function manualPaymentRequestMeta(): array
    {
        $meta = $this->manualPaymentRequest?->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        return $meta;
    }

    private function transactionMeta(): array
    {
        $meta = $this->paymentTransaction?->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        return $meta;
    }

    private function walletTransactionMeta(): array
    {
        $meta = $this->walletTransaction?->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        return $meta;
    }

    private function normalizeString($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_bool($value) || $value === null) {
            return null;
        }

        if (is_numeric($value) && ! is_string($value)) {
            $value = (string) $value;
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '' || strcasecmp($trimmed, 'null') === 0) {
            return null;
        }

        return $trimmed;
    }

    private function normalizeMultiline($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_bool($value) || $value === null) {
            return null;
        }

        if (is_numeric($value) && ! is_string($value)) {
            return (string) $value;
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '' && $value !== '0') {
            return null;
        }

        return $value;
    }

    private function normalizeUrl(?string $url): ?string
    {
        $normalized = $this->normalizeString($url);

        if ($normalized === null) {
            return null;
        }

        if (! filter_var($normalized, FILTER_VALIDATE_URL)) {
            return null;
        }

        return $normalized;
    }

    private function sanitizeBankName(string $value): ?string
    {
        $normalized = trim($value);

        if ($normalized === '') {
            return null;
        }

        $lower = Str::lower($normalized);

        $genericValues = array_merge(
            ['manual_bank', 'manual banks', 'manual bank', 'manual transfer', 'bank transfer', 'bank'],
            ManualPaymentRequest::manualBankGatewayAliases()
        );

        foreach ($genericValues as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            if ($lower === Str::lower($candidate)) {
                return null;
            }
        }

        $defaultDisplay = ManualBank::defaultDisplayName();
        if (is_string($defaultDisplay) && Str::lower(trim($defaultDisplay)) === $lower) {
            return null;
        }

        return $normalized;
    }

    private function generateStorageUrl($path, $disk = null): ?string
    {
        $normalizedPath = $this->normalizeString($path);

        if ($normalizedPath === null) {
            return null;
        }

        if (filter_var($normalizedPath, FILTER_VALIDATE_URL)) {
            return $normalizedPath;
        }

        $diskName = $this->normalizeString($disk) ?? 'public';

        try {
            $diskInstance = Storage::disk($diskName);

            $url = null;

            if (method_exists($diskInstance, 'temporaryUrl')) {
                try {
                    $url = $diskInstance->temporaryUrl($normalizedPath, now()->addMinutes(10));
                } catch (Throwable $temporaryUrlError) {
                    $url = null;
                }
            }

            if (! is_string($url) || trim($url) === '') {
                try {
                    $url = $diskInstance->url($normalizedPath);
                } catch (Throwable $directUrlError) {
                    $url = null;
                }
            }

            return $this->normalizeString($url);
        } catch (Throwable) {
            return null;
        }
    }



    private function extractSenderNameFromNote($note): ?string
    {
        return $this->extractValueFromNote($note, [
            '~(?:اسم\s*المرسل)\s*[:\-]\s*(.+)$~u',
            '~(?:sender\s*name)\s*[:\-]\s*(.+)$~iu',
            '~(?:account\s*name)\s*[:\-]\s*(.+)$~iu',
        ]);
    }

    private function extractTransferReferenceFromNote($note): ?string
    {
        $value = $this->extractValueFromNote($note, [
            '~(?:رقم\s*(?:الحوالة|التحويل|العملية|المرجع))\s*[:\-#]\s*(.+)$~u',
            '~(?:reference|transfer\s*(?:number|reference)|transaction\s*(?:number|reference)|payment\s*(?:number|reference)|ref)\s*[:\-#]\s*(.+)$~iu',
        ]);

        if ($value === null) {
            return null;
        }

        return $this->normalizeString(rtrim($value, " .،:-"));
    }

    private function extractValueFromNote($note, array $patterns): ?string
    {
        if ($note instanceof \Stringable) {
            $note = (string) $note;
        }

        if (is_array($note)) {
            $flattened = Arr::flatten($note);
            $segments = [];

            foreach ($flattened as $segment) {
                if ($segment instanceof \Stringable) {
                    $segment = (string) $segment;
                }

                if (is_scalar($segment)) {
                    $segments[] = (string) $segment;
                }
            }

            $note = $segments === [] ? null : implode("\n", $segments);
        }

        $normalized = $this->normalizeMultiline($note);

        if ($normalized === null) {
            return null;
        }

        $lines = preg_split('/\R/u', $normalized) ?: [$normalized];

        foreach ($lines as $line) {
            if (! is_string($line)) {
                continue;
            }

            $trimmedLine = trim($line);

            if ($trimmedLine === '') {
                continue;
            }

            foreach ($patterns as $pattern) {
                if (@preg_match($pattern, '') === false) {
                    continue;
                }

                if (preg_match($pattern, $trimmedLine, $matches)) {
                    $candidate = $matches[1] ?? null;
                    $normalizedCandidate = $this->normalizeString($candidate);

                    if ($normalizedCandidate !== null) {
                        return $normalizedCandidate;
                    }
                }
            }
        }

        return null;
    }
}
