<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-building me-2"></i><?= htmlspecialchars($b['name']) ?> (<?= htmlspecialchars($b['code']) ?>)</h3>
    <div class="text-muted small">Branch Profile & Operational Jurisdiction</div>
  </div>
  <a href="<?= url('/branches') ?>" class="btn btn-outline-secondary btn-sm">Back</a>
</div>

<div class="row g-4 mb-4">
  <div class="col-12 col-lg-5">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Branch Parameters</h6>
      </div>
      <div class="card-body p-3 small">
        <div class="mb-2"><strong>Code:</strong> <span class="badge bg-teal text-white"><?= htmlspecialchars($b['code']) ?></span></div>
        <div class="mb-2"><strong>Address:</strong> <?= htmlspecialchars($b['address'] ?: '-') ?></div>
        <div class="mb-2"><strong>Phone:</strong> <?= htmlspecialchars($b['phone'] ?: '-') ?></div>
        <div class="mb-2"><strong>Branch Head:</strong> <?= htmlspecialchars($b['head_name'] ?: 'Not Assigned') ?></div>
        <div class="mb-2"><strong>Geofence Radius:</strong> <?= $b['radius_m'] ?> meters</div>
        <div><strong>Status:</strong> <span class="badge bg-success">Active</span></div>
      </div>
    </div>

    <!-- Staff Assigned -->
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-people me-1"></i>Staff Assigned to Branch (<?= count($staff) ?>)</h6>
      </div>
      <div class="card-body p-3 small">
        <?php foreach ($staff as $s): ?>
          <div class="d-flex justify-content-between py-1 border-bottom">
            <span><?= htmlspecialchars($s['name']) ?></span>
            <span class="badge bg-light text-dark border"><?= $s['role'] ?></span>
          </div>
        <?php endforeach; ?>
      </div>
    </div>
  </div>

  <div class="col-12 col-lg-7">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-cash-coin me-1"></i>Recent Loans in Branch</h6>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>Loan #</th>
              <th>Borrower</th>
              <th>Product</th>
              <th class="text-end">Principal</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($loans as $l): ?>
              <tr>
                <td><strong>#<?= $l['id'] ?></strong></td>
                <td><a href="<?= url('/loans/' . $l['id']) ?>" class="text-teal text-decoration-none fw-semibold"><?= htmlspecialchars($l['customer_name']) ?></a></td>
                <td><?= htmlspecialchars($l['product_name']) ?></td>
                <td class="text-end fw-bold"><?= inr($l['principal']) ?></td>
                <td><span class="badge bg-<?= ($l['status'] === 'active') ? 'success' : 'secondary' ?>"><?= $l['status'] ?></span></td>
              </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
