<?php
/**
 * SARVOOCCH Microcare Foundation - Loans, EMI Schedules & Collections
 */

if (!defined('SARVOOCCH_APP')) exit;

class LoanController {
    public function list(): void {
        need('loans');
        $u = current_user();

        $status = $_GET['status'] ?? 'active';
        $branch = $_GET['branch'] ?? '';

        $sql = "SELECT l.*, c.name as customer_name, c.phone, p.name as product_name " .
               "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE 1=1";
        $params = [];

        if (!empty($status)) {
            $sql .= " AND l.status = ?";
            $params[] = $status;
        }
        if (!empty($branch)) {
            $sql .= " AND l.branch = ?";
            $params[] = $branch;
        }
        if ($u['role'] === 'field_agent') {
            $sql .= " AND l.agent_id = ?";
            $params[] = (int)$u['id'];
        }

        $sql .= " ORDER BY l.id DESC LIMIT 100";
        $loans = q($sql, $params);

        view('loans/list', [
            'loans' => $loans,
            'selectedStatus' => $status,
            'selectedBranch' => $branch
        ]);
    }

    public function detail(int $lid): void {
        need('loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, c.dob, p.name as product_name " .
                  "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);

        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }

        $schedule = q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no ASC", [$lid]);
        $payments = q("SELECT * FROM payments WHERE loan_id=? ORDER BY id DESC", [$lid]);
        $settleQuote = Finance::settlementQuote($lid);
        [$nocEligible, $nocDate] = Finance::nocState($loan);

        view('loans/detail', [
            'l' => $loan,
            'schedule' => $schedule,
            'payments' => $payments,
            'settleQuote' => $settleQuote,
            'nocEligible' => $nocEligible,
            'nocDate' => $nocDate
        ]);
    }

    public function card(int $lid): void {
        need('loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, c.dob, p.name as product_name " .
                  "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);
        $schedule = q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no ASC", [$lid]);

        view('loans/card', [
            'l' => $loan,
            'schedule' => $schedule,
            'noLayout' => true
        ]);
    }

    public function nocPdf(int $lid): void {
        need('loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, c.aadhaar, p.name as product_name " .
                  "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);

        if (!$loan || $loan['status'] !== 'closed') {
            die("NOC is only issued for fully closed loans.");
        }

        view('loans/noc_print', [
            'l' => $loan,
            'noLayout' => true
        ]);
    }

    public function settleForm(int $lid): void {
        need('loans', 'payments');
        $loan = q("SELECT l.*, c.name as customer_name FROM loans l JOIN customers c ON l.customer_id=c.id WHERE l.id=?", [$lid], true);
        $quote = Finance::settlementQuote($lid);

        view('loans/settle', [
            'l' => $loan,
            'q' => $quote
        ]);
    }

    public function settlePost(int $lid): void {
        csrf_verify();
        need('loans', 'payments');
        $channel = $_POST['channel'] ?? 'CASH';
        $ref = trim($_POST['ref'] ?? '');

        Database::beginTransaction();
        try {
            $isSqlite = Database::getConnection()->getAttribute(PDO::ATTR_DRIVER_NAME) === 'sqlite';
            $loan = q("SELECT * FROM loans WHERE id=?" . ($isSqlite ? "" : " FOR UPDATE"), [$lid], true);
            if (!$loan || $loan['status'] === 'closed') {
                Database::rollBack();
                flash("Loan is already closed or invalid.", "warning");
                redirect(url('/loans/' . $lid));
            }

            $quote = Finance::settlementQuote($lid);
            if (!$quote) {
                Database::rollBack();
                flash("No outstanding balance on this loan.", "warning");
                redirect(url('/loans/' . $lid));
            }

            // Mark all remaining schedule entries as paid
            $today = date('Y-m-d');
            ex("UPDATE schedule SET paid=1, paid_on=? WHERE loan_id=? AND paid=0", [$today, $lid]);
            ex("INSERT INTO payments (loan_id, amount, channel, ref, at) VALUES (?, ?, ?, ?, NOW())",
                [$lid, $quote['total'], $channel, $ref ?: 'SETTLE' . strtoupper(bin2hex(random_bytes(4)))]);

            ex("UPDATE loans SET status='closed', closure_date=? WHERE id=?", [$today, $lid]);
            Database::commit();

            flash("Loan #" . $lid . " has been fully settled and closed. NOC will be available after 15 days.", "success");
            redirect(url('/loans/' . $lid));
        } catch (Exception $e) {
            if (Database::inTransaction()) {
                Database::rollBack();
            }
            flash("Settlement transaction failed: " . $e->getMessage(), "danger");
            redirect(url('/loans/' . $lid));
        }
    }

    public function payForm(int $lid): void {
        need('payments');
        $loan = q("SELECT l.*, c.name as customer_name FROM loans l JOIN customers c ON l.customer_id=c.id WHERE l.id=?", [$lid], true);
        $nextEmi = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no ASC LIMIT 1", [$lid], true);

        view('loans/pay', [
            'l' => $loan,
            'nextEmi' => $nextEmi
        ]);
    }

    public function payPost(int $lid): void {
        csrf_verify();
        need('payments');

        $schedId = (int)($_POST['schedule_id'] ?? 0);
        $channel = $_POST['channel'] ?? 'CASH';
        $ref = trim($_POST['ref'] ?? '');

        $payRef = Finance::recordPayment($lid, $schedId, $channel, $ref ?: null);
        if ($payRef) {
            flash("Payment of EMI successfully recorded. Transaction Ref: " . $payRef, "success");
        } else {
            flash("Unable to record payment (instalment already marked paid or invalid).", "danger");
        }

        redirect(url('/loans/' . $lid));
    }

    public function portal(): void {
        need('portal');
        $u = current_user();

        $cid = (int)($u['customer_id'] ?? 0);
        $customer = q("SELECT * FROM customers WHERE id=?", [$cid], true);
        $loans = q("SELECT l.*, p.name as product_name FROM loans l JOIN products p ON l.product_id=p.id WHERE l.customer_id=? ORDER BY l.id DESC", [$cid]);

        view('loans/portal', [
            'customer' => $customer,
            'loans' => $loans
        ]);
    }

    public function runAutopay(): void {
        http_response_code(501);
        flash("Automated eNACH clearing is disabled until NPCI payment gateway integration is live.", "danger");
        redirect(url('/loans'));
    }
}
