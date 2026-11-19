<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Customer Login Credentials Slip</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<style>
  body { background: #f8fafc; font-size: 13px; }
  .slip { max-width: 550px; margin: 30px auto; background: #fff; padding: 24px; border: 1px dashed #cbd5e1; border-radius: 8px; }
  @media print { .no-print { display: none !important; } .slip { border: 1px solid #000; margin: 0; } }
</style>
</head>
<body>
<div class="slip">
  <div class="no-print d-flex justify-content-between mb-3">
    <button onclick="window.print()" class="btn btn-primary btn-sm">Print Slip</button>
    <a href="<?= url('/crm/' . $c['id']) ?>" class="btn btn-outline-secondary btn-sm">Back to Customer</a>
  </div>

  <div class="text-center mb-3">
    <h4 class="fw-bold mb-0">SARVOOCCH Microcare Foundation</h4>
    <div class="small text-muted">BORROWER PORTAL LOGIN CREDENTIALS / ग्राहक लॉगिन पर्ची</div>
  </div>

  <table class="table table-bordered table-sm mb-3">
    <tr>
      <td class="bg-light fw-bold" style="width: 35%;">Customer Name</td>
      <td class="fw-semibold"><?= htmlspecialchars($c['name']) ?></td>
    </tr>
    <tr>
      <td class="bg-light fw-bold">Customer ID</td>
      <td>#<?= $c['id'] ?></td>
    </tr>
    <tr>
      <td class="bg-light fw-bold">Branch</td>
      <td><?= htmlspecialchars($c['branch']) ?></td>
    </tr>
    <tr>
      <td class="bg-light fw-bold">Portal URL</td>
      <td><strong>https://sarvocchfinance.com/portal</strong></td>
    </tr>
    <tr class="table-warning">
      <td class="fw-bold">Login Username</td>
      <td><kbd class="fs-6"><?= htmlspecialchars($temp['username'] ?? $u['username'] ?? '') ?></kbd></td>
    </tr>
    <tr class="table-warning">
      <td class="fw-bold">Temporary Password</td>
      <td><kbd class="fs-6"><?= htmlspecialchars($temp['password'] ?? '********') ?></kbd></td>
    </tr>
  </table>

  <div class="alert alert-info small mb-3">
    <strong>सुरक्षा निर्देश / Security Instructions:</strong><br>
    1. Visit <code>https://sarvocchfinance.com/portal</code> on your mobile phone browser.<br>
    2. Enter your username and temporary password provided above.<br>
    3. You will be prompted to set your personal secret password upon first login.<br>
    4. You can view your loan schedule, payments, and download NOC directly from the portal.
  </div>

  <div class="row text-center mt-4">
    <div class="col-6">
      <div style="height: 40px; border-bottom: 1px solid #000;"></div>
      <div class="small mt-1">Authorized Branch Signature</div>
    </div>
    <div class="col-6">
      <div style="height: 40px; border-bottom: 1px solid #000;"></div>
      <div class="small mt-1">Customer Acknowledgement</div>
    </div>
  </div>
</div>
</body>
</html>
