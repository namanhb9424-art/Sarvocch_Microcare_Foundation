<?php
/**
 * SARVOOCCH Microcare Foundation - Platform Settings & Holidays Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class SettingsController {
    public function index(): void {
        need('settings', 'admin');
        $cfg = Database::getConfig();
        $holidays = q("SELECT * FROM holidays ORDER BY day ASC");

        view('settings/index', [
            'cfg' => $cfg,
            'defs' => SETTING_DEFS,
            'holidays' => $holidays
        ]);
    }

    public function save(): void {
        csrf_verify();
        need('settings', 'admin');

        $action = $_POST['action'] ?? 'save';

        if ($action === 'save') {
            foreach (SETTING_DEFS as [$key, $lbl, $default, $kind]) {
                if (isset($_POST[$key])) {
                    $val = trim($_POST[$key]);
                    ex("INSERT INTO settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value`=VALUES(`value`)",
                        [$key, $val]);
                }
            }
            Database::refreshConfig();
            flash("System parameters updated successfully.", "success");
        } elseif ($action === 'add_holiday') {
            $day = $_POST['day'] ?? '';
            $name = trim($_POST['name'] ?? '');
            if (!empty($day) && !empty($name)) {
                ex("INSERT INTO holidays (`day`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name`=VALUES(`name`)",
                    [$day, $name]);
                flash("Public holiday added: " . htmlspecialchars($name), "success");
            }
        } elseif ($action === 'del_holiday') {
            $day = $_POST['day'] ?? '';
            if (!empty($day)) {
                ex("DELETE FROM holidays WHERE `day`=?", [$day]);
                flash("Holiday removed.", "info");
            }
        }

        redirect(url('/settings'));
    }

    public function backupSql(): void {
        need('settings', 'admin');

        $pdo = Database::getConnection();
        $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

        $dateStr = date('Y-m-d_His');
        $filename = "sarvocch_db_backup_{$dateStr}.sql";

        header('Content-Type: application/sql; charset=utf-8');
        header("Content-Disposition: attachment; filename=\"{$filename}\"");
        header('Pragma: no-cache');
        header('Expires: 0');

        echo "-- ==========================================================\n";
        echo "-- SARVOOCCH Microcare Foundation - Database Export / Backup\n";
        echo "-- CIN: U88900MP2026NPL084139 · Section 8 Microfinance\n";
        echo "-- Generated At: " . date('Y-m-d H:i:s T') . "\n";
        echo "-- Database Driver: " . strtoupper($driver) . "\n";
        echo "-- ==========================================================\n\n";

        if ($driver === 'sqlite') {
            $tablesStmt = $pdo->query("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
            while ($row = $tablesStmt->fetch(PDO::FETCH_ASSOC)) {
                $table = $row['name'];
                echo "-- Table structure for `{$table}`\n";
                echo "DROP TABLE IF EXISTS `{$table}`;\n";
                echo $row['sql'] . ";\n\n";

                $rowsStmt = $pdo->query("SELECT * FROM \"{$table}\"");
                $dataRows = $rowsStmt->fetchAll(PDO::FETCH_ASSOC);
                if (!empty($dataRows)) {
                    echo "-- Dumping data for `{$table}`\n";
                    foreach ($dataRows as $r) {
                        $cols = array_map(fn($c) => "`" . $c . "`", array_keys($r));
                        $vals = array_map(function($v) use ($pdo) {
                            if ($v === null) return 'NULL';
                            return $pdo->quote((string)$v);
                        }, array_values($r));
                        echo "INSERT INTO `{$table}` (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $vals) . ");\n";
                    }
                    echo "\n";
                }
            }
        } else {
            // MySQL
            echo "SET FOREIGN_KEY_CHECKS = 0;\n";
            echo "SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';\n\n";

            $tablesStmt = $pdo->query("SHOW TABLES");
            $tables = $tablesStmt->fetchAll(PDO::FETCH_COLUMN);

            foreach ($tables as $table) {
                echo "-- --------------------------------------------------------\n";
                echo "-- Table structure for `{$table}`\n";
                echo "-- --------------------------------------------------------\n";
                echo "DROP TABLE IF EXISTS `{$table}`;\n";

                $createStmt = $pdo->query("SHOW CREATE TABLE `{$table}`");
                $createRow = $createStmt->fetch(PDO::FETCH_NUM);
                echo $createRow[1] . ";\n\n";

                $rowsStmt = $pdo->query("SELECT * FROM `{$table}`");
                $dataRows = $rowsStmt->fetchAll(PDO::FETCH_ASSOC);
                if (!empty($dataRows)) {
                    echo "-- Dumping data for `{$table}`\n";
                    foreach ($dataRows as $r) {
                        $cols = array_map(fn($c) => "`" . $c . "`", array_keys($r));
                        $vals = array_map(function($v) use ($pdo) {
                            if ($v === null) return 'NULL';
                            return $pdo->quote((string)$v);
                        }, array_values($r));
                        echo "INSERT INTO `{$table}` (" . implode(', ', $cols) . ") VALUES (" . implode(', ', $vals) . ");\n";
                    }
                    echo "\n";
                }
            }
            echo "SET FOREIGN_KEY_CHECKS = 1;\n";
        }

        echo "-- Backup generated successfully.\n";
        exit;
    }
}
