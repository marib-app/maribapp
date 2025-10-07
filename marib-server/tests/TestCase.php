<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication;



    protected function setUp(): void
    {
        $_ENV['APP_KEY'] = $_ENV['APP_KEY'] ?? 'base64:YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE=';
        $_SERVER['APP_KEY'] = $_SERVER['APP_KEY'] ?? $_ENV['APP_KEY'];

        $_ENV['DB_CONNECTION'] = 'sqlite';
        $_SERVER['DB_CONNECTION'] = 'sqlite';

        $_ENV['DB_DATABASE'] = ':memory:';
        $_SERVER['DB_DATABASE'] = ':memory:';

        parent::setUp();
    }


}
