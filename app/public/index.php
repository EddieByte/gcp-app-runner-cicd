<?php

/**
 * Front controller. Nginx sends every non-static request here.
 *
 * Routes:
 *   GET /         status page (env, revision, DB version, visit counter)
 *   GET /healthz  liveness  - used by Cloud Run's startup/liveness probe
 *   GET /readyz   readiness - checks the database
 */

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Config;
use App\Database;
use App\Health;

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

function json_response(int $status, array $body): never
{
    http_response_code($status);
    header('Content-Type: application/json');
    header('Cache-Control: no-store');
    echo json_encode($body, JSON_THROW_ON_ERROR);
    exit;
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
}

if ($path === '/healthz') {
    json_response(...Health::liveness());
}

try {
    $config = Config::fromEnv(getenv());
} catch (InvalidArgumentException $ex) {
    // Misconfiguration is logged in full (Cloud Logging) but not shown to users.
    error_log('[config] ' . $ex->getMessage());
    $path === '/readyz'
        ? json_response(503, ['status' => 'degraded', 'config' => 'invalid'])
        : json_response(500, ['error' => 'Application is misconfigured']);
}

if ($path === '/readyz') {
    json_response(...Health::readiness(static fn (): bool => Database::connect($config)->ping()));
}

if ($path !== '/') {
    json_response(404, ['error' => 'Not found']);
}

// Status page. DB errors are shown as a status, never as raw exception text.
$db = ['ok' => false, 'version' => null, 'visits' => null];
try {
    $database = Database::connect($config);
    $database->ensureSchema();
    $db = ['ok' => true, 'version' => $database->serverVersion(), 'visits' => $database->incrementVisits()];
} catch (Throwable $ex) {
    error_log('[db] ' . $ex->getMessage());
}

header('Cache-Control: no-store');
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($config->appName) ?> &middot; <?= e($config->environment) ?></title>
    <!-- Served by the GCS backend bucket via the load balancer (/static/*) -->
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
<main>
    <header>
        <img src="/static/logo.svg" alt="" width="48" height="48">
        <h1><?= e($config->appName) ?></h1>
        <span class="badge"><?= e($config->environment) ?></span>
    </header>

    <table>
        <tr><th>Cloud Run revision</th><td><?= e($config->revision) ?></td></tr>
        <tr><th>PHP</th><td><?= e(PHP_VERSION) ?> (FPM behind Nginx)</td></tr>
        <tr><th>Database connection</th><td><?= e($config->connectionLabel()) ?></td></tr>
        <tr>
            <th>Database status</th>
            <td class="<?= $db['ok'] ? 'ok' : 'fail' ?>">
                <?= $db['ok'] ? 'Connected &middot; MySQL ' . e($db['version']) : 'Unreachable (see logs)' ?>
            </td>
        </tr>
        <tr><th>Visits (stored in Cloud SQL)</th><td><?= $db['ok'] ? e((string) $db['visits']) : '&ndash;' ?></td></tr>
    </table>

    <p class="note">Static assets on this page are served from Cloud Storage, not the container.</p>
</main>
</body>
</html>
