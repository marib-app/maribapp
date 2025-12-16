import re, pathlib
path = pathlib.Path("app/Http/Controllers/UserVerificationController.php")
src = path.read_text(encoding="utf-8")
pattern = r"\$user_token = UserFcmToken::where\('user_id', \$verification_field->user->id\)->pluck\('fcm_token'\)->toArray\(\);.*?\r?\n\s*if \(\$request->expectsJson\(\) \|\| \$request->ajax\(\)\) \{"
new_block = """
            $user_token = UserFcmToken::where('user_id', $verification_field->user->id)->pluck('fcm_token')->toArray();
            $title = 'تنبيه التوثيق';
            $body = $newStatus === 'approved'
                ? "تهانياً تم توثيق حسابك"
                : "تم تحديث حالة طلب التوثيق إلى " . ucfirst($request->status);
            if (!empty($user_token)) {
                $notificationResponse = NotificationService::sendFcmNotification(
                    $user_token,
                    $title,
                    $body,
                    "verifcation-request-update",
                    ['id' => $id]
                );

                if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                    Log::error('UserVerificationController: Failed to send verification status notification', $notificationResponse);

                    ResponseService::warningResponse(
                        $notificationResponse['message'] ?? 'Failed to send verification notification.',
                        $notificationResponse,
                        $notificationResponse['code'] ?? null
                    );
                }
            }
            try {
                Notifications::create([
                    'title' => $title,
                    'message' => $body,
                    'image' => '',
                    'item_id' => null,
                    'send_to' => 'selected',
                    'user_id' => (string) $verification_field->user->id,
                    'category' => 'account',
                    'meta' => [
                        'type' => 'verification',
                        'request_id' => $id,
                        'status' => $newStatus,
                    ],
                ]);
            } catch (Throwable $e) {
                Log::error('UserVerificationController: Failed to persist verification notification', {'error': $e->getMessage()});
            }
            if ($request->expectsJson() || $request->ajax()) {
"""
new_src, n = re.subn(pattern, new_block, src, flags=re.S)
if not n:
    raise SystemExit('pattern not found')
path.write_text(new_src, encoding="utf-8")
print('patched', n)