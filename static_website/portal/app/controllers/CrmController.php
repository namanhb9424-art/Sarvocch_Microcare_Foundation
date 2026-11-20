<?php
/**
 * SARVOOCCH Microcare Foundation - CRM & Customer Lead Management
 */

if (!defined('SARVOOCCH_APP')) exit;

class CrmController {
    public function list(): void {
        need('crm');
        $u = current_user();

        $branch = $_GET['branch'] ?? '';
        $stage = $_GET['stage'] ?? '';
        $qSearch = trim($_GET['q'] ?? '');

        if ($u['role'] === 'field_agent') {
            $agentId = (int)$u['id'];
        } else {
            $agentId = !empty($_GET['agent']) ? (int)$_GET['agent'] : null;
        }

        $sql = "SELECT c.*, u.name as agent_name FROM customers c LEFT JOIN users u ON c.agent_id=u.id WHERE 1=1";
        $params = [];

        if ($u['role'] !== 'admin') {
            $branch = $u['branch'] ?? '';
            $sql .= " AND c.branch = ?";
            $params[] = $branch;
        } elseif (!empty($branch)) {
            $sql .= " AND c.branch = ?";
            $params[] = $branch;
        }
        if (!empty($stage)) {
            $sql .= " AND c.stage = ?";
            $params[] = $stage;
        }
        if ($agentId !== null) {
            $sql .= " AND c.agent_id = ?";
            $params[] = $agentId;
        }
        if (!empty($qSearch)) {
            $digitsSearch = preg_replace('/\D/', '', $qSearch);
            if (strlen($digitsSearch) === 12) {
                $searchHash = hash_hmac('sha256', $digitsSearch, AADHAAR_HMAC_KEY);
                $sql .= " AND (c.name LIKE ? OR c.phone LIKE ? OR c.aadhaar_hash = ?)";
                $params[] = "%$qSearch%";
                $params[] = "%$qSearch%";
                $params[] = $searchHash;
            } else {
                $sql .= " AND (c.name LIKE ? OR c.phone LIKE ? OR c.aadhaar_last4 LIKE ?)";
                $params[] = "%$qSearch%";
                $params[] = "%$qSearch%";
                $params[] = "%$qSearch%";
            }
        }

        $sql .= " ORDER BY c.id DESC LIMIT 100";
        $customers = q($sql, $params);

        $agents = ($u['role'] !== 'admin')
            ? q("SELECT id, name, branch FROM users WHERE role='field_agent' AND branch=? ORDER BY name", [$u['branch'] ?? ''])
            : q("SELECT id, name, branch FROM users WHERE role='field_agent' ORDER BY name");

        view('crm/list', [
            'customers' => $customers,
            'agents' => $agents,
            'filters' => [
                'branch' => $branch,
                'stage' => $stage,
                'agent' => (string)($agentId ?? ''),
                'q' => $qSearch
            ]
        ]);
    }

    public function create(): void {
        csrf_verify();
        need('crm');
        $u = current_user();

        $name = trim($_POST['name'] ?? '');
        $phone = trim($_POST['phone'] ?? '');
        $dob = $_POST['dob'] ?? null;
        $address = trim($_POST['address'] ?? '');
        $branch = ($u['role'] !== 'admin') ? ($u['branch'] ?? 'Bhopal Head Office') : ($_POST['branch'] ?? ($u['branch'] ?? 'Bhopal Head Office'));
        $agentId = $u['role'] === 'field_agent' ? (int)$u['id'] : (!empty($_POST['agent_id']) ? (int)$_POST['agent_id'] : null);

        if (empty($name) || empty($phone)) {
            flash("Customer Name and Mobile Number are required.", "danger");
            redirect(url('/crm'));
        }

        $cid = ex(
            "INSERT INTO customers (name, phone, dob, address, branch, agent_id, stage, created) VALUES (?, ?, ?, ?, ?, ?, 'lead', NOW())",
            [$name, $phone, $dob ?: null, $address, $branch, $agentId]
        );

        ex("INSERT INTO comm_logs (customer_id, channel, note, by_name, at) VALUES (?, 'System', 'Customer lead registered in portal', ?, NOW())",
            [$cid, $u['name']]);

        flash("Customer " . htmlspecialchars($name) . " created successfully.", "success");
        redirect(url('/crm/' . $cid));
    }

    public function detail(int $cid): void {
        need('crm');
        $customer = q("SELECT c.*, u.name as agent_name FROM customers c LEFT JOIN users u ON c.agent_id=u.id WHERE c.id=?", [$cid], true);
        if (!$customer) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($customer['branch']);

        $kyc = q("SELECT * FROM kyc_forms WHERE customer_id=?", [$cid], true);
        $applications = q("SELECT a.*, p.name as product_name FROM applications a JOIN products p ON a.product_id=p.id WHERE a.customer_id=? ORDER BY a.id DESC", [$cid]);
        $loans = q("SELECT l.*, p.name as product_name FROM loans l JOIN products p ON l.product_id=p.id WHERE l.customer_id=? ORDER BY l.id DESC", [$cid]);
        $commLogs = q("SELECT * FROM comm_logs WHERE customer_id=? ORDER BY id DESC", [$cid]);
        $portalUser = q("SELECT * FROM users WHERE customer_id=?", [$cid], true);

        view('crm/detail', [
            'c' => $customer,
            'kyc' => $kyc,
            'applications' => $applications,
            'loans' => $loans,
            'logs' => $commLogs,
            'portalUser' => $portalUser
        ]);
    }

    public function addLog(int $cid): void {
        csrf_verify();
        need('crm');
        $u = current_user();

        $c = q("SELECT branch FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);

        $channel = $_POST['channel'] ?? 'Call';
        $note = trim($_POST['note'] ?? '');

        if (!empty($note)) {
            ex("INSERT INTO comm_logs (customer_id, channel, note, by_name, at) VALUES (?, ?, ?, ?, NOW())",
                [$cid, $channel, $note, $u['name']]);
            flash("Interaction logged successfully.", "success");
        }

        redirect(url('/crm/' . $cid));
    }

    public function updateStage(int $cid): void {
        csrf_verify();
        need('crm');

        $c = q("SELECT branch FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);

        $stage = $_POST['stage'] ?? 'lead';
        ex("UPDATE customers SET stage=? WHERE id=?", [$stage, $cid]);
        flash("Customer stage updated to " . htmlspecialchars($stage), "info");
        redirect(url('/crm/' . $cid));
    }

    public function createPortalLogin(int $cid): void {
        csrf_verify();
        need('crm');
        $u = current_user();

        $c = q("SELECT * FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);

        $cleanPhone = preg_replace('/\D/', '', $c['phone'] ?? '');
        $uname = 'c_' . ($cleanPhone ? substr($cleanPhone, -6) : $cid);
        $tempPw = 'Sarvoocch@' . rand(1000, 9999);
        $hash = Auth::hashPassword($tempPw);

        $existing = q("SELECT id FROM users WHERE customer_id=?", [$cid], true);
        if ($existing) {
            ex("UPDATE users SET pw=?, must_change=1 WHERE id=?", [$hash, $existing['id']]);
        } else {
            ex("INSERT INTO users (username, pw, name, role, branch, phone, customer_id, must_change) VALUES (?, ?, ?, 'customer', ?, ?, ?, 1)",
                [$uname, $hash, $c['name'], $c['branch'], $c['phone'], $cid]);
        }

        $_SESSION['temp_cred_' . $cid] = [
            'username' => $uname,
            'password' => $tempPw
        ];

        flash("Customer portal access created. Print the login credentials slip now.", "success");
        redirect(url('/crm/' . $cid . '/login-slip'));
    }

    public function loginSlip(int $cid): void {
        need('crm');
        $c = q("SELECT * FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/crm'));
        }
        assert_branch_access($c['branch']);

        $u = q("SELECT * FROM users WHERE customer_id=?", [$cid], true);
        $temp = $_SESSION['temp_cred_' . $cid] ?? null;

        view('crm/login_slip', [
            'c' => $c,
            'u' => $u,
            'temp' => $temp,
            'noLayout' => true
        ]);
    }
}
