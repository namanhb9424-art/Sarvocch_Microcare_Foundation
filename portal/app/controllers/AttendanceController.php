<?php
/**
 * SARVOOCCH Microcare Foundation - Attendance & Regularization Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class AttendanceController {
    public function index(): void {
        need('attendance');
        $u = current_user();

        $today = date('Y-m-d');
        $myAttendance = q("SELECT * FROM attendance WHERE user_id=? ORDER BY day DESC LIMIT 30", [$u['id']]);
        $todayRecord = q("SELECT * FROM attendance WHERE user_id=? AND day=?", [$u['id'], $today], true);

        // Requests
        $requests = [];
        if (can('manager') || can('admin')) {
            $requests = q("SELECT r.*, u.name as user_name FROM att_requests r JOIN users u ON r.user_id=u.id ORDER BY r.id DESC LIMIT 50");
        } else {
            $requests = q("SELECT * FROM att_requests WHERE user_id=? ORDER BY id DESC LIMIT 20", [$u['id']]);
        }

        view('attendance/index', [
            'myAttendance' => $myAttendance,
            'todayRecord' => $todayRecord,
            'requests' => $requests,
            'today' => $today
        ]);
    }

    public function punch(): void {
        csrf_verify();
        need('attendance');
        $u = current_user();

        $today = date('Y-m-d');
        $nowTime = date('H:i:s');
        $lat = !empty($_POST['lat']) ? (float)$_POST['lat'] : null;
        $lng = !empty($_POST['lng']) ? (float)$_POST['lng'] : null;

        $existing = q("SELECT * FROM attendance WHERE user_id=? AND day=?", [$u['id'], $today], true);

        if (!$existing) {
            // Punch In
            ex("INSERT INTO attendance (user_id, day, in_time, lat, lng) VALUES (?, ?, ?, ?, ?)",
                [$u['id'], $today, $nowTime, $lat, $lng]);
            flash("Punch IN registered at " . date('h:i A'), "success");
        } else {
            // Punch Out
            ex("UPDATE attendance SET out_time=? WHERE id=?", [$nowTime, $existing['id']]);
            flash("Punch OUT registered at " . date('h:i A'), "info");
        }

        redirect(url('/attendance'));
    }

    public function request(): void {
        csrf_verify();
        need('attendance');
        $u = current_user();

        $day = $_POST['day'] ?: date('Y-m-d');
        $inTime = $_POST['in_time'] ?: '09:30:00';
        $outTime = $_POST['out_time'] ?: '18:30:00';
        $reason = trim($_POST['reason'] ?? 'Field collection overtime');

        ex("INSERT INTO att_requests (user_id, branch, day, in_time, out_time, reason, status, requested_at) VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW())",
            [$u['id'], $u['branch'], $day, $inTime, $outTime, $reason]);

        flash("Attendance regularization request submitted for approval.", "success");
        redirect(url('/attendance'));
    }

    public function decide(int $rid, string $action): void {
        csrf_verify();
        need('manager', 'admin');
        $u = current_user();

        $req = q("SELECT * FROM att_requests WHERE id=?", [$rid], true);
        if (!$req) {
            flash("Request not found.", "danger");
            redirect(url('/attendance'));
        }

        $decision = ($action === 'approve') ? 'approved' : 'rejected';
        ex("UPDATE att_requests SET status=?, decided_by=?, decided_at=NOW() WHERE id=?",
            [$decision, $u['name'], $rid]);

        if ($decision === 'approved') {
            // Upsert attendance table
            $existing = q("SELECT id FROM attendance WHERE user_id=? AND day=?", [$req['user_id'], $req['day']], true);
            if ($existing) {
                ex("UPDATE attendance SET in_time=?, out_time=? WHERE id=?", [$req['in_time'], $req['out_time'], $existing['id']]);
            } else {
                ex("INSERT INTO attendance (user_id, day, in_time, out_time) VALUES (?, ?, ?, ?)",
                    [$req['user_id'], $req['day'], $req['in_time'], $req['out_time']]);
            }
        }

        flash("Attendance regularization " . $decision, "info");
        redirect(url('/attendance'));
    }
}
