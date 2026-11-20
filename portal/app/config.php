<?php
/**
 * SARVOOCCH Microcare Foundation - Core Configuration
 * Optimized for Hostinger LiteSpeed + PHP 8.3
 * Subfolder Deployment: https://sarvocchfinance.com/portal
 */

if (!defined('SARVOOCCH_APP')) {
    define('SARVOOCCH_APP', true);
}

// --------------------------------------------------------------------------
// 1. Environment & Base Paths
// --------------------------------------------------------------------------
define('BASE_PATH', dirname(__DIR__));
define('APP_PATH', BASE_PATH . '/app');
define('STORAGE_PATH', BASE_PATH . '/storage');
define('UPLOAD_DIR', STORAGE_PATH . '/uploads');

// Load environment variables from .env if present
$possibleEnvFiles = [];
foreach ([BASE_PATH, APP_PATH, dirname(BASE_PATH)] as $dir) {
    $possibleEnvFiles[] = $dir . '/.env';
    $possibleEnvFiles[] = $dir . '/. env';
    $possibleEnvFiles[] = $dir . '/.env.txt';
}

foreach ($possibleEnvFiles as $envFile) {
    if (file_exists($envFile) && is_readable($envFile)) {
        $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) continue;
            if (str_contains($line, '=')) {
                [$k, $v] = explode('=', $line, 2);
                $k = trim($k);
                $v = trim($v, " \t\n\r\0\x0B\"'");
                @putenv("$k=$v");
                $_ENV[$k] = $v;
                $_SERVER[$k] = $v;
            }
        }
        break;
    }
}

// Optional local overrides
if (file_exists(APP_PATH . '/config.local.php')) {
    require_once APP_PATH . '/config.local.php';
}

// Helper to reliably read environment across all PHP SAPI / disable_functions environments
$cfgGet = function(string $key, mixed $default = null): mixed {
    if (isset($_ENV[$key]) && $_ENV[$key] !== '') return $_ENV[$key];
    if (isset($_SERVER[$key]) && $_SERVER[$key] !== '') return $_SERVER[$key];
    $val = @getenv($key);
    if ($val !== false && $val !== '') return $val;
    return $default;
};

// Automatically detect base URL path for subfolder hosting (e.g. /portal)
$scriptDir = dirname($_SERVER['SCRIPT_NAME'] ?? '');
$baseUri = rtrim(str_replace('\\', '/', $scriptDir), '/');
define('BASE_URI', $baseUri === '' ? '' : $baseUri);

// --------------------------------------------------------------------------
// 2. Database Credentials
// Hostinger uses 'localhost' via UNIX domain socket for MySQL
// --------------------------------------------------------------------------
if (!defined('DB_HOST')) define('DB_HOST', $cfgGet('DB_HOST', 'localhost'));
if (!defined('DB_PORT')) define('DB_PORT', (int)$cfgGet('DB_PORT', 3306));
if (!defined('DB_NAME')) define('DB_NAME', $cfgGet('DB_NAME', 'u170129876_15wvs'));
if (!defined('DB_USER')) define('DB_USER', $cfgGet('DB_USER', 'u170129876_7UJs1'));
if (!defined('DB_PASS')) define('DB_PASS', $cfgGet('DB_PASS', ''));

// --------------------------------------------------------------------------
// 3. Security & Application Secrets
// --------------------------------------------------------------------------
define('SECRET_KEY', $cfgGet('SECRET_KEY', $cfgGet('APP_KEY', 'sarvoocch_prod_secure_token_key_2026_9111199101')));
if (!defined('APP_KEY')) define('APP_KEY', SECRET_KEY);
define('AADHAAR_HMAC_KEY', $cfgGet('AADHAAR_HMAC_KEY', 'sarvoocch_aadhaar_hmac_secret_key_2026_salt'));
define('APP_DEBUG', ($cfgGet('APP_DEBUG') === '1' || $cfgGet('FLASK_DEBUG') === '1'));
define('DISABLE_DEMO_LOGINS', ($cfgGet('DISABLE_DEMO_LOGINS') === '1' || !APP_DEBUG));

// Session lifetime (in minutes)
define('SESSION_LIFETIME_MIN', 60);

// File uploads
define('MAX_UPLOAD_SIZE', 16 * 1024 * 1024); // 16 MB
define('ALLOWED_EXT', ['pdf', 'png', 'jpg', 'jpeg']);

// --------------------------------------------------------------------------
// 4. Role-Based Access Control (RBAC) - Identical to Portal Specification
// --------------------------------------------------------------------------
define('PERMS', [
    'admin' => ['*'],
    'manager' => [
        'dashboard', 'crm', 'kyc', 'apply', 'applications', 'approve', 'disburse', 'loans',
        'payments', 'field', 'employees', 'hrm', 'whatsapp', 'sync', 'calculator', 'products',
        'kycform', 'pregrt', 'attendance', 'reports'
    ],
    'underwriter' => [
        'dashboard', 'crm', 'kyc', 'applications', 'approve', 'loans', 'calculator',
        'pregrt', 'attendance', 'reports'
    ],
    'field_agent' => [
        'crm', 'kyc', 'apply', 'applications', 'field', 'sync', 'calculator', 'whatsapp',
        'payments', 'kycform', 'pregrt', 'attendance'
    ],
    'customer' => ['portal', 'payments', 'calculator']
]);

define('ROLES', array_keys(PERMS));

// Navigation Menu Definitions
define('NAV', [
    ['dashboard', 'Dashboard', 'dashboard', 'speedometer2'],
    ['portal', 'My Loans', 'portal', 'wallet2'],
    ['crm', 'CRM', 'crm', 'people'],
    ['kycform', 'New Customer (KYC Form)', 'kyc_form_new', 'person-vcard'],
    ['pregrt', 'Pre-GRT (Group Form)', 'pregrt_list', 'people-fill'],
    ['apply', 'New Application', 'apply', 'file-earmark-plus'],
    ['applications', 'Applications', 'applications', 'files'],
    ['approve', 'Approvals', 'approvals', 'check2-circle'],
    ['disburse', 'Disbursements', 'disbursements', 'cash-stack'],
    ['loans', 'Loan Accounts', 'loans', 'bank'],
    ['payments', 'Collect Repayment', 'payments', 'credit-card'],
    ['calculator', 'EMI Calculator', 'calculator', 'calculator'],
    ['field', 'Field Ops & GPS', 'field', 'geo-alt'],
    ['employees', 'Employee Directory', 'employees', 'person-badge'],
    ['hrm', 'HRM & Leave', 'hrm', 'briefcase'],
    ['attendance', 'Daily Attendance', 'attendance', 'clock-history'],
    ['reports', 'Reports & Compliance', 'reports', 'file-earmark-bar-graph'],
    ['products', 'Loan Products', 'products', 'tags'],
    ['branches', 'Branches & Geo-Fence', 'branches', 'building'],
    ['holidays', 'Holiday Calendar', 'holidays', 'calendar3'],
    ['settings', 'System Settings', 'settings', 'gear'],
    ['users', 'User Administration', 'users', 'shield-lock'],
    ['whatsapp', 'WhatsApp Broadcast', 'whatsapp', 'whatsapp'],
    ['sync', 'Offline Sync Logs', 'sync', 'arrow-repeat']
]);

// --------------------------------------------------------------------------
// 5. System Setting Definitions
// --------------------------------------------------------------------------
define('SETTING_DEFS', [
    ['min_age', 'Minimum Borrower Age (Years)', 18, 'int'],
    ['max_age', 'Maximum Borrower Age (Years)', 55, 'int'],
    ['group_min', 'Minimum Group Members (JLG)', 2, 'int'],
    ['group_max', 'Maximum Group Members (JLG)', 5, 'int'],
    ['income_limit', 'Maximum Monthly Household Income (₹)', 25000, 'int'],
    ['emi_pct', 'Maximum FOIR / EMI Ratio (%)', 60, 'int'],
    ['gst_rate', 'GST on Processing Fee (%)', 18, 'float'],
    ['att_hours', 'Daily Working Shift Hours', 8, 'float']
]);

// --------------------------------------------------------------------------
// 6. Default Branches (Seeded in schema)
// --------------------------------------------------------------------------
define('DEFAULT_BRANCHES', [
    ['Bhopal Head Office', 'BPL-HO', 'Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041', '9111199101', 23.279930, 77.452200],
    ['Pipariya Branch', 'PPR', 'Pipariya, Narmadapuram District, Madhya Pradesh', '9800000001', 22.738750, 78.356346],
    ['Indore - Vijay Nagar', 'IND-VN', 'Vijay Nagar Commercial Complex, Indore, Madhya Pradesh', '9800000002', 22.753300, 75.893700],
    ['Indore - Palasia', 'IND-PL', 'Palasia Square, Indore, Madhya Pradesh', '9800000003', 22.724100, 75.883900],
    ['Bhopal - MP Nagar', 'BPL-MP', 'Zone II, MP Nagar, Bhopal, Madhya Pradesh', '9800000004', 23.233200, 77.434000]
]);
