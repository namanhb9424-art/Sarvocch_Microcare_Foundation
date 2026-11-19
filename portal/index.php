<?php
/**
 * SARVOOCCH Microcare Foundation - Web Portal Front Controller
 * Entry point for https://sarvocchfinance.com/portal
 */

define('SARVOOCCH_APP', true);

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
