<?php

declare(strict_types=1);

namespace App;

use PDO;

/**
 * Thin data access layer: just enough to prove reads AND writes work
 * end to end (Cloud Run -> connector -> Cloud SQL).
 */
final class Database
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public static function connect(Config $config): self
    {
        $pdo = new PDO($config->dsn(), $config->dbUser, $config->dbPass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_TIMEOUT => 5, // fail fast so health checks don't hang
        ]);

        return new self($pdo);
    }

    /** Idempotent: safe to call on every cold start. */
    public function ensureSchema(): void
    {
        $this->pdo->exec(
            'CREATE TABLE IF NOT EXISTS visits (
                id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
                count BIGINT UNSIGNED NOT NULL DEFAULT 0
            ) ENGINE=InnoDB'
        );
        $this->pdo->exec('INSERT IGNORE INTO visits (id, count) VALUES (1, 0)');
    }

    /** Atomically increments the counter and returns the new value. */
    public function incrementVisits(): int
    {
        $this->pdo->exec('UPDATE visits SET count = count + 1 WHERE id = 1');

        return (int) $this->pdo->query('SELECT count FROM visits WHERE id = 1')->fetchColumn();
    }

    public function serverVersion(): string
    {
        return (string) $this->pdo->query('SELECT VERSION()')->fetchColumn();
    }

    public function ping(): bool
    {
        return $this->pdo->query('SELECT 1')->fetchColumn() == 1;
    }
}
