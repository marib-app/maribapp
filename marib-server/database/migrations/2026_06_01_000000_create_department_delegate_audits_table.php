<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('department_delegate_audits', function (Blueprint $table) {
            $table->id();
            $table->string('department');
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event');
            $table->string('reason')->nullable();
            $table->json('difference');
            $table->timestamps();

            $table->index('department');
            $table->index('event');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('department_delegate_audits');
    }
};