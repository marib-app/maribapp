import re, pathlib
src = pathlib.Path("app/Http/Controllers/UserVerificationController.php").read_text(encoding="utf-8")
pattern = r"\$user_token = UserFcmToken::where\('user_id', \$verification_field->user->id\)->pluck\('fcm_token'\)->toArray\(\);" 
print('found user_token', bool(re.search(pattern, src)))
print('snippet around user_token:')
idx = src.find("$user_token = UserFcmToken")
print(src[idx-40:idx+200])