<?php

declare(strict_types=1);

namespace App\Tests\Integration;

use App\Config;
use App\Database;
use PHPUnit\Framework\TestCase;

/**
 * Runs against a real MySQL. In CI, GitHub Actions starts mysql:8.0 as a
 * service container and sets DB_HOST/DB_* env vars. Skipped when absent.
 */
final class DatabaseTest extends TestCase
{
    private Database $db;

    protected function setUp(): void
    {
        if (getenv('DB_HOST') === false) {
            self::markTestSkipped('DB_HOST not set; integration tests need a MySQL instance.');
        }

        $this->db = Database::connect(Config::fromEnv(getenv()));
        $this->db->ensureSchema();
    }

    public function testPing(): void
    {
        self::assertTrue($this->db->ping());
    }

    public function testServerIsMysql8(): void
    {
        self::assertStringStartsWith('8.', $this->db->serverVersion());
    }

    public function testEnsureSchemaIsIdempotent(): void
    {
        $this->db->ensureSchema();
        $this->db->ensureSchema();

        self::assertTrue($this->db->ping());
    }

    public function testIncrementVisitsIncreasesByOne(): void
    {
        $first = $this->db->incrementVisits();
        $second = $this->db->incrementVisits();

        self::assertSame($first + 1, $second);
    }
}
