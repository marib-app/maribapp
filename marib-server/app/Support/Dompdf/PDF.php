<?php

namespace Barryvdh\DomPDF;

use Illuminate\Http\Response;
use Illuminate\Support\Str;

class PDF
{
    private array $options = [];

    private string $html = '';

    private string $paper = 'a4';

    private string $orientation = 'portrait';

    public function setOptions(array $options): self
    {
        $this->options = array_merge($this->options, $options);

        return $this;
    }

    public function loadHTML(string $html): self
    {
        $this->html = $html;

        return $this;
    }

    public function setPaper(string $paper, string $orientation = 'portrait'): self
    {
        $paper = Str::lower($paper);
        $orientation = Str::lower($orientation);

        $this->paper = in_array($paper, array_keys($this->paperDimensions()), true) ? $paper : 'a4';
        $this->orientation = $orientation === 'landscape' ? 'landscape' : 'portrait';

        return $this;
    }

    public function output(): string
    {
        [$width, $height] = $this->resolveDimensions();
        $pages = $this->paginate($this->convertHtmlToLines($this->html), $height);

        return $this->buildPdf($pages, $width, $height);
    }

    public function download(string $filename = 'document.pdf'): Response
    {
        return $this->makeResponse($filename, 'attachment');
    }

    public function stream(string $filename = 'document.pdf'): Response
    {
        return $this->makeResponse($filename, 'inline');
    }

    private function makeResponse(string $filename, string $disposition): Response
    {
        $filename = trim($filename) !== '' ? $filename : 'document.pdf';

        return response($this->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => sprintf('%s; filename="%s"', $disposition, $filename),
        ]);
    }

    private function resolveDimensions(): array
    {
        $dimensions = $this->paperDimensions()[$this->paper] ?? $this->paperDimensions()['a4'];

        if ($this->orientation === 'landscape') {
            return [$dimensions[1], $dimensions[0]];
        }

        return $dimensions;
    }

    private function paperDimensions(): array
    {
        return [
            'a4' => [595.28, 841.89],
            'letter' => [612.0, 792.0],
        ];
    }

    private function convertHtmlToLines(string $html): array
    {
        if (trim($html) === '') {
            return [''];
        }

        $search = [
            '/<\s*br\s*\/?\s*>/i',
            '/<\s*\/p\s*>/i',
            '/<\s*\/div\s*>/i',
            '/<\s*\/h[1-6]\s*>/i',
            '/<\s*li\s*>/i',
            '/<\s*\/li\s*>/i',
            '/<\s*\/tr\s*>/i',
            '/<\s*\/td\s*>/i',
            '/<\s*th\s*>/i',
            '/<\s*\/th\s*>/i',
            '/<\s*\/span\s*>/i',
        ];

        $replace = [
            "\n",
            "\n\n",
            "\n",
            "\n\n",
            '- ',
            "\n",
            "\n",
            "\t",
            '',
            "\t",
            ' ',
        ];

        $text = preg_replace($search, $replace, $html) ?? $html;
        $text = strip_tags($text);
        $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = preg_replace("/\r\n|\r/", "\n", $text) ?? $text;
        $text = str_replace("\t", '    ', $text);
        $text = preg_replace("/\s+\n/", "\n", $text) ?? $text;
        $text = preg_replace("/\n{3,}/", "\n\n", $text) ?? $text;

        $lines = [];

        foreach (explode("\n", $text) as $line) {
            $trimmed = trim($line);

            if ($trimmed === '') {
                $lines[] = '';
                continue;
            }

            foreach ($this->wrapLine($trimmed) as $wrapLine) {
                $lines[] = trim($wrapLine);
            }
        }

        return $lines === [] ? [''] : $lines;
    }

    private function paginate(array $lines, float $pageHeight): array
    {
        $lineHeight = $this->lineHeight();
        $topMargin = $this->margin('top', 40.0);
        $bottomMargin = $this->margin('bottom', 40.0);
        $usableHeight = max(1.0, $pageHeight - $topMargin - $bottomMargin);
        $linesPerPage = max(1, (int) floor($usableHeight / $lineHeight));

        $pages = [];
        $current = [];
        $count = 0;

        foreach ($lines as $line) {
            if ($count >= $linesPerPage) {
                $pages[] = $current;
                $current = [];
                $count = 0;
            }

            $current[] = $line;
            $count++;
        }

        if ($current !== []) {
            $pages[] = $current;
        }

        return $pages === [] ? [['']] : $pages;
    }

    private function wrapLine(string $line, int $maxWidth = 90): array
    {
        $segments = preg_split('/(\s+)/u', $line, -1, PREG_SPLIT_DELIM_CAPTURE | PREG_SPLIT_NO_EMPTY);

        if ($segments === false) {
            return [$line];
        }

        $wrapped = [];
        $current = '';
        $currentWidth = 0;

        foreach ($segments as $segment) {
            $segmentWidth = max(1, $this->stringWidth($segment));

            if ($current !== '' && $currentWidth + $segmentWidth > $maxWidth) {
                $wrapped[] = rtrim($current);
                $current = ltrim($segment);
                $currentWidth = $this->stringWidth($current);
                continue;
            }

            $current .= $segment;
            $currentWidth += $segmentWidth;
        }

        if ($current !== '') {
            $wrapped[] = rtrim($current);
        }

        return $wrapped === [] ? [''] : $wrapped;
    }

    private function stringWidth(string $value): int
    {
        if (function_exists('mb_strwidth')) {
            return mb_strwidth($value, 'UTF-8');
        }

        return strlen($value);
    }

    private function buildPdf(array $pages, float $width, float $height): string
    {
        $objects = [];
        $objectId = 1;

        $catalogId = $objectId++;
        $pagesId = $objectId++;
        $fontId = $objectId++;

        $objects[$fontId] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

        $kids = [];

        foreach ($pages as $pageLines) {
            $contentId = $objectId++;
            $stream = $this->buildStream($pageLines, $height);
            $objects[$contentId] = [
                'type' => 'stream',
                'dictionary' => sprintf('<< /Length %d >>', strlen($stream)),
                'data' => $stream,
            ];

            $pageId = $objectId++;
            $objects[$pageId] = sprintf(
                '<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %.2f %.2f] /Contents %d 0 R /Resources << /Font << /F1 %d 0 R >> >> >>',
                $pagesId,
                $width,
                $height,
                $contentId,
                $fontId
            );

            $kids[] = $pageId;
        }

        $kidsRefs = implode(' ', array_map(static fn (int $id) => sprintf('%d 0 R', $id), $kids));
        $objects[$pagesId] = sprintf('<< /Type /Pages /Kids [%s] /Count %d >>', $kidsRefs, count($kids));
        $objects[$catalogId] = sprintf('<< /Type /Catalog /Pages %d 0 R >>', $pagesId);

        $pdf = "%PDF-1.4\n";
        $offsets = [];

        $maxObjectId = $objectId - 1;

        for ($id = 1; $id <= $maxObjectId; $id++) {
            $offsets[$id] = strlen($pdf);
            $object = $objects[$id] ?? 'null';

            if (is_array($object) && ($object['type'] ?? null) === 'stream') {
                $pdf .= sprintf(
                    "%d 0 obj\n%s\nstream\n%s\nendstream\nendobj\n",
                    $id,
                    $object['dictionary'],
                    $object['data']
                );

                continue;
            }

            $pdf .= sprintf("%d 0 obj\n%s\nendobj\n", $id, $object);
        }

        $xrefOffset = strlen($pdf);
        $pdf .= sprintf("xref\n0 %d\n", $maxObjectId + 1);
        $pdf .= "0000000000 65535 f \n";

        for ($id = 1; $id <= $maxObjectId; $id++) {
            $pdf .= sprintf("%010d 00000 n \n", $offsets[$id]);
        }

        $pdf .= sprintf(
            "trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%EOF",
            $maxObjectId + 1,
            $catalogId,
            $xrefOffset
        );

        return $pdf;
    }

    private function buildStream(array $lines, float $height): string
    {
        $lineHeight = $this->lineHeight();
        $topMargin = $this->margin('top', 40.0);
        $leftMargin = $this->margin('left', 50.0);
        $fontSize = max(6.0, (float) $this->option('font_size', 12.0));

        $currentY = $height - $topMargin;
        $stream = sprintf("BT\n/F1 %.2f Tf\n", $fontSize);

        foreach ($lines as $line) {
            $escaped = $this->escapeText($line);
            $stream .= sprintf("1 0 0 1 %.2f %.2f Tm (%s) Tj\n", $leftMargin, $currentY, $escaped);
            $currentY -= $lineHeight;
        }

        $stream .= "ET";

        return $stream;
    }

    private function lineHeight(): float
    {
        $specified = (float) $this->option('line_height', 14.0);
        $fontSize = (float) $this->option('font_size', 12.0);

        return max(8.0, $specified, $fontSize + 2.0);
    }

    private function margin(string $position, float $default): float
    {
        return max(0.0, (float) $this->option('margin_' . $position, $default));
    }

    private function escapeText(string $text): string
    {
        $text = str_replace(['\\', '(', ')'], ['\\\\', '\\(', '\\)'], $text);

        return preg_replace("/[\x00-\x08\x0B\x0C\x0E-\x1F]/", '', $text) ?? $text;
    }

    private function option(string $key, mixed $default = null): mixed
    {
        $candidates = [$key, Str::camel($key), Str::snake($key)];

        foreach ($candidates as $candidate) {
            if (array_key_exists($candidate, $this->options)) {
                return $this->options[$candidate];
            }
        }

        return $default;
    }
}