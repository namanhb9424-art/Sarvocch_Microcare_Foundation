<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>No Objection Certificate (NOC) - Loan #<?= $l['id'] ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 13px; color: #1e293b; line-height: 1.6; }
  .sheet { max-width: 780px; margin: auto; padding: 30px; border: 1px solid #cbd5e1; }
  @media print { .no-print { display: none !important; } .sheet { border: 0; padding: 0; } }
</style>
</head>
<body>
<div class="sheet mt-3">
  <div class="no-print d-flex justify-content-between mb-4 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print NOC Certificate</button>
    <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <!-- Letterhead Header -->
  <div class="d-flex justify-content-between align-items-center mb-4 pb-3 border-bottom border-2 border-dark">
    <div>
      <h3 class="fw-bold mb-0 text-teal" style="color: #0f766e;">SARVOOCCH MICROCARE FOUNDATION</h3>
      <div class="small text-muted">CIN: U88900MP2026NPL084139 · Section 8 Microfinance Institution</div>
      <div class="small">Regd. Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041</div>
    </div>
    <div class="text-end">
      <div class="badge bg-success fs-6 mb-1">NO OBJECTION CERTIFICATE</div>
      <div class="small">Date: <strong><?= date('d M Y') ?></strong></div>
      <div class="small">Certificate Ref: <strong>SMF/NOC/<?= date('Y') ?>/<?= sprintf('%05d', $l['id']) ?></strong></div>
    </div>
  </div>

  <div class="text-center my-4">
    <h4 class="fw-bold text-uppercase text-decoration-underline">TO WHOMSOEVER IT MAY CONCERN</h4>
    <div class="fw-semibold">NO DUE CERTIFICATE / बेबाकी प्रमाण पत्र</div>
  </div>

  <p>
    This is to certify that <strong>Mrs. <?= htmlspecialchars($l['customer_name']) ?></strong>, 
    residing at <strong><?= htmlspecialchars($l['address'] ?: 'Customer Address') ?></strong>, 
    having Aadhaar ending in <strong>•••• <?= substr($l['aadhaar'] ?? '0000', -4) ?></strong>, 
    had availed a microfinance credit facility bearing <strong>Loan Account No: #<?= $l['id'] ?></strong> 
    under our scheme <strong><?= htmlspecialchars($l['product_name']) ?></strong> from our 
    <strong><?= htmlspecialchars($l['branch']) ?></strong> branch.
  </p>

  <p>
    We hereby confirm and verify that the said loan account has been <strong>PAID IN FULL AND CLOSED</strong> 
    on <strong><?= fmt_date($l['closure_date'] ?: date('Y-m-d')) ?></strong>. 
    As of date, there are <strong>NIL OUTSTANDING DUES</strong> against this loan account.
  </p>

  <p>
    SARVOOCCH Microcare Foundation has <strong>NO OBJECTION</strong> to the borrower availing credit facilities 
    from other institutions or closing any related statutory pledges.
  </p>

  <div class="p-3 bg-light border rounded small my-4">
    <strong>Loan Summary:</strong><br>
    • Sanctioned Principal: <?= inr($l['principal']) ?><br>
    • Total Tenure: <?= $l['tenure'] ?> Monthly Instalments<br>
    • Account Closure Date: <?= fmt_date($l['closure_date'] ?: date('Y-m-d')) ?><br>
    • Outstanding Balance: <strong>₹ 0.00 (NIL)</strong>
  </div>

  <div class="row text-center mt-5 pt-3">
    <div class="col-6">
      <div style="height: 45px; border-bottom: 1px dashed #000;"></div>
      <div class="small fw-semibold mt-1">Borrower Acknowledgement</div>
    </div>
    <div class="col-6">
      <div style="height: 45px; border-bottom: 1px dashed #000;"></div>
      <div class="small fw-semibold mt-1">For SARVOOCCH Microcare Foundation<br>(Authorized Signatory & Seal)</div>
    </div>
  </div>
</div>
</body>
</html>
