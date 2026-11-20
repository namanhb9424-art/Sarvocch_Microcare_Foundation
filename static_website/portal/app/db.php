<?php
/**
 * SARVOOCCH Microcare Foundation - Database Layer
 * PDO with MySQL (Production) & SQLite (Embedded Fallback/Zero-Config)
 * Provides q() and ex() helpers matching the Python codebase.
 */

if (!defined('SARVOOCCH_APP')) exit;

class Database {
    private static ?PDO $instance = null;
    private static array $configCache = [];
    private static array $branchCache = [];

    public static function getConnection(): PDO {
        if (self::$instance !== null) {
            return self::$instance;
        }

        // Only allow SQLite when explicit environment flag USE_SQLITE=1 is set (dev/testing)
        $useSqlite = (getenv('USE_SQLITE') === '1' || (defined('USE_SQLITE') && USE_SQLITE === true));
        $sqlitePath = STORAGE_PATH . '/sarvocch.db';

        if ($useSqlite) {
            if (!file_exists($sqlitePath)) {
                error_log("SQLite development database not found at: " . $sqlitePath);
                http_response_code(503);
                header('Retry-After: 60');
                echo "<h1>503 Service Unavailable</h1><p>Embedded development database not found.</p>";
                exit;
            }
            try {
                $options = [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
                ];
                self::$instance = new PDO('sqlite:' . $sqlitePath, null, null, $options);
                self::$instance->exec("PRAGMA journal_mode=WAL;");
                self::$instance->exec("PRAGMA foreign_keys=ON;");
                self::$instance->exec("PRAGMA busy_timeout=5000;");
                if (method_exists(self::$instance, 'sqliteCreateFunction')) {
                    self::$instance->sqliteCreateFunction('NOW', fn() => date('Y-m-d H:i:s'));
                    self::$instance->sqliteCreateFunction('CURDATE', fn() => date('Y-m-d'));
                }
                return self::$instance;
            } catch (PDOException $e) {
                error_log("SQLite Connection Error: " . $e->getMessage());
                http_response_code(503);
                header('Retry-After: 60');
                echo "<h1>503 Service Unavailable</h1><p>Database engine error. Please try again later.</p>";
                exit;
            }
        }

        // Production MySQL Connection (USE_SQLITE != 1)
        try {
            $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME);
            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
            ];
            self::$instance = new PDO($dsn, DB_USER, DB_PASS, $options);
        } catch (PDOException $e) {
            // Log error internally without leaking credentials or stack traces to client
            error_log("Production MySQL Connection Failure: " . $e->getMessage());

            http_response_code(503);
            header('Retry-After: 60');
            ?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>503 Service Temporarily Unavailable · SARVOOCCH</title>
<style>
  body { background: #0f172a; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; color: #334155; }
  .card { max-width: 500px; width: 90%; background: #ffffff; border-radius: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.3); padding: 2.5rem; text-align: center; }
  h2 { color: #0f766e; margin-top: 0; font-size: 1.5rem; }
  p { font-size: 0.95rem; line-height: 1.5; color: #64748b; }
  .code { display: inline-block; padding: 0.25rem 0.6rem; background: #f1f5f9; border-radius: 4px; font-size: 0.85rem; color: #475569; margin-top: 1rem; }
</style>
</head>
<body>
<div class="card">
  <h2>SARVOOCCH Microcare Foundation</h2>
  <p>The enterprise financial portal is temporarily undergoing scheduled maintenance or database synchronization.</p>
  <p>Please try again in a few moments.</p>
  <div class="code">HTTP 503 · Service Temporarily Unavailable</div>
</div>
</body>
</html>
            <?php
            exit;
        }

        return self::$instance;
    }

    public static function refreshConfig(): array {
        try {
            $rows = q("SELECT `key`, `value` FROM settings");
            $cfg = [];
            foreach (SETTING_DEFS as [$key, $lbl, $default, $kind]) {
                $cfg[$key] = $kind === 'int' ? (int)$default : (float)$default;
            }
            foreach ($rows as $r) {
                $k = $r['key'];
                $v = $r['value'];
                foreach (SETTING_DEFS as [$defKey, $lbl, $default, $kind]) {
                    if ($k === $defKey) {
                        $cfg[$k] = $kind === 'int' ? (int)$v : (float)$v;
                        break;
                    }
                }
            }
            self::$configCache = $cfg;

            // Branches
            $bRows = q("SELECT name FROM branches WHERE active=1 ORDER BY id");
            self::$branchCache = !empty($bRows) ? array_column($bRows, 'name') : array_column(DEFAULT_BRANCHES, 0);

            return self::$configCache;
        } catch (Exception $e) {
            return [];
        }
    }

    public static function getBranches(): array {
        if (empty(self::$branchCache)) {
            self::refreshConfig();
        }
        return self::$branchCache;
    }

    public static function getConfig(): array {
        if (empty(self::$configCache)) {
            self::refreshConfig();
        }
        return self::$configCache;
    }

    public static function beginTransaction(): bool {
        $db = self::getConnection();
        return $db->inTransaction() ? true : $db->beginTransaction();
    }

    public static function commit(): bool {
        $db = self::getConnection();
        return $db->inTransaction() ? $db->commit() : true;
    }

    public static function rollBack(): bool {
        $db = self::getConnection();
        return $db->inTransaction() ? $db->rollBack() : true;
    }

    public static function inTransaction(): bool {
        return self::getConnection()->inTransaction();
    }
}

/**
 * Transaction helper wrappers
 */
function db_begin(): bool {
    return Database::beginTransaction();
}

function db_commit(): bool {
    return Database::commit();
}

function db_rollback(): bool {
    return Database::rollBack();
}

/**
 * Execute a query and return rows (or one row)
 * Matches Python q(sql, args=(), one=False)
 */
function q(string $sql, array $args = [], bool $one = false): mixed {
    $db = Database::getConnection();
    $stmt = $db->prepare($sql);
    $stmt->execute($args);
    return $one ? $stmt->fetch() : $stmt->fetchAll();
}

/**
 * Execute an INSERT / UPDATE / DELETE statement
 * Matches Python ex(sql, args=())
 * Returns lastInsertId for inserts, or rowCount
 */
function ex(string $sql, array $args = []): int {
    $db = Database::getConnection();
    $stmt = $db->prepare($sql);
    $stmt->execute($args);
    $id = $db->lastInsertId();
    return $id ? (int)$id : $stmt->rowCount();
}
