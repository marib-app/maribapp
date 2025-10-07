<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class MediaController extends Controller
{
    public function show(Request $request, string $path): BinaryFileResponse
    {
        $diskName = config('filesystems.default', 'public');
        $disk = Storage::disk($diskName);

        $normalizedPath = ltrim(str_replace('\\', '/', $path), '/');

        if ($normalizedPath === '' || preg_match('/(^|\/)\.\.(\/|$)/', $normalizedPath)) {
            abort(404);
        }

        if (! $disk->exists($normalizedPath)) {
            abort(404);
        }

        $absolutePath = $disk->path($normalizedPath);

        $headers = [];
        $mimeType = $disk->mimeType($normalizedPath);

        if (is_string($mimeType) && $mimeType !== '') {
            $headers['Content-Type'] = $mimeType;
        }

        $size = $disk->size($normalizedPath);

        if (is_int($size) && $size >= 0) {
            $headers['Content-Length'] = (string) $size;
        }

        $response = response()->file($absolutePath, $headers);

        $lastModified = $disk->lastModified($normalizedPath);

        if (is_int($lastModified)) {
            $response->setLastModified(Carbon::createFromTimestampUTC($lastModified));
        }

        $ifModifiedSince = $request->headers->get('If-Modified-Since');

        if ($ifModifiedSince !== null && is_int($lastModified)) {
            $ifModifiedSinceTime = strtotime($ifModifiedSince);

            if ($ifModifiedSinceTime !== false && $lastModified <= $ifModifiedSinceTime) {
                $response->setNotModified();
            }
        }

        return $response;
    }
}