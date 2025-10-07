<?php

namespace App\Exceptions;

use Symfony\Component\HttpFoundation\Response;

class ResponseServiceTestException extends \RuntimeException
{
    public function __construct(private readonly Response $response)
    {
        parent::__construct('ResponseService intercepted response for testing.');
    }

    public function getResponse(): Response
    {
        return $this->response;
    }
}