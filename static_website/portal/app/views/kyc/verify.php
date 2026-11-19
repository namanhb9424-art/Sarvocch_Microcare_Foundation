<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-shield-check me-2"></i>KYC Verification & Identity Registry</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Digital Identity Validation</div>
  </div>
  <a href="<?= url('/kyc-form/new') ?>" class="btn btn-primary btn-sm">
    <i class="bi bi-person-plus me-1"></i> New Customer KYC Form
  </a>
</div>

<div class="card shadow-sm border-0 mb-4">
  <div class="card-header bg-white py-3">
    <h6 class="fw-bold mb-0">Identity Check Utility</h6>
  </div>
  <div class="card-body p-3">
    <div class="row g-2 align-items-end">
      <div class="col-12 col-md-3">
        <label class="form-label small mb-0">ID Type</label>
        <select id="idKind" class="form-select form-select-sm">
          <option value="aadhaar">Aadhaar Card (UIDAI)</option>
          <option value="pan">PAN Card (NSDL)</option>
          <option value="voter">Voter ID (ECI)</option>
        </select>
      </div>
      <div class="col-12 col-md-4">
        <label class="form-label small mb-0">Identification Number</label>
        <input type="text" id="idNumber" class="form-control form-control-sm" placeholder="Enter Aadhaar/PAN/Voter...">
      </div>
      <div class="col-12 col-md-3">
        <label class="form-label small mb-0">OTP Verification</label>
        <input type="text" id="idOtp" class="form-control form-control-sm" placeholder="Enter OTP (demo: 123456)">
      </div>
      <div class="col-12 col-md-2">
        <button type="button" class="btn btn-sm btn-teal text-white w-100" style="background-color: #0f766e;" onclick="testKyc()">Verify Online</button>
      </div>
    </div>
    <div id="kycRes" class="mt-2 small"></div>
  </div>
</div>

<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Customer Name</th>
          <th>Mobile</th>
          <th>Aadhaar</th>
          <th>PAN</th>
          <th>Branch</th>
          <th>KYC Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($customers as $c): ?>
          <tr>
            <td class="fw-semibold"><?= htmlspecialchars($c['name']) ?></td>
            <td><?= htmlspecialchars($c['phone'] ?: '-') ?></td>
            <td><?= $c['aadhaar'] ? '•••• ' . substr($c['aadhaar'], -4) : '<span class="text-muted">Missing</span>' ?></td>
            <td><?= htmlspecialchars($c['pan'] ?: '-') ?></td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($c['branch'] ?: '-') ?></span></td>
            <td>
              <?php if ($c['kyc_status'] === 'verified'): ?>
                <span class="badge bg-success">Verified</span>
              <?php else: ?>
                <span class="badge bg-warning text-dark">Pending</span>
              <?php endif; ?>
            </td>
            <td class="text-center">
              <a href="<?= url('/crm/' . $c['id'] . '/kyc-form') ?>" class="btn btn-sm btn-outline-primary py-0">Edit KYC</a>
              <?php if ($c['kyc_form_id']): ?>
                <a href="<?= url('/crm/' . $c['id'] . '/kyc-form/print') ?>" target="_blank" class="btn btn-sm btn-outline-secondary py-0">Print</a>
              <?php endif; ?>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>

<script>
function testKyc() {
  const kind = document.getElementById('idKind').value;
  const number = document.getElementById('idNumber').value;
  const otp = document.getElementById('idOtp').value;
  const res = document.getElementById('kycRes');
  res.innerHTML = '<span class="text-muted">Querying validation registry...</span>';

  const fd = new FormData();
  fd.append('kind', kind);
  fd.append('number', number);
  fd.append('otp', otp);
  fd.append('csrf_token', document.querySelector('meta[name="csrf-token"]').content);

  fetch('<?= url("/api/kyc/verify") ?>', {
    method: 'POST',
    body: fd
  })
  .then(r => r.json())
  .then(d => {
    if (d.ok) {
      res.innerHTML = `<span class="text-success"><i class="bi bi-check-circle me-1"></i> ${d.message}</span>`;
    } else {
      res.innerHTML = `<span class="text-danger"><i class="bi bi-x-circle me-1"></i> ${d.message}</span>`;
    }
  })
  .catch(e => {
    res.innerHTML = '<span class="text-danger">Network error validating ID.</span>';
  });
}
</script>
