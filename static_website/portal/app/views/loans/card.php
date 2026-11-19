<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Loan Passbook Card - #<?= $l['id'] ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 11px; }
  .sheet { max-width: 800px; margin: auto; padding: 20px; }
  .lbl { width: 30%; font-weight: bold; background: #f8fafc; }
  @media print { .no-print { display: none !important; } .sheet { padding: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between mb-3 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Card</button>
    <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <div class="text-center mb-3">
    <h4 class="fw-bold mb-0 text-teal">SARVOOCCH MICROCARE FOUNDATION</h4>
    <div class="small text-muted">LOAN PASSBOOK CARD / ऋण पासबुक कार्ड</div>
    <div class="small">Branch: <strong><?= htmlspecialchars($l['branch']) ?></strong> · Loan Account: <strong>#<?= $l['id'] ?></strong></div>
  </div>

  <table class="table table-bordered table-sm mb-3">
    <tr><td class="lbl">Borrower Name</td><td class="fw-bold"><?= htmlspecialchars($l['customer_name']) ?></td><td class="lbl">Loan Product</td><td><?= htmlspecialchars($l['product_name']) ?></td></tr>
    <tr><td class="lbl">Principal Disbursed</td><td class="fw-bold"><?= inr($l['principal']) ?></td><td class="lbl">Interest Rate</td><td><?= $l['rate'] ?>% p.a. (Reducing)</td></tr>
    <tr><td class="lbl">Monthly EMI</td><td class="fw-bold"><?= inr($l['emi']) ?></td><td class="lbl">Tenure</td><td><?= $l['tenure'] ?> Instalments</td></tr>
  </table>

  <table class="table table-bordered table-sm mb-0">
    <thead class="table-light text-center">
      <tr>
        <th>Instalment #</th>
        <th>Due Date</th>
        <th>Instalment (₹)</th>
        <th>Principal (₹)</th>
        <th>Interest (₹)</th>
        <th>Balance (₹)</th>
        <th>Date Paid</th>
        <th>Officer Sign</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($schedule as $s): ?>
        <tr>
          <td class="text-center"><?= $s['no'] ?></td>
          <td class="text-center"><?= fmt_date($s['due_date']) ?></td>
          <td class="text-end fw-bold"><?= inr($s['emi']) ?></td>
          <td class="text-end"><?= inr($s['principal']) ?></td>
          <td class="text-end"><?= inr($s['interest']) ?></td>
          <td class="text-end"><?= inr($s['balance']) ?></td>
          <td class="text-center"><?= $s['paid'] ? fmt_date($s['paid_on']) : '' ?></td>
          <td></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>
</body>
</html>
