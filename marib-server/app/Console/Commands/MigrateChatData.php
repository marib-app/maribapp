<?php

namespace App\Console\Commands;

use App\Models\Chat;
use App\Models\ChatMessage;
use App\Models\ItemOffer;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class MigrateChatData extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'chat:migrate-old-data {--chunk=500 : Number of legacy chat rows to process per chunk}';

    /**
     * The console command description.
     */
    protected $description = 'Migrate legacy chat records into the chat_conversations and chat_messages tables';

    public function handle(): int
    {
        if (!Schema::hasTable('chats')) {
            $this->warn('Legacy chats table does not exist. Nothing to migrate.');
            return Command::SUCCESS;
        }

        if (!Schema::hasTable('chat_conversations') || !Schema::hasTable('chat_messages')) {
            $this->error('New chat tables are missing. Please run the migrations first.');
            return Command::FAILURE;
        }

        $total = DB::table('chats')->count();

        if ($total === 0) {
            $this->info('No legacy chat records found.');
            return Command::SUCCESS;
        }

        $chunkSize = (int) $this->option('chunk');
        if ($chunkSize <= 0) {
            $chunkSize = 500;
        }

        $this->info("Migrating {$total} legacy chat records in chunks of {$chunkSize}...");
        $this->output->progressStart($total);

        $processed = 0;

        DB::table('chats')
            ->orderBy('id')
            ->chunkById($chunkSize, function ($rows) use (&$processed) {
                $itemOfferIds = collect($rows)->pluck('item_offer_id')->filter()->unique();
                $itemOffers = ItemOffer::whereIn('id', $itemOfferIds)->get()->keyBy('id');

                DB::transaction(function () use ($rows, &$processed, $itemOffers) {
                    foreach ($rows as $row) {
                        $rowCreatedAt = $row->created_at ? Carbon::parse($row->created_at) : now();
                        $rowUpdatedAt = $row->updated_at ? Carbon::parse($row->updated_at) : $rowCreatedAt;

                        $conversation = Chat::firstOrCreate(
                            ['item_offer_id' => $row->item_offer_id],
                            ['created_at' => $rowCreatedAt, 'updated_at' => $rowUpdatedAt]
                        );

                        $participants = collect([
                            $row->sender_id,
                            optional($itemOffers->get($row->item_offer_id))->seller_id,
                            optional($itemOffers->get($row->item_offer_id))->buyer_id,
                        ])->filter()->unique()->values()->all();

                        if (!empty($participants)) {
                            $conversation->participants()->syncWithoutDetaching($participants);
                        }

                        $messageContent = $row->message;
                        if ($messageContent === '') {
                            $messageContent = null;
                        }

                        $filePath = $row->file ?: null;
                        $audioPath = $row->audio ?: null;

                        ChatMessage::updateOrCreate(
                            [
                                'conversation_id' => $conversation->id,
                                'sender_id' => $row->sender_id,
                                'message' => $messageContent,
                                'file' => $filePath,
                                'audio' => $audioPath,
                                'created_at' => $rowCreatedAt,
                            ],
                            [
                                'updated_at' => $rowUpdatedAt,
                            ]
                        );

                        $createdAt = $conversation->created_at ?? $rowCreatedAt;
                        $updatedAt = $conversation->updated_at ?? $rowUpdatedAt;

                        if ($rowCreatedAt->lt($createdAt)) {
                            $createdAt = $rowCreatedAt;
                        }

                        if ($rowUpdatedAt->gt($updatedAt)) {
                            $updatedAt = $rowUpdatedAt;
                        }

                        DB::table('chat_conversations')
                            ->where('id', $conversation->id)
                            ->update([
                                'created_at' => $createdAt,
                                'updated_at' => $updatedAt,
                            ]);

                        $conversation->created_at = $createdAt;
                        $conversation->updated_at = $updatedAt;

                        $processed++;
                        $this->output->progressAdvance();
                    }
                });
            });

        $this->output->progressFinish();

        $this->info("Migration completed. Migrated {$processed} messages.");

        return Command::SUCCESS;
    }
}