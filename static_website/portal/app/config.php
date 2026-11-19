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

// Automatically detect base URL path for subfolder hosting (e.g. /portal)
$scriptDir = dirname($_SERVER['SCRIPT_NAME'] ?? '');
$baseUri = rtrim(str_replace('\\', '/', $scriptDir), '/');
define('BASE_URI', $baseUri === '' ? '' : $baseUri);

// --------------------------------------------------------------------------
// 2. Database Credentials
// Hostinger uses localhost for MySQL
// --------------------------------------------------------------------------
define('DB_HOST', getenv('DB_HOST') ?: '127.0.0.1');
define('DB_PORT', (int)(getenv('DB_PORT') ?: 3306));
define('DB_NAME', getenv('DB_NAME') ?: 'sarvoocch_portal');
define('DB_USER', getenv('DB_USER') ?: 'sarvoocch_user');
define('DB_PASS', getenv('DB_PASS') ?: ''); // Set via .env or server environment

// --------------------------------------------------------------------------
// 3. Security & Application Secrets
// --------------------------------------------------------------------------
define('SECRET_KEY', getenv('SECRET_KEY') ?: 'sarvoocch_prod_secure_token_key_2026_9111199101');
define('APP_DEBUG', (getenv('APP_DEBUG') === '1' || getenv('FLASK_DEBUG') === '1'));
define('DISABLE_DEMO_LOGINS', getenv('DISABLE_DEMO_LOGINS') === '1' || !APP_DEBUG);

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
    ['loans', 'Loans & EMI', 'loans', 'cash-coin'],
    ['reports', 'Reports', 'reports', 'file-earmark-bar-graph'],
    ['kyc', 'KYC Verify', 'kyc', 'shield-check'],
    ['calculator', 'EMI Calculator', 'calculator', 'calculator'],
    ['products', 'Loan Products', 'products', 'box-seam'],
    ['field', 'Field Operations', 'field', 'geo-alt'],
    ['sync', 'Offline Sync', 'sync', 'arrow-repeat'],
    ['whatsapp', 'WhatsApp', 'whatsapp', 'whatsapp'],
    ['employees', 'Employees', 'employees', 'person-badge'],
    ['hrm', 'HRM', 'hrm', 'briefcase'],
    ['attendance', 'Attendance', 'attendance', 'clock-history'],
    ['branches', 'Branches', 'branches', 'building'],
    ['settings', 'Settings', 'settings', 'gear'],
    ['users', 'Users & Roles', 'users', 'key']
]);

// --------------------------------------------------------------------------
// 5. Default Business Constants & Fallback Parameters
// --------------------------------------------------------------------------
define('DEFAULT_BRANCHES', [
    ['Bhopal Head Office', 'BPL-HO', 'Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041', 23.27993, 77.45220],
    ['Pipariya Branch', 'PPR', 'Pipariya, Narmadapuram, Madhya Pradesh', 22.73875, 78.35635],
    ['Indore - Vijay Nagar', 'IND-VN', 'Vijay Nagar, Indore', 22.7533, 75.8937],
    ['Indore - Palasia', 'IND-PL', 'Palasia, Indore', 22.7241, 75.8839],
    ['Bhopal - MP Nagar', 'BPL-MP', 'MP Nagar, Bhopal', 23.2332, 77.4340]
]);

define('SETTING_DEFS', [
    ['min_age', 'Minimum borrower age (years)', 18, 'int'],
    ['max_age', 'Maximum borrower age (years)', 55, 'int'],
    ['group_min', 'Minimum members in a group', 2, 'int'],
    ['group_max', 'Maximum members in a group', 5, 'int'],
    ['income_limit', 'Household monthly income limit (Rs)', 25000, 'num'],
    ['emi_pct', 'Maximum EMI as % of household monthly income', 60, 'num'],
    ['gst_rate', 'GST rate on the processing fee (%), shown as half CGST + half SGST', 18, 'num'],
    ['att_hours', 'Minimum hours worked before punch-out is allowed', 8, 'num']
]);
