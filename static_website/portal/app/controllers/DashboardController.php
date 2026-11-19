<?php
/**
 * SARVOOCCH Microcare Foundation - Dashboard Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class DashboardController {
    public function index(): void {
        need('dashboard');
        $u = current_user();

        // Branch filter for manager / admin
        $branch = $_GET['branch'] ?? '';
        if ($u['role'] === 'manager' && !empty($u['branch'])) {
            $branch = $u['branch'];
        }

        $branchSql = "";
        $params = [];
        if (!empty($branch)) {
            $branchSql = " WHERE branch = ? ";
            $params[] = $branch;
        }

        // 1. KPI Counts
        $totalBorrowers = (int)(q("SELECT COUNT(*) as c FROM customers" . $branchSql, $params, true)['c'] ?? 0);
        $activeLoans = (int)(q("SELECT COUNT(*) as c FROM loans " . ($branchSql ? $branchSql . " AND status='active'" : "WHERE status='active'"), $params, true)['c'] ?? 0);
        
        $disbursed = (float)(q("SELECT COALESCE(SUM(principal),0) as s FROM loans" . $branchSql, $params, true)['s'] ?? 0);
        
        $collectedRow = q("SELECT COALESCE(SUM(amount),0) as s FROM payments WHERE loan_id IN (SELECT id FROM loans" . $branchSql . ")", $params, true);
        $totalCollected = (float)($collectedRow['s'] ?? 0);

        // Outstanding principal in active loans
        $outstandingRow = q("SELECT COALESCE(SUM(balance),0) as s FROM schedule WHERE paid=0 AND loan_id IN (SELECT id FROM loans WHERE status='active'" . ($branch ? " AND branch=?" : "") . ")", $branch ? [$branch] : [], true);
        $totalOutstanding = (float)($outstandingRow['s'] ?? 0);

        // Pending applications
        $pendingApps = (int)(q("SELECT COUNT(*) as c FROM applications WHERE status IN ('submitted','pregrt_passed')" . ($branch ? " AND branch=?" : ""), $branch ? [$branch] : [], true)['c'] ?? 0);

        // Overdue EMIs
        $today = date('Y-m-d');
        $overdueCount = (int)(q("SELECT COUNT(*) as c FROM schedule s JOIN loans l ON s.loan_id=l.id WHERE s.paid=0 AND s.due_date < ?" . ($branch ? " AND l.branch=?" : ""), $branch ? [$today, $branch] : [$today], true)['c'] ?? 0);

        // Recent 5 loans
        $recentLoans = q("SELECT l.*, c.name as customer_name, p.name as product_name FROM loans l JOIN customers c ON l.customer_id=c.id JOIN products p ON l.product_id=p.id " . ($branch ? "WHERE l.branch=? " : "") . "ORDER BY l.id DESC LIMIT 5", $branch ? [$branch] : []);

        // Recent 5 applications
        $recentApps = q("SELECT a.*, c.name as customer_name, p.name as product_name FROM applications a JOIN customers c ON a.customer_id=c.id JOIN products p ON a.product_id=p.id " . ($branch ? "WHERE a.branch=? " : "") . "ORDER BY a.id DESC LIMIT 5", $branch ? [$branch] : []);

        // Recent 5 payments
        $recentPayments = q("SELECT p.*, l.branch, c.name as customer_name FROM payments p JOIN loans l ON p.loan_id=l.id JOIN customers c ON l.customer_id=c.id " . ($branch ? "WHERE l.branch=? " : "") . "ORDER BY p.id DESC LIMIT 5", $branch ? [$branch] : []);

        view('dashboard/index', [
            'totalBorrowers' => $totalBorrowers,
            'activeLoans' => $activeLoans,
            'totalDisbursed' => $disbursed,
            'totalCollected' => $totalCollected,
            'totalOutstanding' => $totalOutstanding,
            'pendingApps' => $pendingApps,
            'overdueCount' => $overdueCount,
            'recentLoans' => $recentLoans,
            'recentApps' => $recentApps,
            'recentPayments' => $recentPayments,
            'selectedBranch' => $branch
        ]);
    }

    public function details(): void {
        need('dashboard');
        
        // Branch-wise summary breakdown
        $branches = Database::getBranches();
        $breakdown = [];
        foreach ($branches as $b) {
            $loans = (int)(q("SELECT COUNT(*) as c FROM loans WHERE branch=? AND status='active'", [$b], true)['c'] ?? 0);
            $disbursed = (float)(q("SELECT COALESCE(SUM(principal),0) as s FROM loans WHERE branch=?", [$b], true)['s'] ?? 0);
            $outstanding = (float)(q("SELECT COALESCE(SUM(s.balance),0) as s FROM schedule s JOIN loans l ON s.loan_id=l.id WHERE s.paid=0 AND l.branch=? AND l.status='active'", [$b], true)['s'] ?? 0);
            $collected = (float)(q("SELECT COALESCE(SUM(p.amount),0) as s FROM payments p JOIN loans l ON p.loan_id=l.id WHERE l.branch=?", [$b], true)['s'] ?? 0);
            
            $breakdown[] = [
                'branch' => $b,
                'active_loans' => $loans,
                'disbursed' => $disbursed,
                'outstanding' => $outstanding,
                'collected' => $collected
            ];
        }

        view('dashboard/detail', [
            'breakdown' => $breakdown
        ]);
    }
}
