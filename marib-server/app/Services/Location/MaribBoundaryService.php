<?php

namespace App\Services\Location;

use Illuminate\Support\Arr;

class MaribBoundaryService
{
    /**
     * @return array<int, array{lat: float, lng: float}>
     */
    public function getPolygon(): array
    {
        $rawPolygon = config('marib.boundary.polygon', []);

        $normalized = [];

        foreach ($rawPolygon as $point) {
            $lat = Arr::get($point, 'lat');
            $lng = Arr::get($point, 'lng');

            if (!is_numeric($lat) || !is_numeric($lng)) {
                continue;
            }

            $normalized[] = [
                'lat' => (float) $lat,
                'lng' => (float) $lng,
            ];
        }

        return $normalized;
    }

    public function contains(float $lat, float $lng): bool
    {
        $polygon = $this->getPolygon();

        if (count($polygon) < 3) {
            return false;
        }

        return $this->pointInPolygon($lat, $lng, $polygon);
    }

    /**
     * @param array<int, array{lat: float, lng: float}> $polygon
     */
    private function pointInPolygon(float $lat, float $lng, array $polygon): bool
    {
        $inside = false;
        $pointsCount = count($polygon);

        for ($i = 0, $j = $pointsCount - 1; $i < $pointsCount; $j = $i++) {
            $xi = $polygon[$i]['lng'];
            $yi = $polygon[$i]['lat'];
            $xj = $polygon[$j]['lng'];
            $yj = $polygon[$j]['lat'];

            $denominator = $yj - $yi;

            if (abs($denominator) < 1e-12) {
                $denominator = $denominator < 0 ? -1e-12 : 1e-12;
            }

            $intersect = (($yi > $lat) !== ($yj > $lat))
                && ($lng < (($xj - $xi) * ($lat - $yi) / $denominator) + $xi);

            if ($intersect) {
                $inside = !$inside;
            }
        }

        return $inside;
    }
}