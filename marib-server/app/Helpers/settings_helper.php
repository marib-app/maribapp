<?php

use App\Models\Language;
use Illuminate\Support\Facades\Session;

function current_language() {
    $language = Session::get('language');

    // إذا كان الكائن المخزن يحتوي على الخاصية rtl فنحن في الوضع الصحيح بالفعل
    if (is_object($language) && isset($language->rtl)) {
        $code = $language->code ?? $language->locale ?? config('app.locale', 'ar');
        Session::put('locale', $code);
        app()->setLocale($code);
        return;
    }

    // دعم المصفوفات المخزنة في الجلسة والتي تحتوي على rtl
    if (is_array($language) && array_key_exists('rtl', $language)) {
        $code = $language['code'] ?? $language['locale'] ?? config('app.locale', 'ar');
        $languageObject = (object) [
            'code' => $code,
            'rtl' => (bool) $language['rtl'],
        ];

        Session::put('language', $languageObject);
        Session::put('locale', $languageObject->code);
        app()->setLocale($languageObject->code);
        return;
    }

    // إذا كانت القيمة مجرد سلسلة فحاول جلب الكائن من قاعدة البيانات
    if (is_string($language) && $language !== '') {
        $languageModel = Language::where('code', $language)->first();
        if ($languageModel) {
            Session::put('language', $languageModel);
            Session::put('locale', $languageModel->code);
            app()->setLocale($languageModel->code);
            return;
        }


    // fallback: استخدام الإعداد الافتراضي للتطبيق أو العربية إذا لم تتوفر لغة صالحة
    $defaultCode = config('app.locale', 'ar');
    $defaultLanguage = Language::where('code', $defaultCode)->first();

    if (!$defaultLanguage) {
        $defaultLanguage = (object) [
            'code' => $defaultCode,
            'rtl' => $defaultCode === 'ar',
        ];
    }

    Session::put('language', $defaultLanguage);
    $locale = $defaultLanguage->code ?? $defaultCode;
    Session::put('locale', $locale);
    app()->setLocale($locale);


    }
}

function get_language() {
    return Language::get();
}
