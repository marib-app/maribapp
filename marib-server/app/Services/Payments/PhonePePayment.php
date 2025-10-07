<?php

namespace App\Services\Payments;

use Auth;
use PhonePe\PhonePe as PhonePeSDK;
use Exception;

class PhonePePayment implements PaymentInterface
{
    private string $saltKey;
    private string $merchantId;
    private string $callbackUrl;

    public function __construct($merchantId, $saltKey)
    {
        $this->merchantId = $merchantId;
        $this->saltKey = $saltKey;
        $this->callbackUrl = url('/webhook/phonePe');
    }

    /**
     * Create payment intent for PhonePe
     *
     * @param $amount
     * @param $customMetaData
     * @return array
     * @throws Exception
     */
    public function createPaymentIntent($amount, $customMetaData)
    {
        if($customMetaData['platform_type'] == 'app') {
            $redirectUrl = route('phonepe.success') ;
        }else{
            $redirectUrl = route('phonepe.success.web');
        }
        $amount = $this->minimumAmountValidation('INR', $amount);
        $transactionId = uniqid();
        $metaData = 't' .'-'. $customMetaData['payment_transaction_id'] .'-'. 'p' .'-'. $customMetaData['package_id'];
        $phonepe = PhonePeSDK::init(
            $this->merchantId,
            $metaData,
            $this->saltKey,
            "1",
            $redirectUrl,
            $this->callbackUrl,
            "DEV"
        );

        $amountInPaisa = $amount * 100;
        $userMobile = Auth::user()->mobile;
         $redirectURL = $phonepe->standardCheckout()->createTransaction($amountInPaisa, $userMobile, $metaData)->getTransactionURL();
        // $response = $this->sendRequest('https://api-preprod.phonepe.com/apis/pg-sandbox/pg/v1/pay', $requestBody, $signature);
        if (!empty($redirectURL)) {
            return $this->formatPaymentIntent($transactionId, $amount, 'INR', 'pending', $customMetaData, $redirectURL);
        }

        throw new Exception("Error initiating payment: " . $redirectURL);
    }

    /**
     * Create and format payment intent for PhonePe
     *
     * @param $amount
     * @param $customMetaData
     * @return array
     * @throws Exception
     */
    public function createAndFormatPaymentIntent($amount, $customMetaData): array
    {
        return $this->createPaymentIntent($amount, $customMetaData);
    }

    /**
     * Retrieve payment intent (check payment status)
     *
     * @param $transactionId
     * @return array
     * @throws Exception
     */
    public function retrievePaymentIntent($transactionId): array
    {
        $statusUrl = 'https://api.phonepe.com/v3/transaction/' . $transactionId . '/status';
        $signature = $this->generateSignature(''); // Adjust if needed based on PhonePe requirements

        $response = $this->sendRequest($statusUrl, '', $signature);

        if ($response['success']) {
            return $this->formatPaymentIntent($transactionId, $response['amount'], 'INR', $response['status'], [], $response);
        }

        throw new Exception("Error fetching payment status: " . $response['message']);
    }

    /**
     * Format payment intent response
     *
     * @param $id
     * @param $amount
     * @param $currency
     * @param $status
     * @param $metadata
     * @param $paymentIntent
     * @return array
     */
    public function formatPaymentIntent($id, $amount, $currency, $status, $metadata, $paymentIntent): array
    {
        return [
            'id' => $id,
            'amount' => $amount,
            'currency' => $currency,
            'metadata' => $metadata,
            'status' => match ($status) {
                "SUCCESS" => "succeeded",
                "PENDING" => "pending",
                "FAILED" => "failed",
                default => "unknown"
            },
            'payment_gateway_response' => $paymentIntent
        ];
    }

    /**
     * Minimum amount validation
     *
     * @param $currency
     * @param $amount
     * @return float|int
     */
    public function minimumAmountValidation($currency, $amount)
    {
        $minimumAmount = match ($currency) {
            'INR' => 1.00, // 1 Rupee
            default => 0.50
        };

        return ($amount >= $minimumAmount) ? $amount : $minimumAmount;
    }

    /**
     * Generate HMAC signature for PhonePe
     *
     * @param $encodedRequestBody
     * @return string
     */
    private function generateSignature($encodedRequestBody): string
    {
        // Base64 encode the request body
        $base64Payload = base64_encode($encodedRequestBody);

        // Concatenate Base64 payload, endpoint, and salt key
        $stringToHash = $base64Payload . '/pg/v1/pay' . $this->saltKey;

        // Hash the string using SHA256
        $hash = hash('sha256', $stringToHash);

        // Append salt index (Assumed to be 1 in this example)
        return $hash . '###' . 1;
    }

    /**
     * Send cURL request to PhonePe API
     *
     * @param $url
     * @param $requestBody
     * @param $signature
     * @return array
     */
    // private function sendRequest($url, $requestBody, $signature): array
    // {
    //     // dd($requestBody);
    //     $ch = curl_init($url);
    //     curl_setopt($ch, CURLOPT_POST, 1);
    //     curl_setopt($ch, CURLOPT_POSTFIELDS, $requestBody);
    //     curl_setopt($ch, CURLOPT_HTTPHEADER, [
    //         'Content-Type: application/json',
    //         'X-VERIFY: ' . $signature,
    //     ]);
    //     curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    //     $response = curl_exec($ch);
    //     curl_close($ch);
    //     return json_decode($response, true);
    // }
}
