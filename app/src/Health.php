<?php

declare(strict_types=1);

namespace App;

use Throwable;

/**
 * Liveness vs readiness, the same split Kubernetes uses:
 *  - liveness  (/healthz): is the process up? Never touches the DB, so a DB
 *    outage doesn't make Cloud Run restart healthy containers.
 *  - readiness (/readyz):  can we serve real traffic? Checks the DB.
 */
final class Health
{
    /** @return array{0:int, 1:array<string,string>} [HTTP status, body] */
    public static function liveness(): array
    {
        return [200, ['status' => 'ok']];
    }

    /**
     * @param callable():bool $dbCheck
     * @return array{0:int, 1:array<string,string>}
     */
    public static function readiness(callable $dbCheck): array
    {
        try {
            $ok = $dbCheck();
        } catch (Throwable) {
            $ok = false;
        }

        return $ok
            ? [200, ['status' => 'ok', 'db' => 'ok']]
            : [503, ['status' => 'degraded', 'db' => 'unreachable']];
    }
}
