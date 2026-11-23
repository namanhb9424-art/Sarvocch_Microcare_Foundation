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
        if ($u['role'] !== 'admin') {
            $branch = $u['branch'] ?? '';
            $sql .= " AND l.branch = ?";
            $params[] = $branch;
        } elseif (!empty($branch)) {
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
        assert_branch_access($loan['branch']);

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
        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }
        assert_branch_access($loan['branch']);

        $schedule = q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no ASC", [$lid]);

        view('loans/card', [
            'l' => $loan,
            'schedule' => $schedule,
            'noLayout' => true
        ]);
    }

    public function nocPdf(int $lid): void {
        need('loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, c.aadhaar_last4, p.name as product_name " .
                  "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);

        if (!$loan || $loan['status'] !== 'closed') {
            die("NOC is only issued for fully closed loans.");
        }
        assert_branch_access($loan['branch']);

        view('loans/noc_print', [
            'l' => $loan,
            'noLayout' => true
        ]);
    }

    public function settleForm(int $lid): void {
        need('loans', 'payments');
        $loan = q("SELECT l.*, c.name as customer_name, l.branch FROM loans l JOIN customers c ON l.customer_id=c.id WHERE l.id=?", [$lid], true);
        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }
        assert_branch_access($loan['branch']);
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
            assert_branch_access($loan['branch']);

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
        $loan = q("SELECT l.*, c.name as customer_name, l.branch FROM loans l JOIN customers c ON l.customer_id=c.id WHERE l.id=?", [$lid], true);
        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }
        assert_branch_access($loan['branch']);
        $nextEmi = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no ASC LIMIT 1", [$lid], true);

        view('loans/pay', [
            'l' => $loan,
            'nextEmi' => $nextEmi
        ]);
    }

    public function payPost(int $lid): void {
        csrf_verify();
        need('payments');

        $loan = q("SELECT * FROM loans WHERE id=?", [$lid], true);
        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }
        assert_branch_access($loan['branch']);

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
        if ($customer) {
            assert_branch_access($customer['branch']);
        }
        $loans = q("SELECT l.*, p.name as product_name FROM loans l JOIN products p ON l.product_id=p.id WHERE l.customer_id=? ORDER BY l.id DESC", [$cid]);

        view('loans/portal', [
            'customer' => $customer,
            'loans' => $loans
        ]);
    }

    public function runAutopay(): void {
        need('payments', 'loans', 'dashboard');
        $today = date('Y-m-d');

        // Retrieve active mandates with installments due on or before today
        $dueInstallments = q(
            "SELECT s.id as schedule_id, s.loan_id, s.emi, s.due_date, m.bank, m.acct_last4, m.mtype, l.loan_no, c.name as customer_name " .
            "FROM schedule s " .
            "JOIN loans l ON s.loan_id = l.id " .
            "JOIN mandates m ON m.loan_id = l.id " .
            "JOIN customers c ON l.customer_id = c.id " .
            "WHERE s.paid = 0 AND s.due_date <= ? AND l.status = 'active' AND m.status = 'active' " .
            "ORDER BY s.due_date ASC",
            [$today]
        );

        if (empty($dueInstallments)) {
            flash("AutoPay Cycle: No pending dues for active eNACH mandates as of today ({$today}).", "info");
            redirect(url('/loans'));
            return;
        }

        $processed = 0;
        $totalCollected = 0.0;
        Database::beginTransaction();
        try {
            foreach ($dueInstallments as $item) {
                $ref = 'NACH' . strtoupper(bin2hex(random_bytes(4))) . $item['schedule_id'];
                $payRef = Finance::recordPayment((int)$item['loan_id'], (int)$item['schedule_id'], 'eNACH', $ref);
                if ($payRef) {
                    $processed++;
                    $totalCollected += (float)$item['emi'];
                }
            }
            Database::commit();
            flash("AutoPay Batch Completed: Successfully processed {$processed} installments via eNACH clearing totaling " . inr($totalCollected) . ".", "success");
        } catch (Exception $e) {
            if (Database::inTransaction()) {
                Database::rollBack();
            }
            flash("AutoPay Batch processing error: " . $e->getMessage(), "danger");
        }

        redirect(url('/loans'));
    }

    public function receiptPrint(int $lid, int $pid): void {
        need('payments', 'loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, p.name as product_name " .
                 "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);
        if (!$loan) {
            die("Loan not found");
        }
        assert_branch_access($loan['branch']);

        $payment = q("SELECT * FROM payments WHERE id=? AND loan_id=?", [$pid, $lid], true);
        if (!$payment) {
            die("Payment receipt not found");
        }

        $schedule = q("SELECT * FROM schedule WHERE id=?", [$payment['schedule_id']], true);
        $outstanding = q("SELECT COALESCE(SUM(balance),0) as bal FROM schedule WHERE loan_id=? AND paid=0", [$lid], true)['bal'] ?? 0;

        view('loans/receipt_print', [
            'l' => $loan,
            'p' => $payment,
            's' => $schedule,
            'outstanding' => (float)$outstanding,
            'noLayout' => true
        ]);
    }

    public function upiQrJson(int $lid): void {
        header('Content-Type: application/json; charset=utf-8');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone FROM loans l JOIN customers c ON l.customer_id=c.id WHERE l.id=?", [$lid], true);
        if (!$loan) {
            http_response_code(404);
            echo json_encode(['ok' => false, 'message' => 'Loan not found']);
            exit;
        }

        $nextEmi = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no ASC LIMIT 1", [$lid], true);
        $amount = (float)($_GET['amount'] ?? ($nextEmi ? $nextEmi['emi'] : $loan['emi']));
        $ref = 'SARV' . $lid . 'I' . ($nextEmi ? $nextEmi['no'] : '1');

        $upiIntent = PaymentGatewayService::buildUpiIntent($amount, $ref, 'EMI ' . $loan['loan_no']);
        $qrUrl = PaymentGatewayService::getQrCodeUrl($upiIntent, 300);

        echo json_encode([
            'ok' => true,
            'loan_id' => $lid,
            'loan_no' => $loan['loan_no'],
            'borrower' => $loan['customer_name'],
            'amount' => $amount,
            'upi_intent' => $upiIntent,
            'qr_url' => $qrUrl,
            'ref' => $ref
        ]);
        exit;
    }

    public function kfsPdf(int $lid): void {
        need('loans');
        $loan = q("SELECT l.*, c.name as customer_name, c.phone, c.address, c.aadhaar_last4, c.pan, c.bank_account, c.bank_ifsc, p.name as product_name, p.fee_pct, p.method " .
                  "FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id WHERE l.id=?", [$lid], true);
        if (!$loan) {
            flash("Loan record not found.", "danger");
            redirect(url('/loans'));
        }
        assert_branch_access($loan['branch']);

        $schedule = q("SELECT * FROM schedule WHERE loan_id=? ORDER BY no ASC", [$lid]);

        $principal = (float)$loan['principal'];
        $feePct = (float)($loan['fee_pct'] ?? 1.50);
        $procFee = round($principal * ($feePct / 100), 2);
        $cgst = round($procFee * 0.09, 2);
        $sgst = round($procFee * 0.09, 2);
        $gstTotal = $cgst + $sgst;
        $upfrontDeductions = $procFee + $gstTotal;
        $netDisbursed = $principal - $upfrontDeductions;
        $totalInterest = (float)array_sum(array_column($schedule, 'interest'));
        $totalRepay = $principal + $totalInterest;
        $totalCostOfCredit = $totalInterest + $upfrontDeductions;
        $tenureYears = ((int)$loan['tenure']) / 12.0;
        $apr = ($tenureYears > 0 && $netDisbursed > 0) ? round((($totalCostOfCredit / $netDisbursed) / $tenureYears) * 100, 2) : (float)$loan['rate'];

        view('loans/kfs_print', [
            'l' => $loan,
            'schedule' => $schedule,
            'principal' => $principal,
            'feePct' => $feePct,
            'procFee' => $procFee,
            'cgst' => $cgst,
            'sgst' => $sgst,
            'gstTotal' => $gstTotal,
            'upfrontDeductions' => $upfrontDeductions,
            'netDisbursed' => $netDisbursed,
            'totalInterest' => $totalInterest,
            'totalRepay' => $totalRepay,
            'totalCostOfCredit' => $totalCostOfCredit,
            'apr' => $apr,
            'noLayout' => true
        ]);
    }
}

