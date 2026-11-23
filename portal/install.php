<?php
/**
 * SARVOOCCH Microcare Foundation - Production Web Installer & Diagnostic Verifier
 * Designed for Hostinger LiteSpeed + PHP 8.3 + MySQL (u170129876_q1gD8)
 * URL: https://sarvocchfinance.com/portal/install.php
 */

define('SARVOOCCH_APP', true);
require_once __DIR__ . '/app/config.php';
require_once __DIR__ . '/app/db.php';
require_once __DIR__ . '/app/auth.php';

$lockFile = STORAGE_PATH . '/installed.lock';
$isLocked = file_exists($lockFile);

$phpOk = version_compare(PHP_VERSION, '8.1.0', '>=');
$pdoOk = extension_loaded('pdo');
$pdoMysqlOk = extension_loaded('pdo_mysql');
$jsonOk = extension_loaded('json');
$opensslOk = extension_loaded('openssl');
$mbstringOk = extension_loaded('mbstring');
$storageWritable = is_writable(STORAGE_PATH);
$uploadsWritable = is_writable(STORAGE_PATH . '/uploads');

$dbStatus = false;
$dbError = null;
$existingTables = [];
$driverName = 'unknown';

try {
    $pdo = Database::getConnection();
    $dbStatus = true;
    $driverName = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    if ($driverName === 'mysql') {
        $stmt = $pdo->query("SHOW TABLES");
        $existingTables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } else {
        $stmt = $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
        $existingTables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    }
} catch (Throwable $e) {
    $dbStatus = false;
    $dbError = $e->getMessage();
}

$executionResult = null;
$executionError = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !$isLocked) {
    $action = $_POST['action'] ?? '';
    if ($action === 'install') {
        try {
            $sqlFile = __DIR__ . '/database/setup_database.sql';
            if (!file_exists($sqlFile)) {
                throw new RuntimeException("SQL schema file not found at: {$sqlFile}");
            }
            $sql = file_get_contents($sqlFile);

            // Execute SQL statements
            $pdo = Database::getConnection();
            $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

            if ($driver === 'mysql') {
                $pdo->exec("SET FOREIGN_KEY_CHECKS = 0;");
            }

            // Split into distinct executable queries
            $queries = explode(";\n", str_replace("\r\n", "\n", $sql));
            $executedCount = 0;
            foreach ($queries as $q) {
                $trimmed = trim($q);
                if (!empty($trimmed) && !str_starts_with($trimmed, '--') && !str_starts_with($trimmed, '/*')) {
                    $pdo->exec($trimmed);
                    $executedCount++;
                }
            }

            if ($driver === 'mysql') {
                $pdo->exec("SET FOREIGN_KEY_CHECKS = 1;");
            }

            if (!empty($_POST['lock_after'])) {
                file_put_contents($lockFile, "Installed on " . date('Y-m-d H:i:s T') . "\n");
                $isLocked = true;
            }

            // Refresh table list
            if ($driver === 'mysql') {
                $stmt = $pdo->query("SHOW TABLES");
                $existingTables = $stmt->fetchAll(PDO::FETCH_COLUMN);
            } else {
                $stmt = $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
                $existingTables = $stmt->fetchAll(PDO::FETCH_COLUMN);
            }

            $executionResult = "Database successfully initialized! {$executedCount} SQL queries executed. Total active tables: " . count($existingTables);
        } catch (Throwable $ex) {
            $executionError = $ex->getMessage();
        }
    } elseif ($action === 'lock') {
        file_put_contents($lockFile, "Manually locked on " . date('Y-m-d H:i:s T') . "\n");
        $isLocked = true;
    }
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Production Installer & Verification · SARVOOCCH Portal</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<style>
  body { background: #0f172a; min-height: 100vh; display: flex; align-items: center; justify-content: center; font-family: system-ui, -apple-system, sans-serif; color: #334155; padding: 24px 12px; }
  .install-card { max-width: 720px; width: 100%; border-radius: 14px; background: #ffffff; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.4); overflow: hidden; }
  .card-header-bar { background: linear-gradient(135deg, #0f766e 0%, #042f2e 100%); color: #ffffff; padding: 1.5rem; text-align: center; }
  .check-icon { font-size: 1.1rem; }
</style>
</head>
<body>
<div class="install-card">
  <div class="card-header-bar">
    <i class="bi bi-bank2 fs-2 mb-1 d-block"></i>
    <h4 class="fw-bold mb-0">SARVOOCCH Microcare Foundation</h4>
    <small class="opacity-75">Production Web Installer & Environment Verifier</small>
  </div>

  <div class="p-4 p-md-5">
    <?php if ($isLocked): ?>
      <div class="alert alert-success d-flex align-items-center mb-4">
        <i class="bi bi-shield-lock-fill fs-2 me-3 text-success"></i>
        <div>
          <strong class="d-block">Installer is Locked for Security</strong>
          <span class="small">The database has been initialized and this installer is disabled. To re-run, remove <code>portal/storage/installed.lock</code> via FTP/cPanel File Manager.</span>
        </div>
      </div>
      <div class="text-center">
        <a href="<?= url('/login') ?>" class="btn btn-teal text-white px-4 py-2" style="background-color: #0f766e;">
          <i class="bi bi-box-arrow-in-right me-1"></i> Proceed to Portal Sign In
        </a>
      </div>
    <?php else: ?>

      <?php if ($executionResult): ?>
        <div class="alert alert-success d-flex align-items-center mb-4">
          <i class="bi bi-check-circle-fill fs-3 me-3 text-success"></i>
          <div>
            <strong>Installation Completed!</strong>
            <div class="small"><?= htmlspecialchars($executionResult) ?></div>
          </div>
        </div>
      <?php endif; ?>

      <?php if ($executionError): ?>
        <div class="alert alert-danger d-flex align-items-center mb-4">
          <i class="bi bi-exclamation-triangle-fill fs-3 me-3 text-danger"></i>
          <div>
            <strong>Database Error:</strong>
            <div class="small"><?= htmlspecialchars($executionError) ?></div>
          </div>
        </div>
      <?php endif; ?>

      <!-- 1. Environment Matrix -->
      <h6 class="fw-bold text-dark mb-3"><i class="bi bi-cpu me-2 text-teal"></i>System Requirements Matrix</h6>
      <div class="table-responsive mb-4">
        <table class="table table-sm table-bordered align-middle small mb-0">
          <tbody>
            <tr>
              <td>PHP Version (&gt;= 8.1 required)</td>
              <td class="fw-semibold">PHP <?= PHP_VERSION ?></td>
              <td class="text-center"><?= $phpOk ? '<span class="badge bg-success">PASS</span>' : '<span class="badge bg-danger">FAIL</span>' ?></td>
            </tr>
            <tr>
              <td>PDO & MySQL Driver (pdo_mysql)</td>
              <td class="fw-semibold"><?= $pdoMysqlOk ? 'Installed & Active' : 'Not Loaded' ?></td>
              <td class="text-center"><?= ($pdoOk && $pdoMysqlOk) ? '<span class="badge bg-success">PASS</span>' : '<span class="badge bg-danger">FAIL</span>' ?></td>
            </tr>
            <tr>
              <td>Security & Utilities (OpenSSL, JSON, MBString)</td>
              <td class="fw-semibold"><?= ($opensslOk && $jsonOk && $mbstringOk) ? 'All Active' : 'Missing modules' ?></td>
              <td class="text-center"><?= ($opensslOk && $jsonOk && $mbstringOk) ? '<span class="badge bg-success">PASS</span>' : '<span class="badge bg-warning">WARN</span>' ?></td>
            </tr>
            <tr>
              <td>Storage Directory (portal/storage)</td>
              <td class="fw-semibold"><?= $storageWritable ? 'Writable (755/775)' : 'Not Writable' ?></td>
              <td class="text-center"><?= $storageWritable ? '<span class="badge bg-success">PASS</span>' : '<span class="badge bg-danger">FAIL</span>' ?></td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 2. Database Connection -->
      <h6 class="fw-bold text-dark mb-3"><i class="bi bi-database-check me-2 text-teal"></i>Database Status (Hostinger MySQL)</h6>
      <?php if ($dbStatus): ?>
        <div class="p-3 bg-light rounded border mb-4 small">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <div>
              <strong>Driver:</strong> <?= strtoupper($driverName) ?> · 
              <strong>Host:</strong> <?= htmlspecialchars(DB_HOST) ?> · 
              <strong>Database:</strong> <?= htmlspecialchars(DB_NAME) ?>
            </div>
            <span class="badge bg-success"><i class="bi bi-check me-1"></i>Connected</span>
          </div>
          <div class="text-muted">
            Found <strong><?= count($existingTables) ?></strong> existing tables in database:
            <div class="font-monospace text-dark mt-1" style="font-size: 0.75rem;">
              <?= !empty($existingTables) ? implode(', ', $existingTables) : 'No tables yet. Click Initialize below.' ?>
            </div>
          </div>
        </div>
      <?php else: ?>
        <div class="alert alert-warning small mb-4">
          <strong>Cannot connect to database:</strong> <?= htmlspecialchars($dbError ?: 'Check config.php credentials') ?>
          <div class="mt-2 text-muted">
            Make sure database <code><?= htmlspecialchars(DB_NAME) ?></code> exists in Hostinger MySQL and password in <code>portal/app/config.php</code> or <code>portal/.env</code> is correct.
          </div>
        </div>
      <?php endif; ?>

      <!-- 3. Actions -->
      <?php if ($dbStatus): ?>
        <form method="post" action="install.php" class="border-top pt-4">
          <input type="hidden" name="action" value="install">
          <div class="form-check mb-3">
            <input class="form-check-input" type="checkbox" name="lock_after" id="lockAfter" value="1" checked>
            <label class="form-check-label small" for="lockAfter">
              <strong>Lock installer after successful setup</strong> (Recommended for production security)
            </label>
          </div>
          <div class="d-flex gap-2">
            <button type="submit" class="btn btn-teal text-white fw-semibold" style="background-color: #0f766e;">
              <i class="bi bi-lightning-charge-fill me-1"></i> <?= count($existingTables) > 0 ? 'Re-run / Update Database Tables' : 'Initialize Production Database (26 Tables)' ?>
            </button>
            <a href="<?= url('/login') ?>" class="btn btn-outline-secondary">Go to Login</a>
          </div>
        </form>
      <?php endif; ?>

    <?php endif; ?>
  </div>
</div>
</body>
</html>
