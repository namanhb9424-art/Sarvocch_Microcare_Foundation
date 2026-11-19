<?php
/**
 * SARVOOCCH Microcare Foundation - HRM, Leaves & Performance Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class HrmController {
    public function index(): void {
        need('hrm');
        $u = current_user();

        // Leaves
        $leaves = [];
        if (can('admin') || can('manager')) {
            $leaves = q("SELECT l.*, u.name as employee_name, u.branch FROM leaves l JOIN users u ON l.user_id=u.id ORDER BY l.id DESC LIMIT 50");
        } else {
            $leaves = q("SELECT * FROM leaves WHERE user_id=? ORDER BY id DESC LIMIT 20", [$u['id']]);
        }

        // Performance
        $perf = q("SELECT p.*, u.name as employee_name FROM perf p JOIN users u ON p.user_id=u.id ORDER BY p.id DESC LIMIT 30");
        $employees = q("SELECT id, user_id, name, branch FROM employees WHERE status='active' ORDER BY name");

        view('hrm/index', [
            'leaves' => $leaves,
            'perf' => $perf,
            'employees' => $employees
        ]);
    }

    public function applyLeave(): void {
        csrf_verify();
        need('hrm');
        $u = current_user();

        $fromD = $_POST['from_d'] ?: date('Y-m-d');
        $toD = $_POST['to_d'] ?: date('Y-m-d');
        $reason = trim($_POST['reason'] ?? 'Personal');

        ex("INSERT INTO leaves (user_id, from_d, to_d, reason, status) VALUES (?, ?, ?, ?, 'pending')",
            [$u['id'], $fromD, $toD, $reason]);

        flash("Leave application submitted for supervisor review.", "success");
        redirect(url('/hrm'));
    }

    public function decideLeave(int $lid, string $action): void {
        csrf_verify();
        need('manager', 'admin');

        $decision = ($action === 'approve') ? 'approved' : 'rejected';
        ex("UPDATE leaves SET status=? WHERE id=?", [$decision, $lid]);

        flash("Leave application #" . $lid . " " . $decision, "info");
        redirect(url('/hrm'));
    }

    public function addPerf(): void {
        csrf_verify();
        need('manager', 'admin');
        $u = current_user();

        $targetUserId = (int)($_POST['user_id'] ?? 0);
        $period = trim($_POST['period'] ?? date('M Y'));
        $rating = (int)($_POST['rating'] ?? 5);
        $notes = trim($_POST['notes'] ?? 'Consistent collection performance');

        ex("INSERT INTO perf (user_id, period, rating, notes, by_name) VALUES (?, ?, ?, ?, ?)",
            [$targetUserId, $period, $rating, $notes, $u['name']]);

        flash("Performance evaluation recorded.", "success");
        redirect(url('/hrm'));
    }
}
