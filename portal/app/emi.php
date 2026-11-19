<?php
/**
 * SARVOOCCH Microcare Foundation - Financial Engine & EMI Calculations
 * Exact mathematical parity with Python implementation
 */

if (!defined('SARVOOCCH_APP')) exit;

class Finance {
    public static function addMonths(DateTime $d, int $n): DateTime {
        $result = clone $d;
        $year = (int)$result->format('Y');
        $month = (int)$result->format('m') - 1 + $n;
        $year += intdiv($month, 12);
        $month = $month % 12 + 1;

        $isLeap = ($year % 4 === 0 && ($year % 100 !== 0 || $year % 400 === 0));
        $dim = [0, 31, ($isLeap ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

        $day = min((int)$d->format('j'), $dim[$month]);
        $result->setDate($year, $month, $day);
        return $result;
    }

    public static function getHolidays(): array {
        try {
            $rows = q("SELECT day FROM holidays");
            return array_column($rows, 'day');
        } catch (Exception $e) {
            return [];
        }
    }

    public static function nextWorkingDay(DateTime $d, array $holidays): DateTime {
        $result = clone $d;
        while ((int)$result->format('N') >= 6 || in_array($result->format('Y-m-d'), $holidays, true)) {
            $result->modify('+1 day');
        }
        return $result;
    }

    public static function emiCalc(float $P, float $annual, int $n, string $method = 'reducing'): float {
        if ($n <= 0) return 0.0;
        if ($method === 'flat') {
            return round(($P + $P * $annual / 100.0 * $n / 12.0) / $n, 2);
        }
        $r = $annual / 1200.0;
        if ($r == 0) return round($P / $n, 2);
        return round($P * $r * pow(1.0 + $r, $n) / (pow(1.0 + $r, $n) - 1.0), 2);
    }

    public static function buildSchedule(float $P, float $annual, int $n, DateTime $start, string $method = 'reducing', ?array $holidays = null): array {
        $hol = $holidays ?? self::getHolidays();
        $rows = [];
        $bal = $P;
        $emi = self::emiCalc($P, $annual, $n, $method);

        for ($i = 1; $i <= $n; $i++) {
            if ($method === 'flat') {
                $interest = round($P * $annual / 100.0 / 12.0, 2);
                $prin = round($P / $n, 2);
            } else {
                $interest = round($bal * $annual / 1200.0, 2);
                $prin = round($emi - $interest, 2);
            }

            if ($i === $n) {
                $prin = round($bal, 2);
            }

            $thisEmi = round($prin + $interest, 2);
            $bal = round($bal - $prin, 2);
            $dueDate = self::nextWorkingDay(self::addMonths($start, $i), $hol);

            $rows[] = [
                'no' => $i,
                'due_date' => $dueDate->format('Y-m-d'),
                'emi' => $thisEmi,
                'principal' => $prin,
                'interest' => $interest,
                'balance' => max($bal, 0.0)
            ];
        }

        return [$emi, $rows];
    }

    public static function createLoan(int $appId, ?DateTime $start = null): int {
        $a = q("SELECT * FROM applications WHERE id=?", [$appId], true);
        if (!$a) throw new Exception("Application not found");
        $p = q("SELECT * FROM products WHERE id=?", [$a['product_id']], true);
        if (!$p) throw new Exception("Product not found");

        $start = $start ?? new DateTime();
        [$emi, $rows] = self::buildSchedule((float)$a['amount'], (float)$a['rate'], (int)$a['tenure'], $start, $p['method']);

        $lid = ex(
            "INSERT INTO loans(application_id, customer_id, product_id, principal, rate, tenure, method, emi, start_date, status, branch, agent_id) " .
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)",
            [
                $appId, $a['customer_id'], $a['product_id'], $a['amount'], $a['rate'],
                $a['tenure'], $p['method'], $emi, $start->format('Y-m-d'),
                $a['branch'], $a['agent_id']
            ]
        );

        foreach ($rows as $r) {
            ex(
                "INSERT INTO schedule(loan_id, no, due_date, emi, principal, interest, balance) VALUES (?, ?, ?, ?, ?, ?, ?)",
                [$lid, $r['no'], $r['due_date'], $r['emi'], $r['principal'], $r['interest'], $r['balance']]
            );
        }

        return $lid;
    }

    public static function recordPayment(int $loanId, int $schedId, string $channel, ?string $ref = null, ?string $at = null): ?string {
        $s = q("SELECT * FROM schedule WHERE id=? AND loan_id=?", [$schedId, $loanId], true);
        if (!$s || $s['paid']) return null;

        $at = $at ?? date('Y-m-d H:i:s');
        $dateOnly = substr($at, 0, 10);
        $ref = $ref ?: strtoupper(substr($channel, 0, 3)) . strtoupper(bin2hex(random_bytes(5)));

        ex("UPDATE schedule SET paid=1, paid_on=? WHERE id=?", [$dateOnly, $schedId]);
        ex("INSERT INTO payments(loan_id, schedule_id, amount, channel, ref, at) VALUES (?, ?, ?, ?, ?, ?)",
            [$loanId, $schedId, $s['emi'], $channel, $ref, $at]);

        $leftRow = q("SELECT COUNT(*) as c FROM schedule WHERE loan_id=? AND paid=0", [$loanId], true);
        if ((int)($leftRow['c'] ?? 0) === 0) {
            ex("UPDATE loans SET status='closed', closure_date=? WHERE id=?", [$dateOnly, $loanId]);
        }

        return $ref;
    }

    public static function feeSplit(float $amount, float $feePct, ?float $gstRate = null): array {
        $cfg = Database::getConfig();
        $rate = $gstRate ?? (float)($cfg['gst_rate'] ?? 18.0);
        $fee = round($amount * $feePct / 100.0, 2);
        $half = round($fee * $rate / 200.0, 2);
        return [
            'fee' => $fee,
            'cgst' => $half,
            'sgst' => $half,
            'rate' => $rate,
            'half_rate' => $rate / 2.0,
            'total' => round($fee + 2.0 * $half, 2)
        ];
    }

    public static function settlementQuote(int $lid): ?array {
        $unpaid = q("SELECT * FROM schedule WHERE loan_id=? AND paid=0 ORDER BY no", [$lid]);
        if (empty($unpaid)) return null;

        $principal = round(array_sum(array_column($unpaid, 'principal')), 2);
        $nxt = (float)$unpaid[0]['interest'];
        $remainingInterest = array_slice($unpaid, 1);
        $saved = round(array_sum(array_column($remainingInterest, 'interest')), 2);

        return [
            'principal' => $principal,
            'interest' => $nxt,
            'total' => round($principal + $nxt, 2),
            'next_no' => (int)$unpaid[0]['no'],
            'left' => count($unpaid),
            'next_id' => (int)$unpaid[0]['id'],
            'saved' => $saved
        ];
    }

    public static function nocState(array $loan): array {
        if (($loan['status'] ?? '') !== 'closed' || empty($loan['closure_date'])) {
            return [false, null];
        }
        $closed = new DateTime($loan['closure_date']);
        $closed->modify('+15 days');
        $today = new DateTime();
        return [$today >= $closed, $closed->format('Y-m-d')];
    }
}
