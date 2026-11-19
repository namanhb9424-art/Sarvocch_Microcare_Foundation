<?php
/**
 * SARVOOCCH Microcare Foundation - Loan Products Catalog Controller
 */

if (!defined('SARVOOCCH_APP')) exit;

class ProductController {
    public function index(): void {
        need('products', 'admin');
        $products = q("SELECT * FROM products ORDER BY id ASC");
        view('products/index', ['products' => $products]);
    }

    public function save(): void {
        csrf_verify();
        need('products', 'admin');

        $name = trim($_POST['name'] ?? '');
        $rate = (float)($_POST['rate'] ?? 24.0);
        $minAmt = (float)($_POST['min_amt'] ?? 10000);
        $maxAmt = (float)($_POST['max_amt'] ?? 50000);
        $minTenure = (int)($_POST['min_tenure'] ?? 12);
        $maxTenure = (int)($_POST['max_tenure'] ?? 24);
        $method = $_POST['method'] ?? 'reducing';
        $feePct = (float)($_POST['fee_pct'] ?? 1.5);
        $active = !empty($_POST['active']) ? 1 : 0;

        if (empty($name)) {
            flash("Product name is required.", "danger");
            redirect(url('/products'));
        }

        ex("INSERT INTO products (name, rate, min_amt, max_amt, min_tenure, max_tenure, method, fee_pct, active) " .
           "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [$name, $rate, $minAmt, $maxAmt, $minTenure, $maxTenure, $method, $feePct, $active]);

        flash("Loan Product " . htmlspecialchars($name) . " saved to catalogue.", "success");
        redirect(url('/products'));
    }
}
