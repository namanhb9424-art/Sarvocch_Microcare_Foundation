<?php
/**
 * SARVOOCCH Microcare Foundation - Pre-GRT (Joint Liability Group Verification)
 */

if (!defined('SARVOOCCH_APP')) exit;

class PreGrtController {
    public function list(): void {
        need('pregrt');
        $u = current_user();

        $sql = "SELECT p.*, COUNT(m.id) as member_count " .
               "FROM pregrt p LEFT JOIN pregrt_members m ON p.id=m.pregrt_id WHERE 1=1";
        $params = [];

        if ($u['role'] === 'field_agent') {
            $sql .= " AND p.agent_id = ?";
            $params[] = (int)$u['id'];
        } elseif ($u['role'] !== 'admin') {
            $sql .= " AND p.branch = ?";
            $params[] = $u['branch'] ?? '';
        } elseif (!empty($_GET['branch'])) {
            $sql .= " AND p.branch = ?";
            $params[] = $_GET['branch'];
        }

        $sql .= " GROUP BY p.id ORDER BY p.id DESC";
        $groups = q($sql, $params);

        view('pregrt/list', ['groups' => $groups]);
    }

    public function newForm(): void {
        need('pregrt');
        view('pregrt/form', ['group' => null, 'members' => []]);
    }

    public function create(): void {
        csrf_verify();
        need('pregrt');
        $u = current_user();

        $branch = ($u['role'] !== 'admin') ? ($u['branch'] ?? 'Pipariya Branch') : ($_POST['branch'] ?? ($u['branch'] ?? 'Pipariya Branch'));
        $centerNo = trim($_POST['center_no'] ?? '');
        $groupNo = trim($_POST['group_no'] ?? '');
        $village = trim($_POST['village'] ?? '');
        $district = trim($_POST['district'] ?? '');
        $formDate = $_POST['form_date'] ?: date('Y-m-d');
        $psoName = trim($_POST['pso_name'] ?? $u['name']);
        $psoEmpid = trim($_POST['pso_empid'] ?? 'EMP001');
        $bmName = trim($_POST['bm_name'] ?? '');
        $bmEmpid = trim($_POST['bm_empid'] ?? '');
        $notes = trim($_POST['notes'] ?? '');

        $pid = ex(
            "INSERT INTO pregrt (branch, center_no, group_no, village, district, form_date, " .
            "pso_name, pso_empid, bm_name, bm_empid, notes, agent_id, status, created_at) " .
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', NOW())",
            [$branch, $centerNo, $groupNo, $village, $district, $formDate, $psoName, $psoEmpid, $bmName, $bmEmpid, $notes, $u['id']]
        );

        flash("Pre-GRT Group #" . $pid . " created. Now add group member profiles.", "success");
        redirect(url('/pregrt/' . $pid));
    }

    public function detail(int $pid): void {
        need('pregrt');
        $group = q("SELECT * FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            flash("Pre-GRT group record not found.", "danger");
            redirect(url('/pregrt'));
        }
        assert_branch_access($group['branch']);
        $members = q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno ASC", [$pid]);

        view('pregrt/form', [
            'group' => $group,
            'members' => $members
        ]);
    }

    public function update(int $pid): void {
        csrf_verify();
        need('pregrt');

        $group = q("SELECT branch FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            flash("Pre-GRT group record not found.", "danger");
            redirect(url('/pregrt'));
        }
        assert_branch_access($group['branch']);

        $action = $_POST['action'] ?? 'save_members';

        if ($action === 'add_member') {
            $name = trim($_POST['m_name'] ?? '');
            $husband = trim($_POST['m_husband'] ?? '');
            $age = (int)($_POST['m_age'] ?? 25);
            $voter = trim($_POST['m_voter'] ?? '');
            $aadhaar4 = substr(preg_replace('/\D/', '', $_POST['m_aadhaar4'] ?? ''), -4);
            $income = (float)($_POST['m_income'] ?? 0);
            $loanAmt = (float)($_POST['m_amount'] ?? 30000);
            $purpose = trim($_POST['m_purpose'] ?? 'Livestock / Dairy');

            $countRow = q("SELECT COUNT(*) as c FROM pregrt_members WHERE pregrt_id=?", [$pid], true);
            $sno = (int)($countRow['c'] ?? 0) + 1;

            ex(
                "INSERT INTO pregrt_members (pregrt_id, sno, name, husband_name, age, voter_id, " .
                "aadhaar4, annual_income, loan_amount, purpose, c_meeting, c_joint, c_fee, c_rate, c_insurance, c_company, c_group) " .
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, 1, 1, 1, 1, 1)",
                [$pid, $sno, $name, $husband, $age, $voter, $aadhaar4, $income, $loanAmt, $purpose]
            );

            flash("Member " . htmlspecialchars($name) . " added to group.", "success");
        }

        redirect(url('/pregrt/' . $pid));
    }

    public function review(int $pid): void {
        csrf_verify();
        need('manager', 'underwriter', 'admin');
        $u = current_user();

        $group = q("SELECT branch FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            flash("Pre-GRT group record not found.", "danger");
            redirect(url('/pregrt'));
        }
        assert_branch_access($group['branch']);

        $decision = $_POST['decision'] ?? 'verified';
        $remarks = trim($_POST['review_remarks'] ?? '');

        ex("UPDATE pregrt SET status=?, verified_by=?, verified_on=NOW(), review_remarks=? WHERE id=?",
            [$decision, $u['name'], $remarks, $pid]);

        flash("Pre-GRT Group #" . $pid . " review marked as " . $decision, "info");
        redirect(url('/pregrt/' . $pid));
    }

    public function printDoc(int $pid): void {
        need('pregrt');
        $group = q("SELECT * FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            die("Pre-GRT group not found");
        }
        assert_branch_access($group['branch']);
        $members = q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno ASC", [$pid]);

        view('pregrt/print', [
            'g' => $group,
            'members' => $members,
            'noLayout' => true
        ]);
    }

    public function groupApplyForm(int $pid): void {
        need('apply');
        $group = q("SELECT * FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            flash("Pre-GRT group record not found.", "danger");
            redirect(url('/pregrt'));
        }
        assert_branch_access($group['branch']);
        $members = q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno ASC", [$pid]);
        $products = q("SELECT * FROM products WHERE active=1 ORDER BY id");

        view('pregrt/group_apply', [
            'g' => $group,
            'members' => $members,
            'products' => $products
        ]);
    }

    public function groupApplyPost(int $pid): void {
        csrf_verify();
        need('apply');
        $u = current_user();

        $group = q("SELECT * FROM pregrt WHERE id=?", [$pid], true);
        if (!$group) {
            flash("Pre-GRT group record not found.", "danger");
            redirect(url('/pregrt'));
        }
        assert_branch_access($group['branch']);
        $members = q("SELECT * FROM pregrt_members WHERE pregrt_id=? ORDER BY sno ASC", [$pid]);
        $productId = (int)($_POST['product_id'] ?? 1);
        $p = q("SELECT * FROM products WHERE id=?", [$productId], true);

        $createdCount = 0;
        foreach ($members as $m) {
            // Find or create customer
            $phone = '98' . rand(10000000, 99999999);
            $cid = ex("INSERT INTO customers (name, phone, address, branch, agent_id, stage, created) VALUES (?, ?, ?, ?, ?, 'in_verification', NOW())",
                [$m['name'], $phone, $group['village'] . ', ' . $group['district'], $group['branch'], $u['id']]);

            // Create Application
            $aid = ex(
                "INSERT INTO applications (customer_id, product_id, amount, tenure, rate, purpose, income, co_name, status, agent_id, branch, created) " .
                "VALUES (?, ?, ?, 12, ?, ?, ?, ?, 'submitted', ?, ?, NOW())",
                [$cid, $productId, $m['loan_amount'], $p['rate'], $m['purpose'], $m['annual_income'] / 12, $m['husband_name'], $u['id'], $group['branch']]
            );

            ex("UPDATE pregrt_members SET customer_id=? WHERE id=?", [$cid, $m['id']]);
            $createdCount++;
        }

        flash("Successfully generated " . $createdCount . " loan applications from Pre-GRT Group #" . $pid, "success");
        redirect(url('/applications'));
    }
}
