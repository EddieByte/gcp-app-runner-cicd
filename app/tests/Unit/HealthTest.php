<?php

declare(strict_types=1);

namespace App\Tests\Unit;

use App\Health;
use PHPUnit\Framework\TestCase;
use RuntimeException;

final class HealthTest extends TestCase
{
    public function testLivenessIsAlwaysOk(): void
    {
        self::assertSame([200, ['status' => 'ok']], Health::liveness());
    }

    public function testReadinessOkWhenDbCheckPasses(): void
    {
        self::assertSame([200, ['status' => 'ok', 'db' => 'ok']], Health::readiness(static fn (): bool => true));
    }

    public function testReadiness503WhenDbCheckFails(): void
    {
        [$status, $body] = Health::readiness(static fn (): bool => false);

        self::assertSame(503, $status);
        self::assertSame('unreachable', $body['db']);
    }

    public function testReadiness503WhenDbCheckThrows(): void
    {
        [$status] = Health::readiness(static function (): bool {
            throw new RuntimeException('connection refused');
        });

        self::assertSame(503, $status);
    }
}
