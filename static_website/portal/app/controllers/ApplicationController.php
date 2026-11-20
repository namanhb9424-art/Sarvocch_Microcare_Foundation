<?php
/**
 * SARVOOCCH Microcare Foundation - Loan Application & Approval Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class ApplicationController {
    public function list(): void {
        need('applications');
        $u = current_user();

        $status = $_GET['status'] ?? '';
        $branch = $_GET['branch'] ?? '';

        $sql = "SELECT a.*, c.name as customer_name, c.phone, p.name as product_name " .
               "FROM applications a " .
               "JOIN customers c ON a.customer_id=c.id " .
               "JOIN products p ON a.product_id=p.id WHERE 1=1";
        $params = [];

        if (!empty($status)) {
            $sql .= " AND a.status = ?";
            $params[] = $status;
        }
        if ($u['role'] !== 'admin') {
            $branch = $u['branch'] ?? '';
            $sql .= " AND a.branch = ?";
            $params[] = $branch;
        } elseif (!empty($branch)) {
            $sql .= " AND a.branch = ?";
            $params[] = $branch;
        }
        if ($u['role'] === 'field_agent') {
            $sql .= " AND a.agent_id = ?";
            $params[] = (int)$u['id'];
        }

        $sql .= " ORDER BY a.id DESC LIMIT 100";
        $applications = q($sql, $params);

        view('applications/list', [
            'applications' => $applications,
            'selectedStatus' => $status,
            'selectedBranch' => $branch
        ]);
    }

    public function detail(int $aid): void {
        need('applications');
        $app = q("SELECT a.*, c.name as customer_name, c.phone as customer_phone, c.dob as customer_dob, " .
                 "c.address as customer_address, c.aadhaar, c.pan, p.name as product_name, p.method as product_method " .
                 "FROM applications a " .
                 "JOIN customers c ON a.customer_id=c.id " .
                 "JOIN products p ON a.product_id=p.id WHERE a.id=?", [$aid], true);

        if (!$app) {
            flash("Application not found.", "danger");
            redirect(url('/applications'));
        }
        assert_branch_access($app['branch']);

        $extra = q("SELECT * FROM app_extra WHERE application_id=?", [$aid], true);
        $approvals = q("SELECT * FROM approvals WHERE application_id=? ORDER BY id ASC", [$aid]);
        $loan = q("SELECT * FROM loans WHERE application_id=?", [$aid], true);

        // Calculate EMI preview
        $previewEmi = Finance::emiCalc((float)$app['amount'], (float)$app['rate'], (int)$app['tenure'], $app['product_method']);
        $feeSplit = Finance::feeSplit((float)$app['amount'], 1.5);

        view('applications/detail', [
            'a' => $app,
            'extra' => $extra,
            'approvals' => $approvals,
            'loan' => $loan,
            'previewEmi' => $previewEmi,
            'feeSplit' => $feeSplit
        ]);
    }

    public function action(int $aid): void {
        csrf_verify();
        need('approve', 'disburse');
        $u = current_user();

        $action = $_POST['action'] ?? '';
        $remarks = trim($_POST['remarks'] ?? '');

        $app = q("SELECT * FROM applications WHERE id=?", [$aid], true);
        if (!$app) {
            flash("Application not found.", "danger");
            redirect(url('/applications'));
        }
        assert_branch_access($app['branch']);

        if ($action === 'approve') {
            need('approve');
            ex("UPDATE applications SET status='approved' WHERE id=?", [$aid]);
            ex("INSERT INTO approvals (application_id, stage, by_user, by_role, amount, remarks, at) VALUES (?, 'Approved', ?, ?, ?, ?, NOW())",
                [$aid, $u['name'], $u['role'], $app['amount'], $remarks]);
            flash("Application #" . $aid . " approved successfully.", "success");
        } elseif ($action === 'reject') {
            need('approve');
            ex("UPDATE applications SET status='rejected' WHERE id=?", [$aid]);
            ex("INSERT INTO approvals (application_id, stage, by_user, by_role, amount, remarks, at) VALUES (?, 'Rejected', ?, ?, ?, ?, NOW())",
                [$aid, $u['name'], $u['role'], 0, $remarks]);
            flash("Application #" . $aid . " rejected.", "warning");
        } elseif ($action === 'disburse') {
            need('disburse');
            if ($app['status'] !== 'approved') {
                flash("Application must be in approved status before disbursement.", "danger");
                redirect(url('/applications/' . $aid));
            }
            Database::beginTransaction();
            try {
                $lid = Finance::createLoan($aid);
                ex("UPDATE applications SET status='disbursed' WHERE id=?", [$aid]);
                ex("INSERT INTO approvals (application_id, stage, by_user, by_role, amount, remarks, at) VALUES (?, 'Disbursed', ?, ?, ?, ?, NOW())",
                    [$aid, $u['name'], $u['role'], $app['amount'], $remarks ?: 'Loan disbursed into customer account']);
                Database::commit();
                flash("Loan #" . $lid . " created and disbursed successfully!", "success");
                redirect(url('/loans/' . $lid));
            } catch (Exception $e) {
                if (Database::inTransaction()) {
                    Database::rollBack();
                }
                flash("Disbursement failed: " . $e->getMessage(), "danger");
                redirect(url('/applications/' . $aid));
            }
        }

        redirect(url('/applications/' . $aid));
    }

    public function applyForm(): void {
        need('apply');
        $u = current_user();
        $products = q("SELECT * FROM products WHERE active=1 ORDER BY id");
        $customers = ($u['role'] !== 'admin')
            ? q("SELECT id, name, phone, branch FROM customers WHERE branch=? ORDER BY name LIMIT 200", [$u['branch'] ?? ''])
            : q("SELECT id, name, phone, branch FROM customers ORDER BY name LIMIT 200");
        view('applications/apply', [
            'products' => $products,
            'customers' => $customers
        ]);
    }

    public function applyPost(): void {
        csrf_verify();
        need('apply');
        $u = current_user();

        $cid = (int)($_POST['customer_id'] ?? 0);
        $pid = (int)($_POST['product_id'] ?? 0);
        $amount = (float)($_POST['amount'] ?? 0);
        $tenure = (int)($_POST['tenure'] ?? 12);
        $purpose = trim($_POST['purpose'] ?? 'Microenterprise Expansion');
        $income = (float)($_POST['income'] ?? 0);
        $occupation = trim($_POST['occupation'] ?? '');
        $employer = trim($_POST['employer'] ?? '');
        $coName = trim($_POST['co_name'] ?? '');
        $coPhone = trim($_POST['co_phone'] ?? '');
        $coRelation = trim($_POST['co_relation'] ?? 'Husband');
        $coIncome = (float)($_POST['co_income'] ?? 0);

        $c = q("SELECT branch FROM customers WHERE id=?", [$cid], true);
        if (!$c) {
            flash("Customer not found.", "danger");
            redirect(url('/apply'));
        }
        assert_branch_access($c['branch']);

        $branch = ($u['role'] !== 'admin') ? ($u['branch'] ?? 'Bhopal Head Office') : ($_POST['branch'] ?? ($u['branch'] ?? 'Bhopal Head Office'));

        $p = q("SELECT * FROM products WHERE id=?", [$pid], true);
        if (!$p) {
            flash("Invalid loan product selected.", "danger");
            redirect(url('/apply'));
        }

        $aid = ex(
            "INSERT INTO applications (customer_id, product_id, amount, tenure, rate, purpose, income, " .
            "occupation, employer, co_name, co_phone, co_relation, co_income, status, agent_id, branch, created) " .
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', ?, ?, NOW())",
            [
                $cid, $pid, $amount, $tenure, $p['rate'], $purpose, $income,
                $occupation, $employer, $coName, $coPhone, $coRelation, $coIncome,
                $u['id'], $branch
            ]
        );

        // App Extra details
        ex("INSERT INTO app_extra (application_id, inc_agri, inc_business, inc_job, exp_basic, exp_emi, income_total, net_saving, declaration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)",
            [$aid, $income * 0.4, $income * 0.6, 0, $income * 0.4, 0, $income, $income * 0.6]);

        ex("INSERT INTO approvals (application_id, stage, by_user, by_role, amount, remarks, at) VALUES (?, 'Submitted', ?, ?, ?, 'Application submitted via portal', NOW())",
            [$aid, $u['name'], $u['role'], $amount]);

        flash("Loan application #" . $aid . " registered successfully.", "success");
        redirect(url('/applications/' . $aid));
    }

    public function sanctionPdf(int $aid): void {
        need('applications', 'loans');
        $app = q("SELECT a.*, c.name as customer_name, c.dob as customer_dob, c.phone, c.address, p.name as product_name " .
                 "FROM applications a JOIN customers c ON a.customer_id=c.id JOIN products p ON a.product_id=p.id WHERE a.id=?", [$aid], true);
        if (!$app) {
            die("Application not found");
        }
        assert_branch_access($app['branch']);

        // Return printable HTML view which can be saved directly as PDF or printed
        view('applications/sanction_print', [
            'a' => $app,
            'noLayout' => true
        ]);
    }
}
