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
}
