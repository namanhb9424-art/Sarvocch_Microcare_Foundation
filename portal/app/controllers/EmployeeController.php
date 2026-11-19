<?php
/**
 * SARVOOCCH Microcare Foundation - Employee & Staff Dossier Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class EmployeeController {
    public function list(): void {
        need('employees');
        $employees = q("SELECT e.*, u.username, u.role, m.name as manager_name " .
                       "FROM employees e " .
                       "LEFT JOIN users u ON e.user_id=u.id " .
                       "LEFT JOIN employees m ON e.manager_id=m.id " .
                       "ORDER BY e.id DESC");

        $branches = Database::getBranches();
        view('employees/list', [
            'employees' => $employees,
            'branches' => $branches
        ]);
    }

    public function create(): void {
        csrf_verify();
        need('employees', 'admin');

        $name = trim($_POST['name'] ?? '');
        $desig = trim($_POST['designation'] ?? 'Field Officer');
        $branch = $_POST['branch'] ?? 'Pipariya Branch';
        $phone = trim($_POST['phone'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $salary = (float)($_POST['salary'] ?? 20000);
        $role = $_POST['role'] ?? 'field_agent';

        if (empty($name) || empty($phone)) {
            flash("Employee name and phone are required.", "danger");
            redirect(url('/employees'));
        }

        // Create portal user account
        $cleanPhone = preg_replace('/\D/', '', $phone);
        $uname = 'emp_' . ($cleanPhone ? substr($cleanPhone, -6) : rand(100, 999));
        $tempPw = 'Emp@' . rand(1000, 9999);
        $hash = Auth::hashPassword($tempPw);

        $uid = ex("INSERT INTO users (username, pw, name, role, branch, phone, must_change) VALUES (?, ?, ?, ?, ?, ?, 1)",
            [$uname, $hash, $name, $role, $branch, $phone]);

        $defaultDocs = json_encode(['Aadhaar Card', 'PAN Card', 'Bank Passbook', 'Driving License']);

        ex("INSERT INTO employees (user_id, name, designation, branch, phone, email, joined, status, bg_check, docs, salary) " .
           "VALUES (?, ?, ?, ?, ?, ?, CURDATE(), 'active', 'cleared', ?, ?)",
            [$uid, $name, $desig, $branch, $phone, $email, $defaultDocs, $salary]);

        flash("Employee " . htmlspecialchars($name) . " created with portal username: " . $uname . " and temp password: " . $tempPw, "success");
        redirect(url('/employees'));
    }

    public function update(int $eid): void {
        csrf_verify();
        need('employees', 'admin');

        $status = $_POST['status'] ?? 'active';
        $bgCheck = $_POST['bg_check'] ?? 'cleared';
        $salary = (float)($_POST['salary'] ?? 20000);

        ex("UPDATE employees SET status=?, bg_check=?, salary=? WHERE id=?",
            [$status, $bgCheck, $salary, $eid]);

        flash("Employee record updated.", "success");
        redirect(url('/employees'));
    }

    public function printDoc(int $eid): void {
        need('employees');
        $e = q("SELECT e.*, u.username, u.role, m.name as manager_name " .
               "FROM employees e " .
               "LEFT JOIN users u ON e.user_id=u.id " .
               "LEFT JOIN employees m ON e.manager_id=m.id " .
               "WHERE e.id=?", [$eid], true);

        if (!$e) {
            flash("Employee not found.", "danger");
            redirect(url('/employees'));
        }

        $allDocs = ['Aadhaar Card', 'PAN Card', 'Voter ID', 'Driving License', 'Bank Passbook', 'Police Verification', 'Educational Certificate'];
        $docs = json_decode($e['docs'] ?? '[]', true) ?: [];

        view('employees/print', [
            'e' => $e,
            'allDocs' => $allDocs,
            'docs' => $docs,
            'noLayout' => true
        ]);
    }
}
