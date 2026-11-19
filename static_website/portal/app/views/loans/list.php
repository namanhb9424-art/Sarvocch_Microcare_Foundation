<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-cash-coin me-2"></i>Active Loans & EMI Schedule</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Portfolio Asset Monitoring</div>
  </div>
  <?php if (can('admin') || can('manager')): ?>
    <form method="post" action="<?= url('/autopay/run') ?>" class="d-inline">
      <?= csrf_field() ?>
      <button type="submit" class="btn btn-outline-success btn-sm" onclick="return confirm('Run automated eNACH batch collection for all due loans today?')">
        <i class="bi bi-play-circle me-1"></i> Trigger eNACH Autopay Cycle
      </button>
    </form>
  <?php endif; ?>
</div>

<!-- Filters -->
<div class="card shadow-sm border-0 mb-3">
  <div class="card-body p-3">
    <form method="get" action="<?= url('/loans') ?>" class="row g-2 align-items-end">
      <div class="col-6 col-md-4">
        <label class="form-label small mb-0">Loan Status</label>
        <select name="status" class="form-select form-select-sm">
          <option value="active" <?= ($selectedStatus === 'active') ? 'selected' : '' ?>>Active Loans</option>
          <option value="closed" <?= ($selectedStatus === 'closed') ? 'selected' : '' ?>>Closed Loans</option>
          <option value="" <?= ($selectedStatus === '') ? 'selected' : '' ?>>All Loans</option>
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
        <button type="submit" class="btn btn-sm btn-primary flex-fill">Filter</button>
        <a href="<?= url('/loans') ?>" class="btn btn-sm btn-outline-secondary">Reset</a>
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
          <th>Loan #</th>
          <th>Borrower</th>
          <th>Product</th>
          <th class="text-end">Principal</th>
          <th class="text-end">Monthly EMI</th>
          <th>Disbursed On</th>
          <th>Status</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($loans as $l): ?>
          <tr>
            <td><strong>#<?= $l['id'] ?></strong></td>
            <td class="fw-semibold">
              <a href="<?= url('/loans/' . $l['id']) ?>" class="text-teal text-decoration-none">
                <?= htmlspecialchars($l['customer_name']) ?>
              </a>
              <div class="text-muted small"><?= htmlspecialchars($l['phone'] ?: '') ?></div>
            </td>
            <td><?= htmlspecialchars($l['product_name']) ?></td>
            <td class="text-end fw-semibold"><?= inr($l['principal']) ?></td>
            <td class="text-end fw-bold text-teal"><?= inr($l['emi']) ?></td>
            <td class="text-muted"><?= fmt_date($l['start_date']) ?></td>
            <td>
              <span class="badge bg-<?= ($l['status'] === 'active') ? 'success' : 'secondary' ?> text-capitalize">
                <?= $l['status'] ?>
              </span>
            </td>
            <td class="text-center">
              <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-sm btn-outline-primary py-0">Open Loan</a>
              <a href="<?= url('/loans/' . $l['id'] . '/card') ?>" target="_blank" class="btn btn-sm btn-outline-secondary py-0">Card</a>
            </td>
          </tr>
        <?php endforeach; ?>
        <?php if (empty($loans)): ?>
          <tr><td colspan="8" class="text-center text-muted py-4">No loan records found.</td></tr>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>
