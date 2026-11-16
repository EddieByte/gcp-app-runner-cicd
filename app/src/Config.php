<?php

declare(strict_types=1);

namespace App;

use InvalidArgumentException;

/**
 * Application configuration, read from environment variables.
 *
 * On Cloud Run the variables come from the service definition (Terraform/CI)
 * and DB_PASS from Secret Manager. Locally they come from docker-compose.
 *
 * Two ways to reach MySQL:
 *  - INSTANCE_CONNECTION_NAME set -> unix socket /cloudsql/<name> (Cloud Run's
 *    built-in Cloud SQL connector; IAM-authenticated and encrypted)
 *  - otherwise DB_HOST/DB_PORT -> plain TCP (local dev, CI service container)
 *
 * @see https://cloud.google.com/sql/docs/mysql/connect-run
 */
final class Config
{
    public function __construct(
        public readonly string $appName,
        public readonly string $environment,
        public readonly string $revision,
        public readonly string $dbName,
        public readonly string $dbUser,
        public readonly string $dbPass,
        public readonly ?string $dbSocket,
        public readonly ?string $dbHost,
        public readonly int $dbPort,
    ) {
    }

    /**
     * @param array<string, string|false> $env usually getenv()
     */
    public static function fromEnv(array $env): self
    {
        $get = static fn (string $key, ?string $default = null): ?string =>
            isset($env[$key]) && $env[$key] !== '' && $env[$key] !== false ? (string) $env[$key] : $default;

        $missing = array_values(array_filter(
            ['DB_NAME', 'DB_USER', 'DB_PASS'],
            static fn (string $key): bool => $get($key) === null,
        ));

        $connection = $get('INSTANCE_CONNECTION_NAME');
        $host = $get('DB_HOST');

        if ($connection === null && $host === null) {
            $missing[] = 'INSTANCE_CONNECTION_NAME or DB_HOST';
        }

        if ($missing !== []) {
            throw new InvalidArgumentException('Missing required environment variables: ' . implode(', ', $missing));
        }

        $port = (int) $get('DB_PORT', '3306');
        if ($port < 1 || $port > 65535) {
            throw new InvalidArgumentException("DB_PORT must be between 1 and 65535, got {$port}");
        }

        return new self(
            appName: $get('APP_NAME', 'php-app'),
            environment: $get('APP_ENV', 'local'),
            // K_REVISION is set automatically by Cloud Run on every revision.
            revision: $get('K_REVISION', 'local'),
            dbName: (string) $get('DB_NAME'),
            dbUser: (string) $get('DB_USER'),
            dbPass: (string) $get('DB_PASS'),
            dbSocket: $connection !== null ? '/cloudsql/' . $connection : null,
            dbHost: $host,
            dbPort: $port,
        );
    }

    /** PDO DSN: socket when running on Cloud Run, TCP otherwise. */
    public function dsn(): string
    {
        if ($this->dbSocket !== null) {
            return sprintf('mysql:unix_socket=%s;dbname=%s;charset=utf8mb4', $this->dbSocket, $this->dbName);
        }

        return sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $this->dbHost, $this->dbPort, $this->dbName);
    }

    /** How we connect, for display; never includes credentials. */
    public function connectionLabel(): string
    {
        return $this->dbSocket !== null
            ? 'Cloud SQL connector (unix socket)'
            : sprintf('TCP %s:%d', $this->dbHost, $this->dbPort);
    }
}
