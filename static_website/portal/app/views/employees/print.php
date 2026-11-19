<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Employee Dossier - <?= htmlspecialchars($e['name']) ?></title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #fff; font-size: 12px; color: #1e293b; }
  .sheet { max-width: 780px; margin: auto; padding: 25px; }
  .lbl { width: 30%; font-weight: bold; background: #f8fafc; }
  @media print { .no-print { display: none !important; } .sheet { padding: 0; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="no-print d-flex justify-content-between mb-3 pb-2 border-bottom">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Dossier</button>
    <a href="<?= url('/employees') ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>

  <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
    <div>
      <h4 class="fw-bold mb-0 text-teal">SARVOOCCH MICROCARE FOUNDATION</h4>
      <div class="small text-muted">CIN: U88900MP2026NPL084139 · Section 8 Microfinance</div>
      <div class="small">Head Office: Sagar High Street, Ayodhya Bypass, Bhopal - 462041</div>
    </div>
    <div class="text-end">
      <div class="fw-bold fs-6">STAFF DOSSIER / कर्मचारी विवरण प्रपत्र</div>
      <div class="small">Employee ID: <strong>EMP<?= sprintf('%04d', $e['id']) ?></strong></div>
      <div class="small">Branch: <strong><?= htmlspecialchars($e['branch']) ?></strong></div>
    </div>
  </div>

  <table class="table table-bordered table-sm mb-3">
    <tr><td class="lbl">Employee Name</td><td class="fw-bold"><?= htmlspecialchars($e['name']) ?></td><td class="lbl">Date of Joining</td><td><?= fmt_date($e['joined']) ?></td></tr>
    <tr><td class="lbl">Designation</td><td><?= htmlspecialchars($e['designation']) ?></td><td class="lbl">Branch Serving</td><td><?= htmlspecialchars($e['branch']) ?></td></tr>
    <tr><td class="lbl">Mobile Number</td><td><?= htmlspecialchars($e['phone']) ?></td><td class="lbl">Email</td><td><?= htmlspecialchars($e['email'] ?: '-') ?></td></tr>
    <tr><td class="lbl">Portal Username</td><td><code><?= htmlspecialchars($e['username']) ?></code></td><td class="lbl">System Role</td><td><span class="badge bg-secondary"><?= htmlspecialchars($e['role']) ?></span></td></tr>
    <tr><td class="lbl">Employment Status</td><td><span class="badge bg-success"><?= ucfirst($e['status']) ?></span></td><td class="lbl">Background Check</td><td><?= ucfirst($e['bg_check']) ?></td></tr>
  </table>

  <div class="fw-bold mb-2">Submitted Statutory Documents</div>
  <table class="table table-bordered table-sm mb-4">
    <thead class="table-light">
      <tr>
        <th>Document Type</th>
        <th class="text-center" style="width: 25%;">Verification Status</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($allDocs as $d): ?>
        <tr>
          <td><?= $d ?></td>
          <td class="text-center"><?= in_array($d, $docs) ? '<span class="text-success fw-bold">✔ Verified</span>' : '<span class="text-muted">☐ Pending</span>' ?></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>

  <div class="row text-center mt-5">
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Employee Signature</div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">HR & Operations Head</div>
    </div>
    <div class="col-4">
      <div style="height: 35px; border-bottom: 1px solid #000;"></div>
      <div class="small fw-semibold mt-1">Branch Manager</div>
    </div>
  </div>
</div>
</body>
</html>
