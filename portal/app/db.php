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

        $sqlitePath = STORAGE_PATH . '/sarvocch.db';

        try {
            // Attempt MySQL connection if credentials are configured
            if (!empty(DB_PASS) || getenv('FORCE_MYSQL') === '1') {
                $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME);
                $options = [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
                ];
                self::$instance = new PDO($dsn, DB_USER, DB_PASS, $options);
            } elseif (file_exists($sqlitePath)) {
                // If MySQL password is not yet configured, use pre-seeded SQLite immediately
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
            } else {
                // Try MySQL anyway if SQLite database does not exist
                $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME);
                $options = [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
                ];
                self::$instance = new PDO($dsn, DB_USER, DB_PASS, $options);
            }
        } catch (PDOException $e) {
            // Fallback to SQLite if MySQL fails
            if (file_exists($sqlitePath) || getenv('USE_SQLITE') === '1') {
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
            } else {
                throw new Exception("Database Connection Failed: " . $e->getMessage() . " [Host: " . DB_HOST . ", Database: " . DB_NAME . ", User: " . DB_USER . "]");
            }
        }

        if (self::$instance->getAttribute(PDO::ATTR_DRIVER_NAME) === 'sqlite' && method_exists(self::$instance, 'sqliteCreateFunction')) {
            self::$instance->sqliteCreateFunction('NOW', fn() => date('Y-m-d H:i:s'));
            self::$instance->sqliteCreateFunction('CURDATE', fn() => date('Y-m-d'));
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
