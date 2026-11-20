<?php
/**
 * SARVOOCCH Microcare Foundation - Self-Diagnostic & Setup Utility
 * Access: https://sarvocchfinance.com/portal/setup.php
 */

define('SARVOOCCH_APP', true);
require_once __DIR__ . '/app/config.php';

$message = '';
$msgType = 'info';

// Handle MySQL credentials save
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_db'])) {
    $dbHost = trim($_POST['db_host'] ?? 'localhost');
    $dbName = trim($_POST['db_name'] ?? 'u170129876_q1gD8');
    $dbUser = trim($_POST['db_user'] ?? '');
    $dbPass = trim($_POST['db_pass'] ?? '');

    // Write to .env
    $envContent = "# SARVOOCCH Production Environment\n" .
                  "DB_HOST=" . $dbHost . "\n" .
                  "DB_PORT=3306\n" .
                  "DB_NAME=" . $dbName . "\n" .
                  "DB_USER=" . $dbUser . "\n" .
                  "DB_PASS=" . $dbPass . "\n" .
                  "APP_DEBUG=0\n" .
                  "DISABLE_DEMO_LOGINS=1\n" .
                  "SECRET_KEY=sarvoocch_prod_secure_token_key_2026_9111199101\n";

    if (@file_put_contents(__DIR__ . '/.env', $envContent)) {
        $message = "Database configuration saved to .env successfully! Testing connection...";
        $msgType = "success";
        putenv("DB_HOST=$dbHost");
        putenv("DB_NAME=$dbName");
        putenv("DB_USER=$dbUser");
        putenv("DB_PASS=$dbPass");
        $_ENV['DB_HOST'] = $dbHost;
        $_ENV['DB_NAME'] = $dbName;
        $_ENV['DB_USER'] = $dbUser;
        $_ENV['DB_PASS'] = $dbPass;
    } else {
        $message = "Warning: Could not write to .env (permission denied). Please update app/config.php directly.";
        $msgType = "danger";
    }
}

// 1. Diagnostics Checks
$phpVersion = PHP_VERSION;
$pdoMysql = extension_loaded('pdo_mysql');
$pdoSqlite = extension_loaded('pdo_sqlite');
$sqlitePath = STORAGE_PATH . '/sarvocch.db';
$sqliteExists = file_exists($sqlitePath);

// Test MySQL
$mysqlOk = false;
$mysqlErr = '';
$mysqlTables = 0;
try {
    $currHost = getenv('DB_HOST') ?: (defined('DB_HOST') ? DB_HOST : 'localhost');
    $currName = getenv('DB_NAME') ?: (defined('DB_NAME') ? DB_NAME : 'u170129876_q1gD8');
    $currUser = getenv('DB_USER') ?: (defined('DB_USER') ? DB_USER : 'u170129876_q1gD8');
    $currPass = getenv('DB_PASS') ?: (defined('DB_PASS') ? DB_PASS : '');

    $dsn = "mysql:host={$currHost};dbname={$currName};charset=utf8mb4";
    $testPdo = new PDO($dsn, $currUser, $currPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 3
    ]);
    $mysqlOk = true;
    $stmt = $testPdo->query("SHOW TABLES");
    $mysqlTables = count($stmt->fetchAll());
} catch (Exception $e) {
    $mysqlErr = $e->getMessage();
}

// Test SQLite
$sqliteOk = false;
$sqliteTables = 0;
if ($sqliteExists && $pdoSqlite) {
    try {
        $sqPdo = new PDO('sqlite:' . $sqlitePath, null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
        $stmt = $sqPdo->query("SELECT COUNT(*) FROM sqlite_master WHERE type='table'");
        $sqliteTables = (int)$stmt->fetchColumn();
        $sqliteOk = ($sqliteTables > 0);
    } catch (Exception $e) {
        $sqliteOk = false;
    }
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SARVOOCCH Portal Diagnostics & Setup</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<style>
  body { background: #0f172a; min-height: 100vh; font-family: system-ui, -apple-system, sans-serif; padding: 40px 15px; color: #1e293b; }
  .setup-container { max-width: 800px; margin: 0 auto; background: #fff; border-radius: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.3); overflow: hidden; }
  .header-banner { background: linear-gradient(135deg, #0f766e 0%, #042f2e 100%); color: #fff; padding: 2rem; }
  .status-badge { font-size: 0.85rem; padding: 0.35rem 0.65rem; border-radius: 6px; }
</style>
</head>
<body>
<div class="setup-container">
  <div class="header-banner text-center">
    <i class="bi bi-bank2 fs-1 mb-2 d-block text-white"></i>
    <h3 class="fw-bold mb-1">SARVOOCCH Microcare Foundation</h3>
    <p class="mb-0 text-white-50 small">Production Deployment Diagnostics · Hostinger LiteSpeed + PHP 8.3</p>
  </div>

  <div class="p-4 p-md-5">
    <?php if ($message): ?>
      <div class="alert alert-<?= $msgType ?> alert-dismissible fade show" role="alert">
        <?= htmlspecialchars($message) ?>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
    <?php endif; ?>

    <h5 class="fw-bold mb-3"><i class="bi bi-speedometer me-2 text-teal"></i>System Readiness</h5>
    <ul class="list-group mb-4">
      <li class="list-group-item d-flex justify-content-between align-items-center">
        <div><strong>PHP Runtime</strong> <span class="text-muted small ms-2">v<?= $phpVersion ?></span></div>
        <span class="badge bg-success status-badge"><i class="bi bi-check-circle me-1"></i>Active</span>
      </li>
      <li class="list-group-item d-flex justify-content-between align-items-center">
        <div><strong>Embedded SQLite Fallback</strong> <span class="text-muted small ms-2"><?= $sqliteOk ? "Ready ({$sqliteTables} tables)" : "Missing" ?></span></div>
        <span class="badge bg-<?= $sqliteOk ? 'success' : 'warning text-dark' ?> status-badge">
          <?= $sqliteOk ? '<i class="bi bi-check-circle me-1"></i>Operational' : 'Not Loaded' ?>
        </span>
      </li>
      <li class="list-group-item d-flex justify-content-between align-items-center">
        <div>
          <strong>Hostinger MySQL Database</strong> 
          <span class="text-muted small ms-2"><?= $mysqlOk ? "Connected ({$mysqlTables} tables in `{$currName}`)" : "Not Connected" ?></span>
        </div>
        <span class="badge bg-<?= $mysqlOk ? 'success' : 'danger' ?> status-badge">
          <?= $mysqlOk ? '<i class="bi bi-check-circle me-1"></i>Connected' : '<i class="bi bi-x-circle me-1"></i>Action Required' ?>
        </span>
      </li>
    </ul>

    <?php if (!$mysqlOk): ?>
      <div class="card border-warning mb-4">
        <div class="card-header bg-warning bg-opacity-10 fw-semibold text-warning-emphasis">
          <i class="bi bi-exclamation-triangle-fill me-2"></i>MySQL Connection Notice
        </div>
        <div class="card-body">
          <p class="small text-danger font-monospace mb-3"><?= htmlspecialchars($mysqlErr) ?></p>
          <p class="small text-muted mb-3">
            Enter your Hostinger MySQL password below to automatically link your database:
          </p>
          <form method="post" action="">
            <input type="hidden" name="save_db" value="1">
            <div class="row g-2 mb-2">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Database Host</label>
                <input type="text" name="db_host" class="form-control form-control-sm" value="<?= htmlspecialchars($currHost) ?>" required>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Database Name</label>
                <input type="text" name="db_name" class="form-control form-control-sm" value="<?= htmlspecialchars($currName) ?>" required>
              </div>
            </div>
            <div class="row g-2 mb-3">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Database Username</label>
                <input type="text" name="db_user" class="form-control form-control-sm" value="<?= htmlspecialchars($currUser) ?>" placeholder="u170129876_..." required>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Database Password</label>
                <input type="password" name="db_pass" class="form-control form-control-sm" placeholder="Your MySQL Password" required>
              </div>
            </div>
            <button type="submit" class="btn btn-primary btn-sm px-4 fw-semibold">
              <i class="bi bi-save me-1"></i>Save & Test Connection
            </button>
          </form>
        </div>
      </div>
    <?php endif; ?>

    <div class="text-center pt-3 border-top d-flex justify-content-center gap-3">
      <a href="<?= url('/login') ?>" class="btn btn-success px-4 fw-semibold py-2">
        <i class="bi bi-box-arrow-in-right me-2"></i>Open SARVOOCCH Login Portal
      </a>
      <a href="https://sarvocchfinance.com" class="btn btn-outline-secondary px-4 py-2">
        Main Website
      </a>
    </div>
  </div>
</div>
</body>
</html>
