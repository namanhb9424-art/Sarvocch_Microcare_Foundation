<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Key Fact Statement (KFS) - Loan #<?= $l['id'] ?> · Sarvoocch Microcare</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #f8fafc; font-size: 11.5px; color: #1e293b; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; padding: 20px 0; }
  .sheet { max-width: 820px; margin: auto; background: #fff; padding: 32px; border: 1px solid #cbd5e1; border-radius: 8px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
  .lbl { width: 38%; font-weight: 600; background: #f8fafc; color: #334155; }
  .section-banner { background: #0f766e; color: #fff; padding: 6px 12px; font-weight: 700; font-size: 12.5px; text-transform: uppercase; letter-spacing: 0.5px; border-radius: 4px; margin-bottom: 12px; }
  .rbi-badge { background: #f0fdf4; border: 1px solid #86efac; color: #166534; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 4px; display: inline-block; }
  @media print {
    body { background: #fff; padding: 0; }
    .sheet { border: none; box-shadow: none; padding: 0; max-width: 100%; }
    .no-print { display: none !important; }
  }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
    <div>
      <button onclick="window.print()" class="btn btn-primary btn-sm fw-semibold">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="me-1"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
        Print / Save Official KFS PDF
      </button>
    </div>
    <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-secondary btn-sm">Back to Loan</a>
  </div>

  <!-- Header -->
  <div class="d-flex justify-content-between align-items-start border-bottom pb-3 mb-3">
    <div>
      <h4 class="fw-bold mb-0 text-teal" style="color: #0f766e; font-size: 21px;">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="text-muted" style="font-size: 11px;">Section 8 Non-Profit Microfinance Institution · CIN: <code>U88900MP2026NPL084139</code></div>
      <div class="text-muted" style="font-size: 11px;">Regd. Office: Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal, MP - 462041</div>
    </div>
    <div class="text-end">
      <span class="rbi-badge mb-1">RBI REGULATORY FORMAT</span>
      <div class="small mt-1">Ref: <strong>SMF/KFS/<?= date('Y') ?>/<?= sprintf('%05d', $l['id']) ?></strong></div>
      <div class="small">Date of Issue: <strong><?= date('d M Y') ?></strong></div>
    </div>
  </div>

  <div class="section-banner">
    KEY FACT STATEMENT (KFS) / मुख्य तथ्य विवरण (RBI Master Direction Compliant)
  </div>

  <p class="mb-3 small">
    Issued under <em>Master Direction – Reserve Bank of India (Regulatory Framework for Microfinance Loans) Directions, 2022</em>. 
    This document summarizes key financial terms of your microfinance loan facility before/upon disbursement.
  </p>

  <!-- Section 1: Customer & Loan Identification -->
  <table class="table table-bordered table-sm mb-3">
    <tr>
      <td class="lbl">Borrower Name (उधारकर्ता का नाम)</td>
      <td class="fw-bold"><?= htmlspecialchars($l['customer_name']) ?></td>
      <td class="lbl">Loan Account Number</td>
      <td class="fw-bold font-monospace"><?= htmlspecialchars($l['loan_no'] ?: 'SMF-LN-' . $l['id']) ?></td>
    </tr>
    <tr>
      <td class="lbl">Mobile / Contact Number</td>
      <td><?= htmlspecialchars($l['phone'] ?: '-') ?></td>
      <td class="lbl">Loan Product Name</td>
      <td><?= htmlspecialchars($l['product_name']) ?></td>
    </tr>
    <tr>
      <td class="lbl">Permanent / Residence Address</td>
      <td><?= htmlspecialchars($l['address'] ?: 'Customer Address') ?></td>
      <td class="lbl">Serving Branch</td>
      <td><?= htmlspecialchars($l['branch']) ?></td>
    </tr>
    <tr>
      <td class="lbl">Borrower Bank Account & IFSC</td>
      <td colspan="3"><?= htmlspecialchars(($l['bank_account'] ?: 'A/C on file') . ' · IFSC: ' . ($l['bank_ifsc'] ?: 'On record')) ?></td>
    </tr>
  </table>

  <!-- Section 2: Financial Terms & Cost Breakdown -->
  <div class="fw-bold text-dark mb-2">PART A: FINANCIAL TERMS & APR DISCLOSURE</div>
  <table class="table table-bordered table-sm mb-3">
    <tr>
      <td class="lbl">1. Sanctioned Loan Amount (Principal)</td>
      <td class="fw-bold fs-6 text-dark"><?= inr($principal) ?></td>
      <td class="lbl">2. Repayment Tenure</td>
      <td><strong><?= $l['tenure'] ?></strong> Months (<?= $l['tenure'] ?> Monthly EMIs)</td>
    </tr>
    <tr>
      <td class="lbl">3. Interest Rate (% per annum)</td>
      <td><strong><?= $l['rate'] ?>% p.a.</strong> (<?= ucfirst($l['method'] ?? 'reducing') ?> Balance Method)</td>
      <td class="lbl">4. Monthly Instalment (EMI)</td>
      <td class="fw-bold text-teal" style="color: #0f766e;"><?= inr($l['emi']) ?> / month</td>
    </tr>
    <tr>
      <td class="lbl">5. Upfront Processing Fee (<?= number_format($feePct, 2) ?>%)</td>
      <td><?= inr($procFee) ?></td>
      <td class="lbl">6. GST on Processing Fee (18%)</td>
      <td><?= inr($gstTotal) ?> <span class="text-muted" style="font-size: 10px;">(CGST 9%: <?= inr($cgst) ?> + SGST 9%: <?= inr($sgst) ?>)</span></td>
    </tr>
    <tr>
      <td class="lbl">7. Total Upfront Deductions (5 + 6)</td>
      <td class="text-danger fw-semibold"><?= inr($upfrontDeductions) ?></td>
      <td class="lbl">8. Net Disbursed to Bank Account (1 - 7)</td>
      <td class="fw-bold text-success fs-6"><?= inr($netDisbursed) ?></td>
    </tr>
    <tr>
      <td class="lbl">9. Total Interest Payable over Full Tenure</td>
      <td><?= inr($totalInterest) ?></td>
      <td class="lbl">10. Total Repayment by Borrower (1 + 9)</td>
      <td class="fw-bold"><?= inr($totalRepay) ?></td>
    </tr>
    <tr class="table-light">
      <td class="lbl" style="background: #e2e8f0;">11. Total Cost of Credit (7 + 9)</td>
      <td class="fw-bold text-dark"><?= inr($totalCostOfCredit) ?></td>
      <td class="lbl" style="background: #e2e8f0;">12. Annual Percentage Rate (APR)</td>
      <td class="fw-bold fs-6" style="color: #0f766e;"><?= number_format($apr, 2) ?>% p.a.</td>
    </tr>
  </table>

  <!-- Section 3: Statutory & Regulatory Undertakings -->
  <div class="fw-bold text-dark mb-2">PART B: MANDATORY REGULATORY DISCLOSURES (RBI DIRECTIONS 2022)</div>
  <table class="table table-bordered table-sm mb-3">
    <tr>
      <td class="lbl">Cooling-off / Look-up Period (कूलिंग ऑफ अवधि)</td>
      <td><strong>3 Calendar Days</strong> from disbursement. The borrower can exit the loan without penalty by refunding the principal.</td>
    </tr>
    <tr>
      <td class="lbl">Prepayment Penalty Guarantee</td>
      <td><strong>0.00% (Nil)</strong>. Under RBI Master Direction 2022, SARVOOCCH Microcare Foundation charges zero penalty for pre-payment or early foreclosure.</td>
    </tr>
    <tr>
      <td class="lbl">Collateral / Security Requirement</td>
      <td><strong>Nil / Collateral-Free</strong>. Microfinance loans are strictly without collateral or margin money.</td>
    </tr>
    <tr>
      <td class="lbl">Fair Practices Code & Collection Conduct</td>
      <td>Strictly between <strong>07:00 AM and 07:00 PM</strong> at designated center or residence. No harsh or intimidatory recovery conduct.</td>
    </tr>
    <tr>
      <td class="lbl">Grievance Redressal (Level 1)</td>
      <td>Grievance Officer, Shop No. 10A/GF, Sagar High Street, Ayodhya Bypass, Bhopal - 462041.<br>
      Helpline: <strong>+91 91111 99101</strong> | Email: <strong>sarvocchmicrocare@gmail.com</strong> | Portal: <code>https://sarvocchfinance.com</code></td>
    </tr>
    <tr>
      <td class="lbl">Regulatory Escalation (Level 2)</td>
      <td>RBI Integrated Ombudsman Scheme - Complaint Management System (CMS): <strong>https://cms.rbi.org.in</strong></td>
    </tr>
  </table>

  <!-- Section 4: Amortization Schedule Summary -->
  <div class="fw-bold text-dark mb-2">PART C: REPAYMENT SCHEDULE SUMMARY (परिशोधन अनुसूची)</div>
  <div class="table-responsive mb-4">
    <table class="table table-bordered table-sm text-center mb-0">
      <thead class="table-light">
        <tr>
          <th>No</th>
          <th>Due Date</th>
          <th>Principal (₹)</th>
          <th>Interest (₹)</th>
          <th>Total EMI (₹)</th>
          <th>Closing Balance (₹)</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($schedule as $s): ?>
          <tr>
            <td><?= $s['no'] ?></td>
            <td><?= fmt_date($s['due_date']) ?></td>
            <td class="text-end"><?= inr($s['principal']) ?></td>
            <td class="text-end"><?= inr($s['interest']) ?></td>
            <td class="text-end fw-bold"><?= inr($s['emi']) ?></td>
            <td class="text-end"><?= inr($s['balance']) ?></td>
            <td><?= $s['paid'] ? '<span class="badge bg-success" style="font-size: 9px;">Paid</span>' : '<span class="text-muted" style="font-size: 10px;">Due</span>' ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>

  <!-- Signatures -->
  <div class="row text-center mt-4 pt-2">
    <div class="col-6">
      <div style="height: 50px; border-bottom: 1.5px dashed #475569; margin: 0 30px;"></div>
      <div class="small fw-semibold mt-2">Borrower Acceptance / अंगूठा या हस्ताक्षर<br><span class="text-muted" style="font-size: 10px;">(I have understood and accepted all terms in Hindi/English)</span></div>
    </div>
    <div class="col-6">
      <div style="height: 50px; border-bottom: 1.5px dashed #475569; margin: 0 30px;"></div>
      <div class="small fw-semibold mt-2">For SARVOOCCH Microcare Foundation<br><span class="text-muted" style="font-size: 10px;">(Authorized Credit Officer / Branch Manager)</span></div>
    </div>
  </div>
</div>
</body>
</html>
