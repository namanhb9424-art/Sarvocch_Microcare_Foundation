<?php
/**
 * SARVOOCCH Microcare Foundation - Branch Operations & Geography Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class BranchController {
    public function list(): void {
        need('branches', 'admin');
        $branches = q("SELECT b.*, " .
                      "(SELECT COUNT(*) FROM users u WHERE u.branch=b.name) as staff_count, " .
                      "(SELECT COUNT(*) FROM loans l WHERE l.branch=b.name AND l.status='active') as active_loans " .
                      "FROM branches b ORDER BY b.id ASC");

        view('branches/list', ['branches' => $branches]);
    }

    public function create(): void {
        csrf_verify();
        need('branches', 'admin');

        $name = trim($_POST['name'] ?? '');
        $code = strtoupper(trim($_POST['code'] ?? ''));
        $address = trim($_POST['address'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $head = trim($_POST['head_name'] ?? '');
        $lat = !empty($_POST['lat']) ? (float)$_POST['lat'] : null;
        $lng = !empty($_POST['lng']) ? (float)$_POST['lng'] : null;
        $radius = (int)($_POST['radius_m'] ?? 2000);

        if (empty($name) || empty($code)) {
            flash("Branch name and code are required.", "danger");
            redirect(url('/branches'));
        }

        ex("INSERT INTO branches (name, code, address, phone, head_name, lat, lng, radius_m, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)",
            [$name, $code, $address, $phone, $head, $lat, $lng, $radius]);

        Database::refreshConfig();
        flash("Branch " . htmlspecialchars($name) . " added successfully.", "success");
        redirect(url('/branches'));
    }

    public function details(int $bid): void {
        need('branches', 'admin');
        $branch = q("SELECT * FROM branches WHERE id=?", [$bid], true);
        if (!$branch) {
            flash("Branch not found.", "danger");
            redirect(url('/branches'));
        }

        $staff = q("SELECT * FROM users WHERE branch=? ORDER BY name", [$branch['name']]);
        $loans = q("SELECT l.*, c.name as customer_name, p.name as product_name FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.branch=? ORDER BY l.id DESC LIMIT 50", [$branch['name']]);

        view('branches/detail', [
            'b' => $branch,
            'staff' => $staff,
            'loans' => $loans
        ]);
    }
}
