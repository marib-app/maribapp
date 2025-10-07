<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('users', function (Blueprint $table) {
            // Información de contacto adicional (como múltiples números de WhatsApp)
            $table->json('additional_contacts')->nullable()->after('mobile');
            
            // Información bancaria para pagos
            $table->json('payment_info')->nullable()->after('address');
            
            // Información de ubicación
            $table->string('location')->nullable()->after('address');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('additional_contacts');
            $table->dropColumn('payment_info');
            $table->dropColumn('location');
        });
    }
}; 