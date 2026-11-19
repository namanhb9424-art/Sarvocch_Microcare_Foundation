<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sanction Letter - App #<?= $a['id'] ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 12px; color: #1e293b; }
  .sheet { max-width: 780px; margin: auto; padding: 25px; }
  .lbl { width: 35%; font-weight: bold; background: #f8fafc; }
  @media print { .no-print { display: none !important; } .sheet { padding: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between mb-3 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Sanction Letter</button>
    <a href="<?= url('/applications/' . $a['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <!-- Header -->
  <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
    <div>
      <h4 class="fw-bold mb-0 text-teal">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="small text-muted">CIN: U88900MP2026NPL084139 · Section 8 Microfinance Institution</div>
      <div class="small">Regd. Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041</div>
    </div>
    <div class="text-end">
      <div class="badge bg-teal fs-6 mb-1 text-white" style="background-color: #0f766e;">LOAN SANCTION LETTER</div>
      <div class="small">Date: <strong><?= date('d M Y') ?></strong></div>
      <div class="small">Ref: <strong>SMF/SL/<?= date('Y') ?>/<?= sprintf('%05d', $a['id']) ?></strong></div>
    </div>
  </div>

  <p>To,<br>
  <strong>Mrs. <?= htmlspecialchars($a['customer_name']) ?></strong><br>
  <?= htmlspecialchars($a['customer_address'] ?: 'Customer Address') ?><br>
  Mobile: <?= htmlspecialchars($a['phone'] ?: '') ?>
  </p>

  <p class="mt-2">
    Dear Borrower,<br>
    We are pleased to inform you that with reference to your loan application, <strong>SARVOOCCH Microcare Foundation</strong> has sanctioned the microfinance loan facility under the terms outlined below:
  </p>

  <table class="table table-bordered table-sm mb-3">
    <tr><td class="lbl">Sanctioned Amount</td><td class="fw-bold fs-6 text-teal"><?= inr($a['amount']) ?></td></tr>
    <tr><td class="lbl">Loan Product</td><td><?= htmlspecialchars($a['product_name']) ?></td></tr>
    <tr><td class="lbl">Interest Rate</td><td><?= $a['rate'] ?>% p.a. (Reducing Balance Method)</td></tr>
    <tr><td class="lbl">Repayment Tenure</td><td><?= $a['tenure'] ?> Monthly Instalments</td></tr>
    <tr><td class="lbl">Prepayment Penalty</td><td><strong>0.00% (No Prepayment Penalty Guarantee)</strong></td></tr>
    <tr><td class="lbl">Lending Type</td><td>Joint Liability Group (JLG) - Collateral Free Microcredit</td></tr>
    <tr><td class="lbl">Branch Serving Account</td><td><?= htmlspecialchars($a['branch']) ?></td></tr>
  </table>

  <div class="small text-muted mb-4">
    <strong>Key Undertakings:</strong><br>
    • Repayment schedule will be issued upon disbursement. Instalments are due on working days.<br>
    • Grievance Redressal Officer Helpline: <code>+91 91111 99101</code> | Email: <code>sarvocchmicrocare@gmail.com</code>.<br>
    • You can track EMIs and download receipts at: <strong>https://sarvocchfinance.com/portal</strong>
  </div>

  <div class="row text-center mt-5">
    <div class="col-6">
      <div style="height: 45px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Borrower Acceptance Signature / Thumb</div>
    </div>
    <div class="col-6">
      <div style="height: 45px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">For SARVOOCCH Microcare Foundation<br>(Authorized Credit Signatory)</div>
    </div>
  </div>
</div>
</body>
</html>
