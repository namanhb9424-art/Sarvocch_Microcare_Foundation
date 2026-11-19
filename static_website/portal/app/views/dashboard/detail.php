<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-grid-3x3-gap me-2"></i>Branch-Level Operations Breakdown</h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Multi-Branch Portfolio Monitoring</div>
  </div>
  <a href="<?= url('/dashboard') ?>" class="btn btn-outline-secondary btn-sm"><i class="bi bi-arrow-left me-1"></i> Back to Dashboard</a>
</div>

<div class="card shadow-sm border-0 mb-4">
  <div class="table-responsive">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light small text-uppercase">
        <tr>
          <th>Branch Name</th>
          <th class="text-center">Active Loans</th>
          <th class="text-end">Total Disbursed (₹)</th>
          <th class="text-end">Outstanding Principal (₹)</th>
          <th class="text-end">Total Collections (₹)</th>
          <th class="text-center">Action</th>
        </tr>
      </thead>
      <tbody>
        <?php foreach ($breakdown as $b): ?>
          <tr>
            <td class="fw-semibold">
              <i class="bi bi-building me-1 text-teal"></i> <?= htmlspecialchars($b['branch']) ?>
            </td>
            <td class="text-center"><?= number_format($b['active_loans']) ?></td>
            <td class="text-end"><?= inr($b['disbursed']) ?></td>
            <td class="text-end fw-bold text-teal"><?= inr($b['outstanding']) ?></td>
            <td class="text-end text-success fw-bold"><?= inr($b['collected']) ?></td>
            <td class="text-center">
              <a href="<?= url('/loans?branch=' . urlencode($b['branch'])) ?>" class="btn btn-sm btn-outline-primary py-0">View Loans</a>
            </td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</div>
