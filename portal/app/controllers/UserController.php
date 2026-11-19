<?php
/**
 * SARVOOCCH Microcare Foundation - Users & Roles Management Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class UserController {
    public function index(): void {
        need('users', 'admin');
        $users = q("SELECT * FROM users ORDER BY id ASC");
        view('users/index', [
            'users' => $users,
            'roles' => ROLES
        ]);
    }

    public function changeRole(int $uid): void {
        csrf_verify();
        need('users', 'admin');

        $role = $_POST['role'] ?? 'field_agent';
        if (in_array($role, ROLES, true)) {
            ex("UPDATE users SET role=? WHERE id=?", [$role, $uid]);
            flash("User role updated successfully.", "success");
        } else {
            flash("Invalid role specified.", "danger");
        }

        redirect(url('/users'));
    }
}
