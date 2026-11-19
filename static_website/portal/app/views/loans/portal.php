<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal"><i class="bi bi-wallet2 me-2"></i>My Borrowing Portal</h3>
    <div class="text-muted small">Welcome, <?= htmlspecialchars($customer['name'] ?? 'Borrower') ?> · SARVOOCCH Microcare Foundation</div>
  </div>
</div>

<div class="row g-4">
  <?php foreach ($loans as $l): ?>
    <div class="col-12 col-lg-6">
      <div class="card shadow-sm border-0 border-top border-teal border-3 h-100">
        <div class="card-body p-4">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <span class="badge bg-teal text-white" style="background-color: #0f766e;">Loan #<?= $l['id'] ?></span>
            <span class="badge bg-<?= ($l['status'] === 'active') ? 'success' : 'secondary' ?>"><?= ucfirst($l['status']) ?></span>
          </div>

          <h5 class="fw-bold text-dark"><?= htmlspecialchars($l['product_name']) ?></h5>
          
          <div class="row g-2 my-2 small">
            <div class="col-6">
              <span class="text-muted">Loan Amount:</span><br>
              <strong><?= inr($l['principal']) ?></strong>
            </div>
            <div class="col-6">
              <span class="text-muted">Monthly EMI:</span><br>
              <strong class="text-teal fs-6"><?= inr($l['emi']) ?></strong>
            </div>
            <div class="col-6">
              <span class="text-muted">Tenure:</span><br>
              <?= $l['tenure'] ?> Instalments
            </div>
            <div class="col-6">
              <span class="text-muted">Branch:</span><br>
              <?= htmlspecialchars($l['branch']) ?>
            </div>
          </div>

          <div class="d-flex gap-2 mt-4 pt-3 border-top">
            <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-primary btn-sm flex-fill">View EMI Schedule</a>
            <a href="<?= url('/loans/' . $l['id'] . '/card') ?>" target="_blank" class="btn btn-outline-secondary btn-sm flex-fill">Passbook</a>
            <?php if ($l['status'] === 'closed'): ?>
              <a href="<?= url('/loans/' . $l['id'] . '/noc.pdf') ?>" target="_blank" class="btn btn-outline-success btn-sm flex-fill">NOC</a>
            <?php endif; ?>
          </div>
        </div>
      </div>
    </div>
  <?php endforeach; ?>
  <?php if (empty($loans)): ?>
    <div class="col-12 text-center text-muted py-5">
      <i class="bi bi-wallet2 fs-1 text-muted"></i>
      <p class="mt-2">No active loans found under your borrower account.</p>
    </div>
  <?php endif; ?>
</div>
