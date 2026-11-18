<?php
/**
 * Sarvocch Microcare Foundation - Form Submission Endpoint
 * Designed for Hostinger Premium Web Hosting (PHP 7.4 - 8.3+)
 * Handles: Loan Enquiry, Grievance Complaints, General Contact
 * Includes: WhatsApp Direct Forwarding, Free CallMeBot & Telegram Admin Alerts
 */

header('Content-Type: application/json; charset=utf-8');

// ==========================================================
// 1. CONFIGURATION
// ==========================================================
define('ADMIN_EMAIL', 'sarvocchmicrocare@gmail.com');
define('SITE_NAME', 'Sarvocch Microcare Foundation');
define('DATA_DIR', __DIR__ . '/../data');
define('DB_FILE', DATA_DIR . '/sarvocch.db');
define('SUBMISSIONS_FILE', DATA_DIR . '/submissions.json');

// Official WhatsApp Business Number for Customers to chat with
define('WHATSAPP_BUSINESS_PHONE', '919111199101');

// Optional: Free Instant WhatsApp Notifications to Admin's phone via CallMeBot
// How to activate in 10 seconds:
// Send message "I allow callmebot to send me messages" to +34 924 57 28 40 on WhatsApp
// Enter the returned API key below.
define('CALLMEBOT_ADMIN_PHONE', '919111199101'); // Your WhatsApp number with country code (91...)
define('CALLMEBOT_API_KEY', '');                 // Enter your free CallMeBot API key here

// Optional: Free Telegram Bot Notification (leave empty if not using)
define('TELEGRAM_BOT_TOKEN', '');
define('TELEGRAM_CHAT_ID', '');

// ==========================================================
// 2. REQUEST VALIDATION
// ==========================================================
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed. Only POST is accepted.'
    ]);
    exit;
}

// Honeypot check for spam bots
if (!empty($_POST['website_hp'])) {
    echo json_encode([
        'success' => true,
        'message' => 'Your request has been processed.'
    ]);
    exit;
}

// Sanitization Helper
function clean_input($data, $max_len = 1000) {
    if (is_null($data)) return '';
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    return mb_substr($data, 0, $max_len);
}

$action = clean_input($_POST['form_type'] ?? 'contact', 50);

// Validate based on action type
$errors = [];
$payload = [
    'id'         => uniqid('sarvocch_', true),
    'type'       => $action,
    'timestamp'  => date('c'),
    'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN'
];

if ($action === 'loan_enquiry') {
    $name     = clean_input($_POST['name'] ?? '', 100);
    $phone    = clean_input($_POST['phone'] ?? '', 15);
    $email    = clean_input($_POST['email'] ?? '', 120);
    $state    = clean_input($_POST['state'] ?? '', 80);
    $product  = clean_input($_POST['loan_type'] ?? '', 100);
    $amount   = clean_input($_POST['amount'] ?? '', 30);
    $message  = clean_input($_POST['message'] ?? '', 1000);

    if (empty($name))  $errors[] = 'Full name is required.';
    if (empty($phone) || !preg_match('/^[0-9]{10}$/', $phone)) {
        $errors[] = 'A valid 10-digit mobile number is required.';
    }
    if (empty($state)) $errors[] = 'State selection is required.';
    if (!empty($email) && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $errors[] = 'Invalid email address.';
    }

    $payload += compact('name', 'phone', 'email', 'state', 'product', 'amount', 'message');
    $subject = "New Loan Enquiry: {$name} (₹{$amount})";

    $wa_text = "👋 *New Loan Enquiry - Sarvocch Microcare*\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "👤 *Name:* " . $name . "\n" .
               "📱 *Phone:* " . $phone . "\n" .
               "📍 *State:* " . $state . "\n" .
               "💼 *Product:* " . ($product ?: 'General Enquiry') . "\n" .
               "💰 *Amount:* ₹" . ($amount ?: 'To be discussed') . "\n" .
               "📝 *Purpose:* " . ($message ?: 'Livelihood finance') . "\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "Ref ID: #" . substr($payload['id'], -8);

} elseif ($action === 'grievance') {
    $name     = clean_input($_POST['name'] ?? '', 100);
    $phone    = clean_input($_POST['phone'] ?? '', 15);
    $category = clean_input($_POST['category'] ?? '', 100);
    $details  = clean_input($_POST['details'] ?? '', 2000);

    if (empty($name))     $errors[] = 'Full name is required.';
    if (empty($phone) || !preg_match('/^[0-9]{10}$/', $phone)) {
        $errors[] = 'A valid 10-digit mobile number is required.';
    }
    if (empty($category)) $errors[] = 'Complaint category is required.';
    if (empty($details))  $errors[] = 'Complaint details are required.';

    $payload += compact('name', 'phone', 'category', 'details');
    $subject = "Grievance Complaint Logged: {$name} [{$category}]";

    $wa_text = "⚠️ *Customer Grievance Logged - Sarvocch Microcare*\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "👤 *Complainant:* " . $name . "\n" .
               "📱 *Phone:* " . $phone . "\n" .
               "📂 *Category:* " . $category . "\n" .
               "📝 *Details:* " . $details . "\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "Grievance ID: #" . substr($payload['id'], -8);

} else { // contact
    $name    = clean_input($_POST['name'] ?? '', 100);
    $email   = clean_input($_POST['email'] ?? '', 120);
    $phone   = clean_input($_POST['phone'] ?? '', 15);
    $message = clean_input($_POST['message'] ?? '', 1500);

    if (empty($name))    $errors[] = 'Full name is required.';
    if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $errors[] = 'A valid email address is required.';
    }
    if (empty($message)) $errors[] = 'Message is required.';

    $payload += compact('name', 'email', 'phone', 'message');
    $subject = "Website Contact Message from {$name}";

    $wa_text = "💬 *Contact Message - Sarvocch Microcare*\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "👤 *Name:* " . $name . "\n" .
               "📧 *Email:* " . $email . "\n" .
               "📱 *Phone:* " . ($phone ?: 'N/A') . "\n" .
               "📝 *Message:* " . $message . "\n" .
               "━━━━━━━━━━━━━━━━━━━━━━\n" .
               "Ref ID: #" . substr($payload['id'], -8);
}

// Return errors if any
if (!empty($errors)) {
    http_response_code(422);
    echo json_encode([
        'success' => false,
        'message' => implode(' ', $errors)
    ]);
    exit;
}

// ==========================================================
// 3. PERSIST SUBMISSION TO SQLITE DATABASE & JSON BACKUP
// ==========================================================
if (!is_dir(DATA_DIR)) {
    @mkdir(DATA_DIR, 0755, true);
}

// 3.1 SQLite Database Insertion
try {
    if (class_exists('PDO')) {
        $pdo = new PDO('sqlite:' . DB_FILE);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

        // Ensure tables exist
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS loan_enquiries (
                id TEXT PRIMARY KEY,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                name TEXT NOT NULL,
                phone TEXT NOT NULL,
                email TEXT,
                state TEXT NOT NULL,
                product TEXT,
                amount REAL,
                message TEXT,
                ip_address TEXT,
                status TEXT DEFAULT 'NEW'
            );
            CREATE TABLE IF NOT EXISTS grievances (
                id TEXT PRIMARY KEY,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                name TEXT NOT NULL,
                phone TEXT NOT NULL,
                category TEXT NOT NULL,
                details TEXT NOT NULL,
                ip_address TEXT,
                status TEXT DEFAULT 'OPEN'
            );
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                phone TEXT,
                message TEXT NOT NULL,
                ip_address TEXT,
                status TEXT DEFAULT 'UNREAD'
            );
        ");

        if ($action === 'loan_enquiry') {
            $stmt = $pdo->prepare("
                INSERT INTO loan_enquiries (id, name, phone, email, state, product, amount, message, ip_address)
                VALUES (:id, :name, :phone, :email, :state, :product, :amount, :message, :ip)
            ");
            $stmt->execute([
                ':id'      => $payload['id'],
                ':name'    => $payload['name'] ?? '',
                ':phone'   => $payload['phone'] ?? '',
                ':email'   => $payload['email'] ?? '',
                ':state'   => $payload['state'] ?? '',
                ':product' => $payload['product'] ?? '',
                ':amount'  => floatval($payload['amount'] ?? 0),
                ':message' => $payload['message'] ?? '',
                ':ip'      => $payload['ip_address'] ?? ''
            ]);
        } elseif ($action === 'grievance') {
            $stmt = $pdo->prepare("
                INSERT INTO grievances (id, name, phone, category, details, ip_address)
                VALUES (:id, :name, :phone, :category, :details, :ip)
            ");
            $stmt->execute([
                ':id'       => $payload['id'],
                ':name'     => $payload['name'] ?? '',
                ':phone'    => $payload['phone'] ?? '',
                ':category' => $payload['category'] ?? '',
                ':details'  => $payload['details'] ?? '',
                ':ip'       => $payload['ip_address'] ?? ''
            ]);
        } else {
            $stmt = $pdo->prepare("
                INSERT INTO contacts (id, name, email, phone, message, ip_address)
                VALUES (:id, :name, :email, :phone, :message, :ip)
            ");
            $stmt->execute([
                ':id'      => $payload['id'],
                ':name'    => $payload['name'] ?? '',
                ':email'   => $payload['email'] ?? '',
                ':phone'   => $payload['phone'] ?? '',
                ':message' => $payload['message'] ?? '',
                ':ip'      => $payload['ip_address'] ?? ''
            ]);
        }
    }
} catch (Exception $e) {
    error_log("SQLite Insert Error: " . $e->getMessage());
}

// 3.2 JSON File Backup
$submissions = [];
if (file_exists(SUBMISSIONS_FILE)) {
    $existing = @file_get_contents(SUBMISSIONS_FILE);
    $decoded = json_decode($existing, true);
    if (is_array($decoded)) {
        $submissions = $decoded;
    }
}
$submissions[] = $payload;
if (count($submissions) > 500) {
    $submissions = array_slice($submissions, -500);
}
@file_put_contents(SUBMISSIONS_FILE, json_encode($submissions, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE), LOCK_EX);

// ==========================================================
// 4. EMAIL NOTIFICATION
// ==========================================================
$email_body = "
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<style>
  body { font-family: Arial, sans-serif; line-height: 1.6; color: #1e293b; background: #f8fafc; padding: 20px; }
  .card { max-width: 600px; margin: auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; }
  h2 { color: #0757b8; margin-top: 0; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; }
  th, td { padding: 10px; border-bottom: 1px solid #f1f5f9; text-align: left; }
  th { background: #f8fafc; color: #475569; width: 35%; }
  .footer { margin-top: 20px; font-size: 12px; color: #94a3b8; text-align: center; }
</style>
</head>
<body>
<div class='card'>
  <h2>" . htmlspecialchars($subject) . "</h2>
  <p>A new form submission was received on the Sarvocch Microcare website:</p>
  <table>
";

foreach ($payload as $key => $val) {
    if (in_array($key, ['id', 'ip_address'])) continue;
    $label = ucwords(str_replace('_', ' ', $key));
    $email_body .= "<tr><th>" . htmlspecialchars($label) . "</th><td>" . nl2br(htmlspecialchars($val)) . "</td></tr>";
}

$email_body .= "
  </table>
  <div class='footer'>
    Submission ID: {$payload['id']} | Received: {$payload['timestamp']}
  </div>
</div>
</body>
</html>
";

$headers = [
    'MIME-Version: 1.0',
    'Content-Type: text/html; charset=UTF-8',
    'From: ' . SITE_NAME . ' <no-reply@sarvocchfinance.com>',
    'X-Mailer: PHP/' . phpversion()
];

if (!empty($payload['email']) && filter_var($payload['email'], FILTER_VALIDATE_EMAIL)) {
    $headers[] = 'Reply-To: ' . $payload['email'];
}

@mail(ADMIN_EMAIL, $subject, $email_body, implode("\r\n", $headers));

// ==========================================================
// 5. AUTOMATED INSTANT ADMIN ALERTS (CALLMEBOT / TELEGRAM)
// ==========================================================
// Free WhatsApp Alert to Admin Phone
if (!empty(CALLMEBOT_API_KEY) && !empty(CALLMEBOT_ADMIN_PHONE)) {
    $bot_url = "https://api.callmebot.com/whatsapp.php?phone=" . urlencode(CALLMEBOT_ADMIN_PHONE) .
               "&text=" . urlencode($wa_text) .
               "&apikey=" . urlencode(CALLMEBOT_API_KEY);
    $ctx = stream_context_create(['http' => ['timeout' => 3]]);
    @file_get_contents($bot_url, false, $ctx);
}

// Free Telegram Alert (if configured)
if (!empty(TELEGRAM_BOT_TOKEN) && !empty(TELEGRAM_CHAT_ID)) {
    $tg_url = "https://api.telegram.org/bot" . TELEGRAM_BOT_TOKEN . "/sendMessage?chat_id=" . urlencode(TELEGRAM_CHAT_ID) . "&text=" . urlencode($wa_text);
    $ctx = stream_context_create(['http' => ['timeout' => 3]]);
    @file_get_contents($tg_url, false, $ctx);
}

// ==========================================================
// 6. RESPONSE & USER WHATSAPP DEEP-LINK
// ==========================================================
$whatsapp_url = "https://wa.me/" . WHATSAPP_BUSINESS_PHONE . "?text=" . urlencode($wa_text);

$success_messages = [
    'loan_enquiry' => 'Thank you! Your loan enquiry has been submitted. Our Bhopal branch team will get in touch with you.',
    'grievance'    => 'Your grievance has been successfully submitted. You will be contacted according to our customer protection guidelines.',
    'contact'      => 'Thank you! Your message has been received and forwarded to our team.'
];

echo json_encode([
    'success'      => true,
    'message'      => $success_messages[$action] ?? 'Thank you. Your submission was received.',
    'id'           => $payload['id'],
    'whatsapp_url' => $whatsapp_url,
    'wa_text'      => $wa_text
]);
exit;
