<?php
/**
 * SARVOOCCH Microcare Foundation - Web Portal Front Controller
 * Entry point for https://sarvocchfinance.com/portal
 * Optimized for Hostinger LiteSpeed + PHP 8.3
 */

define('SARVOOCCH_APP', true);

// 0. Global Exception & Error Handler (Eliminates White Screens of Death)
set_exception_handler(function (Throwable $e) {
    http_response_code(500);
    $msg = $e->getMessage();
    $isDb = str_contains($msg, 'Database Connection Failed') || str_contains($msg, 'SQLSTATE') || str_contains($msg, 'Access denied') || str_contains($msg, 'Connection refused');
    ?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Database Setup Required · SARVOOCCH Portal</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<style>
  body { background: #0f172a; min-height: 100vh; display: flex; align-items: center; justify-content: center; font-family: system-ui, -apple-system, sans-serif; color: #334155; }
  .setup-card { max-width: 640px; width: 100%; border-radius: 14px; background: #ffffff; box-shadow: 0 20px 40px rgba(0,0,0,0.3); overflow: hidden; }
  .card-header-bar { background: linear-gradient(135deg, #0f766e 0%, #042f2e 100%); color: #ffffff; padding: 1.5rem; text-align: center; }
</style>
</head>
<body>
<div class="container p-3">
  <div class="setup-card mx-auto">
    <div class="card-header-bar">
      <i class="bi bi-bank2 fs-2 mb-1 d-block"></i>
      <h5 class="fw-bold mb-0">SARVOOCCH Microcare Foundation</h5>
      <small class="opacity-75">Production Portal · Diagnostics</small>
    </div>
    <div class="p-4 p-md-5">
      <div class="alert alert-warning d-flex align-items-center mb-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-3 me-3 text-warning"></i>
        <div>
          <strong class="d-block"><?= $isDb ? 'Database Setup Required' : 'Portal Notice' ?></strong>
          <span class="small"><?= htmlspecialchars($msg) ?></span>
        </div>
      </div>

      <?php if ($isDb): ?>
        <p class="small text-muted mb-3">
          To complete your Hostinger deployment, please check your database credentials in <code>portal/app/config.php</code> or <code>portal/.env</code>:
        </p>
        <div class="bg-light p-3 rounded small mb-4 font-monospace border">
          DB_HOST = 'localhost'<br>
          DB_NAME = '<?= htmlspecialchars(defined('DB_NAME') ? DB_NAME : 'u170129876_q1gD8') ?>'<br>
          DB_USER = '<?= htmlspecialchars(defined('DB_USER') ? DB_USER : 'u170129876_...') ?>'<br>
          DB_PASS = '<em>your_hostinger_mysql_password</em>'
        </div>
        <p class="small text-muted mb-0">
          Also ensure you have imported <code>setup_database.sql</code> into phpMyAdmin.
        </p>
      <?php endif; ?>

      <div class="text-center mt-4 pt-3 border-top">
        <a href="https://sarvocchfinance.com" class="btn btn-outline-secondary btn-sm me-2">Main Website</a>
        <a href="<?= htmlspecialchars($_SERVER['REQUEST_URI'] ?? '/portal/login') ?>" class="btn btn-primary btn-sm">Retry Connection</a>
      </div>
    </div>
  </div>
</div>
</body>
</html>
    <?php
    exit;
});

// 1. Core Framework Dependencies
require_once __DIR__ . '/app/config.php';
require_once __DIR__ . '/app/db.php';
require_once __DIR__ . '/app/auth.php';
require_once __DIR__ . '/app/helpers.php';
require_once __DIR__ . '/app/emi.php';

// 2. Autoload All Controllers
foreach (glob(__DIR__ . '/app/controllers/*.php') as $controllerFile) {
    require_once $controllerFile;
}

// 3. Router
require_once __DIR__ . '/app/router.php';

// 4. Initialize Secure Session
Auth::initSession();

// 5. Dispatch Request
Router::dispatch();
