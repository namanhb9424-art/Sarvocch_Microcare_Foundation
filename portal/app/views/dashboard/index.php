<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-speedometer2 me-2"></i>Executive MFI Dashboard</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Management Operations</div>
  </div>
  <div class="d-flex gap-2">
    <a href="<?= url('/dashboard/details') ?>" class="btn btn-outline-primary btn-sm"><i class="bi bi-grid-3x3-gap me-1"></i> Branch Breakdown</a>
    <a href="<?= url('/reports') ?>" class="btn btn-teal text-white btn-sm" style="background-color: #0f766e;"><i class="bi bi-file-earmark-bar-graph me-1"></i> Executive Reports</a>
  </div>
</div>

<div class="row g-3 mb-4">
  <div class="col-6 col-lg-3">
    <div class="card shadow-sm border-0 border-start border-primary border-4">
      <div class="card-body p-3">
        <div class="text-muted small text-uppercase fw-semibold">Active Loans</div>
        <div class="fs-4 fw-bold mt-1 text-dark"><?= number_format($activeLoans) ?></div>
        <div class="small text-muted">Borrowers: <?= number_format($totalBorrowers) ?></div>
      </div>
    </div>
  </div>

  <div class="col-6 col-lg-3">
    <div class="card shadow-sm border-0 border-start border-teal border-4">
      <div class="card-body p-3">
        <div class="text-muted small text-uppercase fw-semibold">Total Disbursed</div>
        <div class="fs-4 fw-bold mt-1 text-teal"><?= inr($totalDisbursed) ?></div>
        <div class="small text-muted">Outstanding: <?= inr($totalOutstanding) ?></div>
      </div>
    </div>
  </div>

  <div class="col-6 col-lg-3">
    <div class="card shadow-sm border-0 border-start border-success border-4">
      <div class="card-body p-3">
        <div class="text-muted small text-uppercase fw-semibold">Total Collections</div>
        <div class="fs-4 fw-bold mt-1 text-success"><?= inr($totalCollected) ?></div>
        <div class="small text-muted">Recovery Efficiency: 99.1%</div>
      </div>
    </div>
  </div>

  <div class="col-6 col-lg-3">
    <div class="card shadow-sm border-0 border-start border-warning border-4">
      <div class="card-body p-3">
        <div class="text-muted small text-uppercase fw-semibold">Action Queue</div>
        <div class="fs-4 fw-bold mt-1 text-dark"><?= $pendingApps ?></div>
        <div class="small text-danger fw-semibold">Overdue EMIs: <?= $overdueCount ?></div>
      </div>
    </div>
  </div>
</div>

<div class="row g-4">
  <!-- Recent Applications -->
  <div class="col-12 col-lg-6">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-file-earmark-plus me-1 text-teal"></i>Recent Loan Applications</h6>
        <a href="<?= url('/applications') ?>" class="small text-teal text-decoration-none">View All →</a>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>ID</th>
              <th>Applicant</th>
              <th>Product</th>
              <th class="text-end">Amount</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($recentApps as $ra): ?>
              <tr>
                <td>#<?= $ra['id'] ?></td>
                <td class="fw-semibold"><a href="<?= url('/applications/' . $ra['id']) ?>" class="text-dark text-decoration-none"><?= htmlspecialchars($ra['customer_name']) ?></a></td>
                <td><?= htmlspecialchars($ra['product_name']) ?></td>
                <td class="text-end fw-semibold"><?= inr($ra['amount']) ?></td>
                <td><span class="badge bg-secondary text-capitalize"><?= $ra['status'] ?></span></td>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($recentApps)): ?>
              <tr><td colspan="5" class="text-center text-muted py-3">No applications submitted yet.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- Recent Payments -->
  <div class="col-12 col-lg-6">
    <div class="card shadow-sm border-0 h-100">
      <div class="card-header bg-white py-3 d-flex justify-content-between align-items-center">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-cash-coin me-1 text-success"></i>Recent Collections & Recoveries</h6>
        <a href="<?= url('/loans') ?>" class="small text-teal text-decoration-none">View Loans →</a>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>Loan #</th>
              <th>Borrower</th>
              <th>Channel</th>
              <th class="text-end">Amount</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($recentPayments as $rp): ?>
              <tr>
                <td><a href="<?= url('/loans/' . $rp['loan_id']) ?>" class="text-teal fw-semibold">#<?= $rp['loan_id'] ?></a></td>
                <td><?= htmlspecialchars($rp['customer_name'] ?? 'Borrower') ?></td>
                <td><span class="badge bg-light text-dark border"><?= $rp['channel'] ?></span></td>
                <td class="text-end fw-bold text-success"><?= inr($rp['amount']) ?></td>
                <td class="text-muted"><?= fmt_date($rp['at']) ?></td>
              </tr>
            <?php endforeach; ?>
            <?php if (empty($recentPayments)): ?>
              <tr><td colspan="5" class="text-center text-muted py-3">No collections recorded yet.</td></tr>
            <?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
