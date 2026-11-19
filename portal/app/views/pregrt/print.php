<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pre-GRT Register - Group #<?= $g['id'] ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 11px; color: #1e293b; }
  .sheet { max-width: 900px; margin: auto; padding: 20px; }
  .lbl { width: 25%; font-weight: bold; background: #f8fafc; }
  @media print { .no-print { display: none !important; } .sheet { padding: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between mb-3 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Pre-GRT Register</button>
    <a href="<?= url('/pregrt/' . $g['id']) ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
    <div>
      <h4 class="fw-bold mb-0 text-teal">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="small text-muted">CIN: U88900MP2026NPL084139 · Section 8 Microfinance</div>
      <div class="small">Branch: <strong><?= htmlspecialchars($g['branch']) ?></strong></div>
    </div>
    <div class="text-end">
      <div class="fw-bold fs-6">PRE-GRT VERIFICATION REGISTER</div>
      <div class="small">Group: Center <strong><?= htmlspecialchars($g['center_no']) ?></strong> / Group <strong><?= htmlspecialchars($g['group_no']) ?></strong></div>
      <div class="small">Village: <strong><?= htmlspecialchars($g['village']) ?></strong>, Dist: <?= htmlspecialchars($g['district']) ?></div>
    </div>
  </div>

  <table class="table table-bordered table-sm mb-3">
    <thead class="table-light text-center small">
      <tr>
        <th>#</th>
        <th>Member Name</th>
        <th>Husband Name</th>
        <th>Age</th>
        <th>Aadhaar</th>
        <th>Annual Income</th>
        <th>Loan Amount (₹)</th>
        <th>Purpose</th>
        <th>Member Sign</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($members as $m): ?>
        <tr>
          <td class="text-center"><?= $m['sno'] ?></td>
          <td class="fw-bold"><?= htmlspecialchars($m['name']) ?></td>
          <td><?= htmlspecialchars($m['husband_name']) ?></td>
          <td class="text-center"><?= $m['age'] ?></td>
          <td class="text-center">•••• <?= $m['aadhaar4'] ?: '0000' ?></td>
          <td class="text-end"><?= inr($m['annual_income']) ?></td>
          <td class="text-end fw-bold"><?= inr($m['loan_amount']) ?></td>
          <td><?= htmlspecialchars($m['purpose']) ?></td>
          <td style="width: 120px;"></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>

  <div class="p-2 border bg-light small mb-4">
    <strong>Group Discipline & Peer Guarantee Undertaking:</strong><br>
    हम समूह की सभी महिला सदस्य सर्वसम्मति से प्रमाणित करती हैं कि हमने सर्वोच्‍च माइक्रोकेयर के सभी नियमों, साप्ताहिक/मासिक बैठकों, ब्याज दर (24% घटती दर) एवं सामूहिक उत्तरदायित्व को समझ लिया है। यदि कोई सदस्य किस्त देने में असमर्थ होती है, तो समूह उसका दायित्व स्वीकार करेगा।
  </div>

  <div class="row text-center mt-4">
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Field Officer (PSO)</div>
      <div class="text-muted" style="font-size: 0.75rem;"><?= htmlspecialchars($g['pso_name']) ?></div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Group Leader Signature</div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Branch Manager Verification</div>
      <div class="text-muted" style="font-size: 0.75rem;"><?= htmlspecialchars($g['verified_by'] ?: 'Pending Review') ?></div>
    </div>
  </div>
</div>
</body>
</html>
