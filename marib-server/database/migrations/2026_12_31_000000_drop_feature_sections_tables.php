<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::dropIfExists('feature_section_items');
        Schema::dropIfExists('feature_sections');
    }

    public function down(): void
    {
        // Legacy ribbon sections were removed permanently.
    }
};

