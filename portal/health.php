<?php
/**
 * SARVOOCCH Microcare Foundation - Production Health & Uptime Endpoint
 * Returns JSON status for UptimeRobot / Pingdom / Hostinger Server Health
 * URL: https://sarvocchfinance.com/portal/health.php
 */

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, no-store, must-revalidate');

define('SARVOOCCH_APP', true);

$startTime = microtime(true);
$response = [
    'status' => 'HEALTHY',
    'timestamp' => date('c'),
    'app' => 'SARVOOCCH Microcare Foundation Core Banking & Operations',
    'cin' => 'U88900MP2026NPL084139',
    'php_version' => PHP_VERSION,
    'checks' => [
        'php' => 'OK',
        'database' => 'UNKNOWN',
        'storage' => 'UNKNOWN'
    ]
];

// Check storage
$storagePath = __DIR__ . '/storage';
if (is_dir($storagePath) && is_writable($storagePath)) {
    $response['checks']['storage'] = 'OK';
} else {
    $response['checks']['storage'] = 'DEGRADED';
    $response['status'] = 'DEGRADED';
}

// Check database
try {
    require_once __DIR__ . '/app/config.php';
    require_once __DIR__ . '/app/db.php';

    $pdo = Database::getConnection();
    $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    $response['engine'] = $driver;

    $stmt = ($driver === 'mysql') ? $pdo->query("SHOW TABLES") : $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);

    $response['checks']['database'] = 'OK';
    $response['tables_count'] = count($tables);
} catch (Throwable $e) {
    $response['checks']['database'] = 'FAILED';
    $response['database_error'] = (defined('APP_DEBUG') && APP_DEBUG) ? $e->getMessage() : 'Database unreachable';
    $response['status'] = 'UNHEALTHY';
    http_response_code(503);
}

$response['response_time_ms'] = round((microtime(true) - $startTime) * 1000, 2);

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
exit;
