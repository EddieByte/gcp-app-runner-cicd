<?php

declare(strict_types=1);

namespace App\Tests\Unit;

use App\Config;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

final class ConfigTest extends TestCase
{
    private const BASE = ['DB_NAME' => 'app', 'DB_USER' => 'app', 'DB_PASS' => 's3cret'];

    public function testUsesCloudSqlSocketWhenConnectionNameIsSet(): void
    {
        $config = Config::fromEnv(self::BASE + ['INSTANCE_CONNECTION_NAME' => 'proj:europe-west1:db']);

        self::assertSame('/cloudsql/proj:europe-west1:db', $config->dbSocket);
        self::assertSame('mysql:unix_socket=/cloudsql/proj:europe-west1:db;dbname=app;charset=utf8mb4', $config->dsn());
        self::assertSame('Cloud SQL connector (unix socket)', $config->connectionLabel());
    }

    public function testSocketWinsOverHostWhenBothAreSet(): void
    {
        $config = Config::fromEnv(self::BASE + ['INSTANCE_CONNECTION_NAME' => 'p:r:i', 'DB_HOST' => 'db']);

        self::assertStringStartsWith('mysql:unix_socket=', $config->dsn());
    }

    public function testUsesTcpWhenOnlyHostIsSet(): void
    {
        $config = Config::fromEnv(self::BASE + ['DB_HOST' => 'db', 'DB_PORT' => '3307']);

        self::assertNull($config->dbSocket);
        self::assertSame('mysql:host=db;port=3307;dbname=app;charset=utf8mb4', $config->dsn());
    }

    public function testAppliesDefaults(): void
    {
        $config = Config::fromEnv(self::BASE + ['DB_HOST' => 'db']);

        self::assertSame('php-app', $config->appName);
        self::assertSame('local', $config->environment);
        self::assertSame('local', $config->revision);
        self::assertSame(3306, $config->dbPort);
    }

    public function testReadsCloudRunRevision(): void
    {
        $config = Config::fromEnv(self::BASE + ['DB_HOST' => 'db', 'K_REVISION' => 'php-app-00042-abc']);

        self::assertSame('php-app-00042-abc', $config->revision);
    }

    public function testListsEveryMissingVariable(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('DB_NAME, DB_USER, DB_PASS, INSTANCE_CONNECTION_NAME or DB_HOST');

        Config::fromEnv([]);
    }

    public function testTreatsEmptyStringsAsMissing(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('DB_PASS');

        Config::fromEnv(['DB_NAME' => 'app', 'DB_USER' => 'app', 'DB_PASS' => '', 'DB_HOST' => 'db']);
    }

    public function testRejectsInvalidPort(): void
    {
        $this->expectException(InvalidArgumentException::class);

        Config::fromEnv(self::BASE + ['DB_HOST' => 'db', 'DB_PORT' => '99999']);
    }

    public function testConnectionLabelNeverContainsThePassword(): void
    {
        $config = Config::fromEnv(self::BASE + ['DB_HOST' => 'db']);

        self::assertStringNotContainsString('s3cret', $config->connectionLabel());
        self::assertStringNotContainsString('s3cret', $config->dsn());
    }
}
