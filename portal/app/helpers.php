<?php
/**
 * SARVOOCCH Microcare Foundation - Global Helpers & Formatting
 */

if (!defined('SARVOOCCH_APP')) exit;

function url(string $path = ''): string {
    $path = '/' . ltrim($path, '/');
    return BASE_URI . $path;
}

function redirect(string $url): void {
    header("Location: " . $url);
    exit;
}

function json_response(array $data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data);
    exit;
}

function inr(mixed $v): string {
    $v = (float)($v ?: 0);
    $neg = $v < 0;
    $v = abs($v);
    $parts = explode('.', sprintf('%.2f', $v));
    $i = $parts[0];
    $d = $parts[1];

    if (strlen($i) > 3) {
        $head = substr($i, 0, -3);
        $tail = substr($i, -3);
        $head = preg_replace('/(\d)(?=(\d\d)+$)/', '$1,', $head);
        $i = $head . ',' . $tail;
    }
    return ($neg ? '-' : '') . '₹' . $i . '.' . $d;
}

function fmt_date(mixed $v): string {
    if (empty($v)) return '-';
    try {
        $d = new DateTime(substr((string)$v, 0, 10));
        return $d->format('d M Y');
    } catch (Exception $e) {
        return (string)$v ?: '-';
    }
}

function view(string $template, array $data = []): void {
    extract($data);
    $user = current_user();
    $branches = Database::getBranches();
    $cfg = Database::getConfig();
    $roles = ROLES;
    $today = date('Y-m-d');

    // Filter nav by role
    $nav = [];
    foreach (NAV as $n) {
        if (can($n[0]) || ($n[0] === 'users' && $user && $user['role'] === 'admin')) {
            $nav[] = $n;
        }
    }

    $viewFile = APP_PATH . '/views/' . $template . '.php';
    if (!file_exists($viewFile)) {
        http_response_code(500);
        die("View template not found: " . htmlspecialchars($template));
    }

    // Capture child view content
    ob_start();
    include $viewFile;
    $childContent = ob_get_clean();

    // Render inside base layout unless $noLayout is set
    if (!empty($noLayout)) {
        echo $childContent;
    } else {
        include APP_PATH . '/views/layout/base.php';
    }
}

// --------------------------------------------------------------------------
// Verhoeff Algorithm for Aadhaar Validation
// --------------------------------------------------------------------------
class Verhoeff {
    private static array $d = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
        [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
        [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
        [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
        [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
        [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
        [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
        [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
        [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    ];

    private static array $p = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
        [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
        [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
        [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
        [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
        [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
        [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
    ];

    private static array $inv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];

    public static function validate(string $num): bool {
        if (!ctype_digit($num) || strlen($num) === 0) return false;
        $c = 0;
        $reversed = array_reverse(str_split($num));
        foreach ($reversed as $i => $ch) {
            $c = self::$d[$c][self::$p[$i % 8][(int)$ch]];
        }
        return $c === 0;
    }
}

function validate_id(string $kind, string $num): bool {
    $num = trim($num);
    if ($kind === 'aadhaar') {
        $clean = preg_replace('/\s+/', '', $num);
        return strlen($clean) === 12 && Verhoeff::validate($clean);
    }
    if ($kind === 'pan') {
        return (bool)preg_match('/^[A-Z]{5}[0-9]{4}[A-Z]$/', strtoupper($num));
    }
    if ($kind === 'voter') {
        return (bool)preg_match('/^[A-Z]{3}[0-9]{7}$/', strtoupper($num));
    }
    return false;
}

// --------------------------------------------------------------------------
// Geolocation & Route Optimization
// --------------------------------------------------------------------------
function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float {
    $R = 6371.0; // Earth radius in km
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
    $c = 2 * asin(sqrt($a));
    return $R * $c;
}

function cluster_tasks(array $tasks, float $radius_km = 3.0): array {
    $clusters = [];
    foreach ($tasks as $t) {
        $lat = $t['lat'] ?? null;
        $lng = $t['lng'] ?? null;
        if ($lat === null || $lng === null) {
            $clusters[] = ['name' => 'Unlocated Tasks', 'tasks' => [$t]];
            continue;
        }
        $placed = false;
        foreach ($clusters as &$c) {
            if (isset($c['center_lat'])) {
                $d = haversine($c['center_lat'], $c['center_lng'], $lat, $lng);
                if ($d <= $radius_km) {
                    $c['tasks'][] = $t;
                    $placed = true;
                    break;
                }
            }
        }
        if (!$placed) {
            $clusters[] = [
                'name' => 'Cluster ' . (count($clusters) + 1),
                'center_lat' => $lat,
                'center_lng' => $lng,
                'tasks' => [$t]
            ];
        }
    }
    return $clusters;
}

// --------------------------------------------------------------------------
// Secure Upload Handling (Outside Public or Protected by .htaccess)
// --------------------------------------------------------------------------
function safe_upload(array $file, string $prefix, bool $images_only = false): string {
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception("File upload failed with error code: " . $file['error']);
    }
    if ($file['size'] > MAX_UPLOAD_SIZE) {
        throw new Exception("File exceeds maximum allowed size of 16MB.");
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = $images_only ? ['jpg', 'jpeg', 'png'] : ALLOWED_EXT;
    if (!in_array($ext, $allowed, true)) {
        throw new Exception("Only " . implode(', ', $allowed) . " files are allowed.");
    }

    // Magic bytes verification
    $handle = fopen($file['tmp_name'], 'rb');
    $bytes = fread($handle, 8);
    fclose($handle);

    $isPng = str_starts_with($bytes, "\x89PNG\r\n\x1a\n");
    $isJpg = str_starts_with($bytes, "\xff\xd8\xff");
    $isPdf = str_starts_with($bytes, "%PDF");

    if (!$isPng && !$isJpg && (!$isPdf || $images_only)) {
        throw new Exception("File failed security signature validation (invalid MIME structure).");
    }

    $finalExt = $isPng ? 'png' : ($isPdf ? 'pdf' : 'jpg');
    $fileName = $prefix . '_' . bin2hex(random_bytes(8)) . '.' . $finalExt;
    
    if (!is_dir(UPLOAD_DIR)) {
        mkdir(UPLOAD_DIR, 0755, true);
    }
    $targetPath = UPLOAD_DIR . '/' . $fileName;

    if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
        throw new Exception("Failed to persist file to storage directory.");
    }

    return $fileName;
}
