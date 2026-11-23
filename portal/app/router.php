<?php
/**
 * SARVOOCCH Microcare Foundation - URL Routing Engine
 * Supports subfolder hosting (e.g. /portal) and dynamic parameters
 */

if (!defined('SARVOOCCH_APP')) exit;

class Router {
    private static array $routes = [];

    public static function add(string $method, string $pattern, string $controller, string $action): void {
        self::$routes[] = [
            'method' => strtoupper($method),
            'pattern' => $pattern,
            'controller' => $controller,
            'action' => $action
        ];
    }

    public static function dispatch(): void {
        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

        // Strip subfolder prefix if present (e.g. /portal)
        if (BASE_URI !== '' && str_starts_with($uri, BASE_URI)) {
            $uri = substr($uri, strlen(BASE_URI));
        }

        $uri = rtrim($uri, '/') ?: '/';

        foreach (self::$routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }

            // Convert :param into regex ([^/]+)
            $patternRegex = preg_replace('#:([a-zA-Z0-9_]+)#', '(?P<$1>[^/]+)', $route['pattern']);
            $patternRegex = '#^' . $patternRegex . '$#';

            if (preg_match($patternRegex, $uri, $matches)) {
                $params = [];
                foreach ($matches as $k => $v) {
                    if (!is_int($k)) {
                        $params[$k] = is_numeric($v) ? (int)$v : $v;
                    }
                }

                $controllerClass = $route['controller'];
                $actionMethod = $route['action'];

                if (!class_exists($controllerClass)) {
                    http_response_code(500);
                    die("Controller class not found: " . htmlspecialchars($controllerClass));
                }

                $instance = new $controllerClass();
                if (!method_exists($instance, $actionMethod)) {
                    http_response_code(500);
                    die("Controller method not found: " . htmlspecialchars($actionMethod));
                }

                call_user_func_array([$instance, $actionMethod], array_values($params));
                return;
            }
        }

        // 404 Route Not Found
        http_response_code(404);
        view('errors/404', ['uri' => $uri]);
    }
}

// --------------------------------------------------------------------------
// Route Registrations (All 74+ Routes)
// --------------------------------------------------------------------------

// Auth & Base
Router::add('GET',  '/',                  'AuthController', 'index');
Router::add('GET',  '/login',             'AuthController', 'loginForm');
Router::add('POST', '/login',             'AuthController', 'loginPost');
Router::add('GET',  '/logout',            'AuthController', 'logout');
Router::add('GET',  '/change-password',   'AuthController', 'changePasswordForm');
Router::add('POST', '/change-password',   'AuthController', 'changePasswordPost');

// Dashboard
Router::add('GET',  '/dashboard',         'DashboardController', 'index');
Router::add('GET',  '/dashboard/details', 'DashboardController', 'details');

// CRM
Router::add('GET',  '/crm',                      'CrmController', 'list');
Router::add('POST', '/crm/new',                  'CrmController', 'create');
Router::add('GET',  '/crm/:cid',                 'CrmController', 'detail');
Router::add('POST', '/crm/:cid/log',             'CrmController', 'addLog');
Router::add('POST', '/crm/:cid/stage',           'CrmController', 'updateStage');
Router::add('POST', '/crm/:cid/login',           'CrmController', 'createPortalLogin');
Router::add('GET',  '/crm/:cid/login-slip',      'CrmController', 'loginSlip');
Router::add('GET',  '/crm/:cid/kyc-form',        'KycController', 'form');
Router::add('POST', '/crm/:cid/kyc-form',        'KycController', 'saveForm');
Router::add('GET',  '/crm/:cid/kyc-form/print',  'KycController', 'printForm');

// KYC
Router::add('GET',  '/kyc',              'KycController', 'verifyList');
Router::add('GET',  '/kyc-form/new',     'KycController', 'newForm');
Router::add('POST', '/kyc-form/new',     'KycController', 'saveForm');
Router::add('POST', '/api/kyc/verify',   'ApiController', 'kycVerify');

// Applications
Router::add('GET',  '/applications',              'ApplicationController', 'list');
Router::add('GET',  '/applications/:aid',         'ApplicationController', 'detail');
Router::add('POST', '/applications/:aid/action',  'ApplicationController', 'action');
Router::add('GET',  '/applications/:aid/sanction.pdf', 'ApplicationController', 'sanctionPdf');
Router::add('GET',  '/apply',                     'ApplicationController', 'applyForm');
Router::add('POST', '/apply',                     'ApplicationController', 'applyPost');

// Loans & EMI
Router::add('GET',  '/loans',                    'LoanController', 'list');
Router::add('GET',  '/loans/:lid',               'LoanController', 'detail');
Router::add('GET',  '/loans/:lid/card',          'LoanController', 'card');
Router::add('GET',  '/loans/:lid/noc.pdf',       'LoanController', 'nocPdf');
Router::add('GET',  '/loans/:lid/settle',        'LoanController', 'settleForm');
Router::add('POST', '/loans/:lid/settle',        'LoanController', 'settlePost');
Router::add('GET',  '/portal',                   'LoanController', 'portal');
Router::add('GET',  '/pay/:lid',                 'LoanController', 'payForm');
Router::add('POST', '/pay/:lid',                 'LoanController', 'payPost');

// Pre-GRT Group Assessment
Router::add('GET',  '/pregrt',               'PreGrtController', 'list');
Router::add('GET',  '/pregrt/new',           'PreGrtController', 'newForm');
Router::add('POST', '/pregrt/new',           'PreGrtController', 'create');
Router::add('GET',  '/pregrt/:pid',          'PreGrtController', 'detail');
Router::add('POST', '/pregrt/:pid',          'PreGrtController', 'update');
Router::add('GET',  '/pregrt/:pid/print',    'PreGrtController', 'printDoc');
Router::add('POST', '/pregrt/:pid/review',   'PreGrtController', 'review');
Router::add('GET',  '/pregrt/:pid/apply',    'PreGrtController', 'groupApplyForm');
Router::add('POST', '/pregrt/:pid/apply',    'PreGrtController', 'groupApplyPost');

// Reports (Letterhead & Portfolio Analysis)
Router::add('GET',  '/reports',             'ReportsController', 'index');
Router::add('GET',  '/reports/pdf',         'ReportsController', 'exportPdf');

// Field Operations
Router::add('GET',  '/field',                   'FieldController', 'index');
Router::add('POST', '/field/assign',            'FieldController', 'assign');
Router::add('POST', '/field/attendance',        'AttendanceController', 'punch');
Router::add('POST', '/field/task/:tid/done',    'FieldController', 'taskDone');

// Attendance
Router::add('GET',  '/attendance',                          'AttendanceController', 'index');
Router::add('POST', '/attendance/punch',                    'AttendanceController', 'punch');
Router::add('POST', '/attendance/request',                  'AttendanceController', 'request');
Router::add('POST', '/attendance/request/:rid/:action',     'AttendanceController', 'decide');

// Employees
Router::add('GET',  '/employees',               'EmployeeController', 'list');
Router::add('POST', '/employees/new',           'EmployeeController', 'create');
Router::add('POST', '/employees/:eid/update',   'EmployeeController', 'update');
Router::add('GET',  '/employees/:eid/print',    'EmployeeController', 'printDoc');

// HRM & Leaves
Router::add('GET',  '/hrm',                       'HrmController', 'index');
Router::add('POST', '/hrm/leave',                 'HrmController', 'applyLeave');
Router::add('POST', '/hrm/leave/:lid/:action',    'HrmController', 'decideLeave');
Router::add('POST', '/hrm/perf',                  'HrmController', 'addPerf');

// Branches
Router::add('GET',  '/branches',              'BranchController', 'list');
Router::add('POST', '/branches',              'BranchController', 'create');
Router::add('GET',  '/branches/:bid/details', 'BranchController', 'details');

// Products & Settings
Router::add('GET',  '/products',          'ProductController', 'index');
Router::add('POST', '/products',          'ProductController', 'save');
Router::add('GET',  '/settings',          'SettingsController', 'index');
Router::add('POST', '/settings',          'SettingsController', 'save');

// Users & Roles
Router::add('GET',  '/users',             'UserController', 'index');
Router::add('POST', '/users/:uid/role',   'UserController', 'changeRole');

// WhatsApp & Offline Sync
Router::add('GET',  '/whatsapp',          'WhatsappController', 'index');
Router::add('POST', '/whatsapp/:cid/send',   'WhatsappController', 'send');
Router::add('POST', '/whatsapp/:cid/verify', 'WhatsappController', 'verify');
Router::add('GET',  '/sync',              'SyncController', 'index');
Router::add('POST', '/api/sync',          'SyncController', 'post');

// Calculator & APIs
Router::add('GET',  '/calculator',        'ApiController', 'calculator');
Router::add('GET',  '/api/emi',           'ApiController', 'emiJson');
Router::add('POST', '/api/location',      'ApiController', 'location');
Router::add('GET',  '/api/nearby',        'ApiController', 'nearby');

// Secure Authenticated Uploads
Router::add('GET',  '/uploads/:name',     'UploadsController', 'serve');

// Grievance Redressal (GRO Workflow)
Router::add('GET',  '/grievances',             'GrievanceController', 'index');
Router::add('GET',  '/grievances/:id',         'GrievanceController', 'detail');
Router::add('POST', '/grievances/:id/update',  'GrievanceController', 'update');

// Mobile Field Operations REST API (/api/v1/...)
Router::add('POST', '/api/v1/auth/login',       'MobileApiController', 'login');
Router::add('GET',  '/api/v1/field/tasks',      'MobileApiController', 'getTasks');
Router::add('POST', '/api/v1/field/attendance', 'MobileApiController', 'postAttendance');
Router::add('POST', '/api/v1/field/collection', 'MobileApiController', 'postCollection');
Router::add('POST', '/api/v1/sync',             'MobileApiController', 'batchSync');

// Real-Time Dynamic UPI QR & Receipts & KFS
Router::add('GET',  '/loans/:id/upi-qr',        'LoanController', 'upiQrJson');
Router::add('GET',  '/loans/:id/receipt/:pid',  'LoanController', 'receiptPrint');
Router::add('GET',  '/loans/:id/kfs.pdf',       'LoanController', 'kfsPdf');

// Regulatory Backup
Router::add('GET',  '/settings/backup.sql',     'SettingsController', 'backupSql');

// Live Regulatory Portfolio Export
Router::add('GET',  '/reports/export-csv',      'ReportsController', 'exportCsv');


