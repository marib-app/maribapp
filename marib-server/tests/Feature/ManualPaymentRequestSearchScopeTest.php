<?php

namespace Tests\Unit;

use App\Models\ManualPaymentRequest;
use Tests\TestCase;

class ManualPaymentRequestSearchScopeTest extends TestCase
{
    public function test_empty_search_term_does_not_modify_query(): void
    {
        $baseSql = ManualPaymentRequest::query()->toSql();

        $this->assertSame(
            $baseSql,
            ManualPaymentRequest::query()->search(null)->toSql(),
            'Empty search should not add conditions.'
        );

        $this->assertSame(
            $baseSql,
            ManualPaymentRequest::query()->search('   ')->toSql(),
            'Whitespace-only search should not add conditions.'
        );

        $termSql = ManualPaymentRequest::query()->search('invoice')->toSql();

        $this->assertNotSame($baseSql, $termSql, 'Populated search should modify the query.');
        $this->assertStringContainsString('like', strtolower($termSql));
    }
}