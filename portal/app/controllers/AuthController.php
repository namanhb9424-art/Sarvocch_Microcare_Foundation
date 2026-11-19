<?php
/**
 * SARVOOCCH Microcare Foundation - Authentication Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class AuthController {
    public function index(): void {
        $u = current_user();
        if (!$u) {
            redirect(url('/login'));
        }
        if ($u['role'] === 'customer') {
            redirect(url('/portal'));
        }
        foreach (['dashboard' => '/dashboard', 'field' => '/field', 'crm' => '/crm'] as $mod => $ep) {
            if (can($mod)) {
                redirect(url($ep));
            }
        }
        redirect(url('/calculator'));
    }

    public function loginForm(): void {
        if (current_user()) {
            $this->index();
            return;
        }

        $demo = [];
        if (!DISABLE_DEMO_LOGINS) {
            $demo = [
                ["admin", "admin123", "Admin"],
                ["manager1", "manager123", "Manager"],
                ["uw1", "uw123", "Underwriter"],
                ["agent1", "agent123", "Field Agent"],
                ["cust1", "cust123", "Customer"]
            ];
        }

        view('auth/login', [
            'demo' => $demo,
            'demoEnabled' => !DISABLE_DEMO_LOGINS,
            'noLayout' => true
        ]);
    }

    public function loginPost(): void {
        csrf_verify();

        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $rateKey = 'login:' . $ip;

        // Rate limit: 10 attempts per 10 minutes
        if (!Auth::checkRateLimit($rateKey, 10, 600)) {
            flash("Too many failed attempts. For security, please wait 10 minutes before retrying.", "danger");
            $this->loginForm();
            return;
        }

        $username = trim($_POST['username'] ?? '');
        $password = $_POST['password'] ?? '';

        if (empty($username) || empty($password)) {
            flash("Username and password are required.", "danger");
            $this->loginForm();
            return;
        }

        $u = q("SELECT * FROM users WHERE username=?", [$username], true);

        if ($u && !empty($u['locked_until']) && strtotime($u['locked_until']) > time()) {
            flash("This account is temporarily locked due to repeated failed logins. Please try again later.", "danger");
            $this->loginForm();
            return;
        }

        if ($u && Auth::verifyPassword($password, $u['pw'])) {
            // Re-hash to bcrypt if stored with legacy format
            if (!password_verify($password, $u['pw'])) {
                $newHash = Auth::hashPassword($password);
                ex("UPDATE users SET pw=? WHERE id=?", [$newHash, $u['id']]);
            }

            Auth::login((int)$u['id']);

            if ($u['must_change']) {
                redirect(url('/change-password'));
            }

            $next = $_GET['next'] ?? '';
            if (!empty($next) && str_starts_with($next, '/') && !str_starts_with($next, '//')) {
                redirect(url($next));
            }
            $this->index();
            return;
        }

        // Track failed attempt
        if ($u) {
            ex("UPDATE users SET failed_logins=failed_logins+1, last_failed=NOW() WHERE id=?", [$u['id']]);
            $failedCount = (int)$u['failed_logins'] + 1;
            if ($failedCount >= 10) {
                $lock = date('Y-m-d H:i:s', time() + 1800); // 30 min lock
                ex("UPDATE users SET locked_until=? WHERE id=?", [$lock, $u['id']]);
            }
        }

        flash("Invalid username or password.", "danger");
        $this->loginForm();
    }

    public function logout(): void {
        Auth::logout();
        flash("You have been signed out safely.", "success");
        redirect(url('/login'));
    }

    public function changePasswordForm(): void {
        need('*', 'dashboard', 'portal', 'crm', 'field');
        $u = current_user();
        view('auth/change_password', [
            'forced' => (bool)$u['must_change']
        ]);
    }

    public function changePasswordPost(): void {
        csrf_verify();
        need('*', 'dashboard', 'portal', 'crm', 'field');
        $u = current_user();

        $old = $_POST['old'] ?? '';
        $new = $_POST['new'] ?? '';
        $confirm = $_POST['confirm'] ?? '';

        if (!Auth::verifyPassword($old, $u['pw'])) {
            flash("Current password is wrong.", "danger");
            view('auth/change_password', ['forced' => (bool)$u['must_change']]);
            return;
        }

        if (strlen($new) < 8 || !preg_match('/[A-Za-z]/', $new) || !preg_match('/[0-9]/', $new)) {
            flash("New password must be at least 8 characters and contain letters and digits.", "danger");
            view('auth/change_password', ['forced' => (bool)$u['must_change']]);
            return;
        }

        if ($new !== $confirm) {
            flash("The two new passwords do not match.", "danger");
            view('auth/change_password', ['forced' => (bool)$u['must_change']]);
            return;
        }

        if ($new === $old) {
            flash("Choose a password different from the current one.", "danger");
            view('auth/change_password', ['forced' => (bool)$u['must_change']]);
            return;
        }

        $hash = Auth::hashPassword($new);
        ex("UPDATE users SET pw=?, must_change=0 WHERE id=?", [$hash, $u['id']]);
        flash("Password updated successfully.", "success");
        $this->index();
    }
}
