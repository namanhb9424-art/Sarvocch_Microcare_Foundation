<?php
/**
 * SARVOOCCH Microcare Foundation - Field Operations Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class FieldController {
    public function index(): void {
        need('field');
        $u = current_user();

        $today = date('Y-m-d');
        $officerId = $u['role'] === 'field_agent' ? (int)$u['id'] : (!empty($_GET['agent']) ? (int)$_GET['agent'] : null);

        $sql = "SELECT t.*, c.name as customer_name, c.phone, c.address " .
               "FROM tasks t LEFT JOIN customers c ON t.customer_id=c.id WHERE 1=1";
        $params = [];

        if ($officerId !== null) {
            $sql .= " AND t.officer_id = ?";
            $params[] = $officerId;
        }

        $sql .= " ORDER BY t.due_date ASC, t.id DESC LIMIT 100";
        $tasks = q($sql, $params);

        $clusters = cluster_tasks($tasks, 3.0);
        $agents = q("SELECT id, name, branch FROM users WHERE role='field_agent' ORDER BY name");

        // Attendance status for today
        $att = q("SELECT * FROM attendance WHERE user_id=? AND day=?", [$u['id'], $today], true);

        view('field/index', [
            'tasks' => $tasks,
            'clusters' => $clusters,
            'agents' => $agents,
            'att' => $att,
            'selectedOfficer' => (string)($officerId ?? '')
        ]);
    }

    public function assign(): void {
        csrf_verify();
        need('field', 'manager', 'admin');

        $title = trim($_POST['title'] ?? 'Field Collection Visit');
        $cid = !empty($_POST['customer_id']) ? (int)$_POST['customer_id'] : null;
        $officerId = (int)($_POST['officer_id'] ?? 0);
        $dueDate = $_POST['due_date'] ?: date('Y-m-d');
        $notes = trim($_POST['notes'] ?? '');

        ex("INSERT INTO tasks (title, customer_id, officer_id, due_date, notes, status) VALUES (?, ?, ?, ?, ?, 'open')",
            [$title, $cid, $officerId, $dueDate, $notes]);

        flash("Task assigned successfully to field officer.", "success");
        redirect(url('/field'));
    }

    public function taskDone(int $tid): void {
        csrf_verify();
        need('field');
        $collected = (float)($_POST['collected'] ?? 0);
        $notes = trim($_POST['notes'] ?? '');

        ex("UPDATE tasks SET status='done', collected=?, notes=?, done_at=NOW() WHERE id=?",
            [$collected, $notes, $tid]);

        flash("Task marked completed. Collected: " . inr($collected), "success");
        redirect(url('/field'));
    }
}
