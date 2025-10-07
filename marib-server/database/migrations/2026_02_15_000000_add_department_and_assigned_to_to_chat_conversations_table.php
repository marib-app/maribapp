<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (! Schema::hasColumn('chat_conversations', 'department')) {
            Schema::table('chat_conversations', function (Blueprint $table) {
                $table->string('department')->nullable()->index();
            });
        }

        if (! Schema::hasColumn('chat_conversations', 'assigned_to')) {
            Schema::table('chat_conversations', function (Blueprint $table) {
                $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $self = $this;

        if (Schema::hasColumn('chat_conversations', 'assigned_to')) {
            Schema::table('chat_conversations', function (Blueprint $table) use ($self) {
                $foreignKeyName = 'chat_conversations_assigned_to_foreign';

                if ($self->tableHasForeignKey('chat_conversations', $foreignKeyName)) {
                    $table->dropForeign($foreignKeyName);
                }

                $table->dropColumn('assigned_to');
            });
        }

        if (Schema::hasColumn('chat_conversations', 'department')) {
            Schema::table('chat_conversations', function (Blueprint $table) use ($self) {
                $indexName = 'chat_conversations_department_index';

                if ($self->tableHasIndex('chat_conversations', $indexName)) {
                    $table->dropIndex($indexName);
                }

                $table->dropColumn('department');
            });
        }
    }

    private function tableHasIndex(string $table, string $index): bool
    {
        try {
            $schemaManager = Schema::getConnection()->getDoctrineSchemaManager();

            return array_key_exists($index, $schemaManager->listTableIndexes($table));
        } catch (\Throwable $exception) {
            return false;
        }
    }

    private function tableHasForeignKey(string $table, string $foreignKey): bool
    {
        try {
            $schemaManager = Schema::getConnection()->getDoctrineSchemaManager();

            foreach ($schemaManager->listTableForeignKeys($table) as $schemaForeignKey) {
                if ($schemaForeignKey->getName() === $foreignKey) {
                    return true;
                }
            }
        } catch (\Throwable $exception) {
            return false;
        }

        return false;
    }
};