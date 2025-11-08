<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        // 1) فرض قيمة افتراضية وعدم السماح بـ NULL في حالة الدفع لطلبات الخدمة
        DB::statement("UPDATE service_requests SET payment_status='pending' WHERE payment_status IS NULL");
        DB::statement("
            ALTER TABLE service_requests
            MODIFY COLUMN payment_status ENUM('pending','review','paid','rejected','cancelled')
            NOT NULL DEFAULT 'pending'
        ");

        // 2) عمود مولَّد لفهرسة نوع السياق من meta (مع فهرس)
        if (!Schema::hasColumn('payment_transactions', 'context_type')) {
            DB::unprepared("
                ALTER TABLE payment_transactions
                ADD COLUMN context_type VARCHAR(64)
                GENERATED ALWAYS AS (LOWER(JSON_UNQUOTE(JSON_EXTRACT(`meta`, '$.context.type')))) VIRTUAL
            ");
            DB::unprepared("CREATE INDEX idx_pt_context_type ON payment_transactions (context_type)");
        }

        if (! Schema::hasColumn('manual_payment_requests', 'service_request_id')) {
            Schema::table('manual_payment_requests', function (Blueprint $table): void {
                $table->foreignId('service_request_id')
                    ->nullable()
                    ->after('payable_id')
                    ->constrained('service_requests')
                    ->nullOnDelete();
            });

            DB::table('manual_payment_requests')
                ->whereNull('service_request_id')
                ->whereIn('payable_type', [
                    'App\\Models\\ServiceRequest',
                    'service_request',
                    'service_requests',
                ])
                ->update(['service_request_id' => DB::raw('payable_id')]);
        }
        // 3) تريجرات ضبط/تحقق payment_transactions (توحيد تسميات البوابة + قيود الربط)
        DB::unprepared("DROP TRIGGER IF EXISTS trg_pt_norm_gateway_bi");
        DB::unprepared("CREATE TRIGGER trg_pt_norm_gateway_bi
        BEFORE INSERT ON payment_transactions FOR EACH ROW
        BEGIN
            SET @gw := LOWER(TRIM(NEW.payment_gateway));
            IF @gw IN ('manual-banks','manual bank','manualbank','bank','bank_transfer','banktransfer','offline','internal') THEN
                SET NEW.payment_gateway = 'manual_bank';
            END IF;
            IF @gw IN ('alsharq','al-sharq') THEN
                SET NEW.payment_gateway = 'bank_alsharq';
            END IF;

            IF LOWER(TRIM(NEW.payment_gateway))='wallet' AND NEW.manual_payment_request_id IS NOT NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='wallet PT cannot reference manual_payment_request';
            END IF;

            IF LOWER(TRIM(NEW.payment_gateway))='manual_bank' AND (NEW.manual_payment_request_id IS NULL OR NEW.manual_payment_request_id=0) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='manual_bank PT must have manual_payment_request_id';
            END IF;

            IF NEW.manual_payment_request_id IS NOT NULL THEN
                SET @bn := (SELECT bank_name FROM manual_payment_requests WHERE id=NEW.manual_payment_request_id);
                IF (@bn IS NULL OR @bn='') THEN
                    SET @bn2 := JSON_UNQUOTE(JSON_EXTRACT(NEW.meta, '$.transfer.bank_name'));
                    IF (@bn2 IS NOT NULL AND @bn2<>'') THEN
                        UPDATE manual_payment_requests SET bank_name=@bn2 WHERE id=NEW.manual_payment_request_id;
                    ELSE
                        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='manual_bank missing bank_name';
                    END IF;
                END IF;
            END IF;
        END");

        DB::unprepared("DROP TRIGGER IF EXISTS trg_pt_norm_gateway_bu");
        DB::unprepared("CREATE TRIGGER trg_pt_norm_gateway_bu
        BEFORE UPDATE ON payment_transactions FOR EACH ROW
        BEGIN
            SET @gw := LOWER(TRIM(NEW.payment_gateway));
            IF @gw IN ('manual-banks','manual bank','manualbank','bank','bank_transfer','banktransfer','offline','internal') THEN
                SET NEW.payment_gateway = 'manual_bank';
            END IF;
            IF @gw IN ('alsharq','al-sharq') THEN
                SET NEW.payment_gateway = 'bank_alsharq';
            END IF;

            IF LOWER(TRIM(NEW.payment_gateway))='wallet' AND NEW.manual_payment_request_id IS NOT NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='wallet PT cannot reference manual_payment_request';
            END IF;

            IF LOWER(TRIM(NEW.payment_gateway))='manual_bank' AND (NEW.manual_payment_request_id IS NULL OR NEW.manual_payment_request_id=0) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='manual_bank PT must have manual_payment_request_id';
            END IF;
        END");

        // 4) تريجرات SR: منع paid/review بدون PT + فرض ctx=service_request عند الربط
        DB::unprepared("DROP TRIGGER IF EXISTS trg_sr_enforce_bi");
        DB::unprepared("CREATE TRIGGER trg_sr_enforce_bi
        BEFORE INSERT ON service_requests FOR EACH ROW
        BEGIN
            IF NEW.payment_status IN ('paid','review') AND (NEW.payment_transaction_id IS NULL OR NEW.payment_transaction_id=0) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SR with paid/review must link a payment_transaction';
            END IF;

            IF NEW.payment_transaction_id IS NOT NULL THEN
                SET @ctx := (SELECT COALESCE(context_type, LOWER(JSON_UNQUOTE(JSON_EXTRACT(meta,'$.context.type'))))
                             FROM payment_transactions WHERE id=NEW.payment_transaction_id);
                IF COALESCE(@ctx,'') <> 'service_request' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SR must link PT with context=service_request';
                END IF;
            END IF;
        END");

        DB::unprepared("DROP TRIGGER IF EXISTS trg_sr_enforce_bu");
        DB::unprepared("CREATE TRIGGER trg_sr_enforce_bu
        BEFORE UPDATE ON service_requests FOR EACH ROW
        BEGIN
            IF NEW.payment_status IN ('paid','review') AND (NEW.payment_transaction_id IS NULL OR NEW.payment_transaction_id=0) THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SR with paid/review must link a payment_transaction';
            END IF;

            IF NEW.payment_transaction_id IS NOT NULL THEN
                SET @ctx := (SELECT COALESCE(context_type, LOWER(JSON_UNQUOTE(JSON_EXTRACT(meta,'$.context.type'))))
                             FROM payment_transactions WHERE id=NEW.payment_transaction_id);
                IF COALESCE(@ctx,'') <> 'service_request' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SR must link PT with context=service_request';
                END IF;
            END IF;
        END");

        // 5) تريجرات WT: يجب أن تشير إلى PT نوعه wallet فقط
        DB::unprepared("DROP TRIGGER IF EXISTS trg_wt_wallet_only_bi");
        DB::unprepared("CREATE TRIGGER trg_wt_wallet_only_bi
        BEFORE INSERT ON wallet_transactions FOR EACH ROW
        BEGIN
            IF NEW.payment_transaction_id IS NOT NULL THEN
                SET @gw := (SELECT LOWER(TRIM(payment_gateway)) FROM payment_transactions WHERE id=NEW.payment_transaction_id);
                IF COALESCE(@gw,'') <> 'wallet' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='wallet_transactions must link to wallet PT';
                END IF;
            END IF;
        END");

        DB::unprepared("DROP TRIGGER IF EXISTS trg_wt_wallet_only_bu");
        DB::unprepared("CREATE TRIGGER trg_wt_wallet_only_bu
        BEFORE UPDATE ON wallet_transactions FOR EACH ROW
        BEGIN
            IF NEW.payment_transaction_id IS NOT NULL THEN
                SET @gw := (SELECT LOWER(TRIM(payment_gateway)) FROM payment_transactions WHERE id=NEW.payment_transaction_id);
                IF COALESCE(@gw,'') <> 'wallet' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='wallet_transactions must link to wallet PT';
                END IF;
            END IF;
        END");

        // 6) إصلاح AUTO_INCREMENT (يتجاهل الجداول الفارغة تلقائياً)
        DB::unprepared("
            SET @n := (SELECT IFNULL(MAX(id),0)+1 FROM payment_transactions);
            SET @sql := CONCAT('ALTER TABLE payment_transactions AUTO_INCREMENT=', @n);
            PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

            SET @n := (SELECT IFNULL(MAX(id),0)+1 FROM service_requests);
            SET @sql := CONCAT('ALTER TABLE service_requests AUTO_INCREMENT=', @n);
            PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

            SET @n := (SELECT IFNULL(MAX(id),0)+1 FROM manual_payment_requests);
            SET @sql := CONCAT('ALTER TABLE manual_payment_requests AUTO_INCREMENT=', @n);
            PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

            SET @n := (SELECT IFNULL(MAX(id),0)+1 FROM wallet_transactions);
            SET @sql := CONCAT('ALTER TABLE wallet_transactions AUTO_INCREMENT=', @n);
            PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
        ");
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        // F?F?F? F?F?F?F??/?????????????/??????F?F?F?F?F? F?F?F? F?F?F?
        DB::unprepared("DROP TRIGGER IF EXISTS trg_pt_norm_gateway_bi");
        DB::unprepared("DROP TRIGGER IF EXISTS trg_pt_norm_gateway_bu");
        DB::unprepared("DROP TRIGGER IF EXISTS trg_sr_enforce_bi");
        DB::unprepared("DROP TRIGGER IF EXISTS trg_sr_enforce_bu");
        DB::unprepared("DROP TRIGGER IF EXISTS trg_wt_wallet_only_bi");
        DB::unprepared("DROP TRIGGER IF EXISTS trg_wt_wallet_only_bu");

        if (Schema::hasColumn('payment_transactions', 'context_type')) {
            DB::unprepared("DROP INDEX idx_pt_context_type ON payment_transactions");
            DB::unprepared("ALTER TABLE payment_transactions DROP COLUMN context_type");
        }

        if (Schema::hasColumn('manual_payment_requests', 'service_request_id')) {
            Schema::table('manual_payment_requests', function (Blueprint $table): void {
                $table->dropForeign(['service_request_id']);
                $table->dropColumn('service_request_id');
            });
        }

        // F?F?F? payment_status F?F?F?F?F?F? F?F?? F?
        DB::statement("ALTER TABLE service_requests MODIFY COLUMN payment_status VARCHAR(32) NULL DEFAULT NULL");
    }
};
