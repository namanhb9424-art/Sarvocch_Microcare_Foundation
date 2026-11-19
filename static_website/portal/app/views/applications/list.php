<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-files me-2"></i>Loan Applications Pipeline</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Underwriting & Multi-Tier Approvals</div>
  </div>
  <a href="<?= url('/apply') ?>" class="btn btn-primary btn-sm">
    <i class="bi bi-file-earmark-plus me-1"></i> New Application
  </a>
</div>

<!-- Filter Bar -->
<div class="card shadow-sm border-0 mb-3">
  <div class="card-body p-3">
    <form method="get" action="<?= url('/applications') ?>" class="row g-2 align-items-end">
      <div class="col-6 col-md-4">
        <label class="form-label small mb-0">Status</label>
        <select name="status" class="form-select form-select-sm">
          <option value="">All Statuses</option>
          <option value="submitted" <?= ($selectedStatus === 'submitted') ? 'selected' : '' ?>>Submitted</option>
          <option value="approved" <?= ($selectedStatus === 'approved') ? 'selected' : '' ?>>Approved</option>
          <option value="disbursed" <?= ($selectedStatus === 'disbursed') ? 'selected' : '' ?>>Disbursed</option>
          <option value="rejected" <?= ($selectedStatus === 'rejected') ? 'selected' : '' ?>>Rejected</option>
        </select>
      </div>

      <div class="col-6 col-md-4">
        <label class="form-label small mb-0">Branch</label>
        <select name="branch" class="form-select form-select-sm">
          <option value="">All Branches</option>
          <?php foreach (Database::getBranches() as $b): ?>
            <option value="<?= htmlspecialchars($b) ?>" <?= ($selectedBranch === $b) ? 'selected' : '' ?>><?= htmlspecialchars($b) ?></option>
          <?php endforeach; ?>
        </select>
      </div>

      <div class="col-12 col-md-4 d-flex gap-1">
        <button type="submit" class="btn btn-sm btn-primary flex-fill">Apply Filter</button>
        <a href="<?= url('/applications') ?>" class="btn btn-sm btn-outline-secondary">Reset</a>
      </div>
    </form>
  </div>
</div>

<!-- Table -->
<div class="card shadow-sm border-0">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>App #</th>
          <th>Borrower</th>
          <th>Product</th>
          <th class="text-end">Requested (₹)</th>
          <th class="text-center">Tenure</th>
          <th>Branch</th>
          <th>Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($applications as $a): ?>
          <tr>
            <td><strong>#<?= $a['id'] ?></strong></td>
            <td class="fw-semibold">
              <a href="<?= url('/applications/' . $a['id']) ?>" class="text-teal text-decoration-none">
                <?= htmlspecialchars($a['customer_name']) ?>
              </a>
              <div class="text-muted small"><?= htmlspecialchars($a['phone'] ?: '') ?></div>
            </td>
            <td><?= htmlspecialchars($a['product_name']) ?></td>
            <td class="text-end fw-bold"><?= inr($a['amount']) ?></td>
            <td class="text-center"><?= $a['tenure'] ?> Mos</td>
            <td><span class="badge bg-light text-dark border"><?= htmlspecialchars($a['branch'] ?: '-') ?></span></td>
            <td>
              <?php
              $badgeClass = match($a['status']) {
                  'approved' => 'bg-info text-dark',
                  'disbursed' => 'bg-success',
                  'rejected' => 'bg-danger',
                  default => 'bg-warning text-dark'
              };
              ?>
              <span class="badge <?= $badgeClass ?> text-capitalize"><?= $a['status'] ?></span>
            </td>
            <td class="text-center">
              <a href="<?= url('/applications/' . $a['id']) ?>" class="btn btn-sm btn-outline-primary py-0">Review</a>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($applications)): ?>
          <tr><td colspan="8" class="text-center text-muted py-4">No loan applications found.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
