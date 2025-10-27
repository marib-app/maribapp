
# دليل العمل والنسخ الاحتياطي لمجلد `maribsrv` (يشمل: `marib-app` و`marib-server`)

> الهدف: تواصل العمل دائمًا على فرع **main** وتحتفظ بنقاط رجوع (Backups) عبر **Tags** بدون الحاجة لتغيير الفروع.

---

## 0) الدخول إلى مسار المشروع (Windows PowerShell)
نفّذ الأوامر التالية لفتح المجلد الصحيح:
```powershell
cd C:\Users\abo-hassn\Desktop\maribservices\maribsrv
```
php artisan migrate

php artisan serve --host=0.0.0.0 --port=8000

php artisan serve --host=0.0.0.0 --port=9001

npm run dev -- --hostname 0.0.0.0 --port 3010
npx next dev -H 0.0.0.0 -p 3000


Get-Content .\storage\logs\laravel.log -Tail 100

git status; git add -A; git commit -m "msg"; git push


php artisan cache:clear; php artisan config:clear ;  php artisan route:clear





# افتح اللوج وراقب كل الأخطاء المهمة
Get-Content .\storage\logs\laravel.log -Tail 0 -Wait `
| Select-String -Pattern "payment-requests|PaymentRequest|PaymentRequestTableQuery|SQLSTATE|QueryException|TypeError|ErrorException|Undefined|Base table|Call to"





// نسخه احتياطية مرقمه 


# === Marib backup tag: backup_maribsrv_N ===
cd C:\Users\abo-hassn\Desktop\maribservices\maribsrv

# 1) وقت فعلي + بادئة التاج
$ts     = Get-Date -Format 'yyyy-MM-dd HH:mm'
$prefix = 'backup_maribsrv_'

# 2) اجلب التاجز من الريموت وحسب الرقم التالي
git fetch --tags
$existing = git tag -l "$prefix*" |
  ForEach-Object { $_ -replace '^backup_maribsrv_','' } |
  Where-Object { $_ -match '^\d+$' } |
  ForEach-Object { [int]$_ }
$next = if ($existing) { ($existing | Sort-Object -Descending | Select-Object -First 1) + 1 } else { 1 }
$tag  = "$prefix$next"

# 3) جهّز الكوميت (حتى لو ما في تغييرات)
git add -A
$staged = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($staged)) {
  git commit --allow-empty -m "checkpoint: $ts"
} else {
  git commit -m "checkpoint: $ts"
}

# 4) أنشئ التاج وادفعه مع main
git tag -a $tag -m "Backup $tag @ $ts"
git push origin HEAD:main
git push origin $tag

# 5) عرض النتيجة
git tag -l "$prefix*" --sort=version:refname
Write-Host "Created tag: $tag at $ts"



الناتج سيكون:

 backup_maribsrv_1, ثم backup_maribsrv_2, backup_maribsrv_3…
 
 تلقائيًا. التاريخ محفوظ في رسالة التاج والكومِت.








استعادة نسخه محدده 


# 0) اذهب لجذر المشروع
cd C:\Users\abo-hassn\Desktop\maribservices\maribsrv

# 1) (اختياري لكن موصى به) خزّن أي تغييرات غير مُكمّتة، ويشمل غير المتتبَّعة
git stash push -m "wip-before-restore-backup_maribsrv_7" --include-untracked

# 2) احضر التاقات وتحقق من وجود المطلوب
git fetch --tags
git tag -l backup_maribsrv_7
git show --no-patch --oneline backup_maribsrv_7

# 3) ارجع محليًا لنسخة التاق (لا يدفع للريموت)
git switch main
git reset --hard backup_maribsrv_7
git clean -fdx        # يحذف أي ملفات/مجلدات غير متتبَّعة

# 4) (اختياري) submodules إن وُجدت
git submodule update --init --recursive

# 5) تحقق أننا على نفس نسخة التاق
git rev-parse --short HEAD
git rev-parse --short backup_maribsrv_7
# يجب أن يكون الناتجان متطابقين

# ====== إن كان عندك Laravel في المجلد marib-server ======
cd .\marib-server
composer install --no-dev --prefer-dist --no-interaction
if (!(Test-Path .env) -and (Test-Path .env.example)) { Copy-Item .env.example .env }

# (إذا APP_KEY غير مضبوط)
php artisan key:generate --force

# تهيئة التخزين والكاش
mkdir -Force .\storage\framework\sessions | Out-Null
mkdir -Force .\storage\framework\cache\data | Out-Null
mkdir -Force .\storage\framework\views | Out-Null
php artisan optimize:clear
php artisan storage:link










تنظيف الطلبات 
تنظيف جداول الطلبات/الخدمات/المدفوعات (TRUNCATE + إعادة الترقيم)






$MYSQL = 'mysql --default-character-set=utf8mb4 -h 127.0.0.1 -u root -D maribsrv -e'
$SQL = @"
SET FOREIGN_KEY_CHECKS=0;

-- خدمات + ربطها
TRUNCATE TABLE service_requests;

-- معاملات المحفظة (لو مربوطة بمعاملات الدفع)
TRUNCATE TABLE wallet_transactions;

-- معاملات الدفع + طلبات الدفع اليدوي
TRUNCATE TABLE payment_transactions;
TRUNCATE TABLE manual_payment_requests;

-- الطلبات (إن كانت ضمن الاختبار)
TRUNCATE TABLE orders;

SET FOREIGN_KEY_CHECKS=1;
"@
iex "$MYSQL `"$SQL`""











---

## 1) تهيئة أولية (تنفَّذ مرّة واحدة فقط إن لم تكن مهيّئًا)
> إذا سبق ورفعت المشروع فهذا القسم يمكنك تجاوزه.
```powershell

git init
git add -A
git commit -m "initial commit — add marib-app and marib-server"
git branch -M main
git remote add origin https://github.com/maribservices/maribsrv.git
git push -u origin main
```

---

## 2) الروتين اليومي المقترح على **main** (بدون فروع)

### A) حفظ نسخة قبل بدء العمل اليومي
> لقطة قبل أي تغييرات لليوم.
```powershell
cd C:\Users\abo-hassn\Desktop\maribservices\maribsrv
git add -A
git commit -m "checkpoint: before work on YYYY-MM-DD"
git tag -a backup-YYYY-MM-DD-start -m "Backup before work"
git push
git push origin backup-YYYY-MM-DD-start
```

### B) حفظ نسخ أثناء اليوم (بعد إنجاز مهمة كبيرة)
> يمكنك أخذ أكثر من نسخة في نفس اليوم. اختر أحد الأسلوبين:
- **ترقيم متسلسل داخل اليوم:**
```powershell
git add -A
git commit -m "checkpoint: task X done"
git tag -a backup-YYYY-MM-DD-1 -m "Backup after task X"
git push
git push origin backup-YYYY-MM-DD-1
```
- **ختم بالوقت (مفضّل):**
```powershell
git add -A
git commit -m "checkpoint: task X done"
git tag -a backup-YYYY-MM-DD-HHmm -m "Backup after task X"
git push
git push origin backup-YYYY-MM-DD-HHmm
```

> **ملاحظة:** إذا لم تتغيّر الملفات لكن تريد نقطة رجوع، استخدم:
```powershell
git commit --allow-empty -m "checkpoint: timestamp only"
```

### C) حفظ نسخة نهاية اليوم
```powershell
git add -A
git commit -m "end of day YYYY-MM-DD"
git tag -a backup-YYYY-MM-DD-end -m "Backup end of day"
git push
git push origin backup-YYYY-MM-DD-end
```

> استبدل `YYYY-MM-DD` و`HHmm` بالقيم الفعلية (مثل `2025-10-07` و`1630`).

---

## 3) اختصار تلقائي (PowerShell) لعمل نسخة بسرعة
> ينشئ Tag فريد تلقائياً بعنوان: `backup-YYYY-MM-DD-HHmm[-note]`.  
> **تنفيذ مرة واحدة:** أضِف الدالة التالية في جلسة PowerShell (أو في ملف الـ profile لتصبح دائمة).
```powershell
function gbackup {
  param([string]$note = "")
  $stamp = (Get-Date -Format "yyyy-MM-dd-HHmm")
  $tag = ("backup-{0}{1}" -f $stamp, ($(if($note -ne ""){"-$note"})))
  git add -A
  git commit -m "checkpoint: $tag" 2>$null; if ($LASTEXITCODE -ne 0) { git commit --allow-empty -m "checkpoint: $tag" }
  git tag -a $tag -m "backup $tag"
  git push
  git push origin $tag
  Write-Host "Created and pushed tag: $tag"
}
```
**الاستخدام:**
```powershell
cd C:\Users\abo-hassn\Desktop\maribservices\maribsrv
gbackup                # مثال: backup-2025-10-07-1630
gbackup feature-X      # مثال: backup-2025-10-07-1630-feature-X
```

---

## 4) الرجوع لأي نسخة (Tag)
- **عرض جميع النسخ:**
```powershell
git tag --list "backup-*"
```
- **فتح نسخة للعرض فقط:**
```powershell
git checkout backup-YYYY-MM-DD-1
```
- **إنشاء فرع جديد للرجوع والعمل عليه:**
```powershell
git checkout -b restore-YYYY-MM-DD-1 backup-YYYY-MM-DD-1
```
- **العودة مجددًا لأحدث commit على main:**
```powershell
git checkout main
```

---

## 5) إدارة الوسوم (Tags) إذا احتجت حذف/إعادة تسمية
- **حذف وسم محليًا وعلى GitHub:**
```powershell
git tag -d backup-YYYY-MM-DD-1
git push origin :refs/tags/backup-YYYY-MM-DD-1
```
> بعد الحذف يمكنك إنشاءه من جديد بالاسم الصحيح.

---

## 6) ملاحظات مهمة
- كل `commit` و`tag` يأخذ **لقطة كاملة** لكل محتوى مجلد `maribsrv` بما فيه: `marib-app`, `marib-server`, و`README.md`.
- عند طلب GitHub لكلمة مرور، استخدم **Personal Access Token** بدل كلمة المرور.
- يُفضَّل كتابة رسائل واضحة في الكومِت/الوسم لتسهيل الرجوع لاحقًا.

---

**انتهى. بالتوفيق!**
