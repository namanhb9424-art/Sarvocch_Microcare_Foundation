<?php
/**
 * SARVOOCCH Microcare Foundation - Grievance Redressal Officer (GRO) Controller
 * Enforces RBI Fair Practices Code for customer complaints and timely resolution
 */

if (!defined('SARVOOCCH_APP')) exit;

class GrievanceController {
    public function index(): void {
        need('crm', 'dashboard', '*');
        $status = $_GET['status'] ?? '';
        $branch = $_GET['branch'] ?? '';

        $w = [];
        $args = [];
        if ($status) {
            $w[] = "status = ?";
            $args[] = $status;
        }
        if ($branch) {
            $w[] = "branch = ?";
            $args[] = $branch;
        }

        $u = current_user();
        if ($u && $u['role'] === 'manager') {
            $w[] = "branch = ?";
            $args[] = $u['branch'];
        }

        $whereClause = !empty($w) ? "WHERE " . implode(" AND ", $w) : "";
        $grievances = q("SELECT * FROM grievances {$whereClause} ORDER BY id DESC LIMIT 100", $args);
        $branches = q("SELECT name FROM branches ORDER BY name");

        view('grievances/index', [
            'grievances' => $grievances,
            'branches' => $branches,
            'status' => $status,
            'selected_branch' => $branch
        ]);
    }

    public function detail(int $id): void {
        need('crm', 'dashboard', '*');
        $g = q("SELECT * FROM grievances WHERE id=?", [$id], true);
        if (!$g) {
            flash("Grievance ticket not found.", "danger");
            redirect(url('/grievances'));
        }

        $staff = q("SELECT id, name FROM users WHERE role IN ('manager', 'underwriter', 'field_agent') ORDER BY name");
        view('grievances/detail', [
            'grievance' => $g,
            'staff' => $staff
        ]);
    }

    public function update(int $id): void {
        csrf_verify();
        need('crm', 'dashboard', '*');

        $status = $_POST['status'] ?? 'open';
        $assignedTo = (int)($_POST['assigned_to'] ?? 0) ?: null;
        $notes = trim($_POST['resolution_notes'] ?? '');

        $resolvedAt = ($status === 'resolved') ? date('Y-m-d H:i:s') : null;

        ex("UPDATE grievances SET status=?, assigned_to=?, resolution_notes=?, resolved_at=? WHERE id=?",
            [$status, $assignedTo, $notes, $resolvedAt, $id]);

        $g = q("SELECT * FROM grievances WHERE id=?", [$id], true);
        if ($g && !empty($g['phone'])) {
            $msg = "Dear {$g['name']}, your SARVOOCCH grievance (#{$g['ticket_no']}) status is now: " . strtoupper($status) . ".";
            if ($notes) {
                $msg .= " Notes: {$notes}";
            }
            NotificationService::sendWhatsApp($g['phone'], $msg);
        }

        flash("Grievance #{$id} updated successfully.", "success");
        redirect(url('/grievances/' . $id));
    }
}
