<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal">Application #<?= $a['id'] ?> · <?= htmlspecialchars($a['customer_name']) ?></h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · Underwriting Dossier</div>
  </div>
  <div class="d-flex gap-2">
    <a href="<?= url('/applications/' . $a['id'] . '/sanction.pdf') ?>" target="_blank" class="btn btn-outline-danger btn-sm">
      <i class="bi bi-file-earmark-pdf me-1"></i> Sanction Letter
    </a>
    <a href="<?= url('/applications') ?>" class="btn btn-outline-secondary btn-sm">Back</a>
  </div>
</div>

<div class="row g-4">
  <!-- Application Summary -->
  <div class="col-12 col-lg-7">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Loan Assessment Details</h6>
      </div>
      <div class="card-body p-3">
        <table class="table table-bordered table-sm mb-0">
          <tr><td class="bg-light fw-semibold" style="width: 35%;">Borrower Name</td><td class="fw-bold"><?= htmlspecialchars($a['customer_name']) ?></td></tr>
          <tr><td class="bg-light fw-semibold">Product Scheme</td><td><?= htmlspecialchars($a['product_name']) ?></td></tr>
          <tr><td class="bg-light fw-semibold">Sanction Amount</td><td class="fs-5 fw-bold text-teal"><?= inr($a['amount']) ?></td></tr>
          <tr><td class="bg-light fw-semibold">Interest Rate</td><td><?= $a['rate'] ?>% p.a. (<?= ucfirst($a['product_method']) ?>)</td></tr>
          <tr><td class="bg-light fw-semibold">Tenure</td><td><?= $a['tenure'] ?> Monthly Instalments</td></tr>
          <tr><td class="bg-light fw-semibold">Calculated EMI</td><td class="fw-bold text-dark"><?= inr($previewEmi) ?> / month</td></tr>
          <tr><td class="bg-light fw-semibold">Processing Fee (1.5%)</td><td><?= inr($feeSplit['fee']) ?> + GST <?= inr($feeSplit['cgst'] * 2) ?> = <strong><?= inr($feeSplit['total']) ?></strong></td></tr>
          <tr><td class="bg-light fw-semibold">Purpose</td><td><?= htmlspecialchars($a['purpose'] ?: 'Grassroots Enterprise Expansion') ?></td></tr>
          <tr><td class="bg-light fw-semibold">Co-Borrower</td><td><?= htmlspecialchars($a['co_name'] ?: 'None') ?> (<?= htmlspecialchars($a['co_relation'] ?: '-') ?>)</td></tr>
          <tr><td class="bg-light fw-semibold">Current Application Status</td><td><span class="badge bg-primary text-uppercase"><?= $a['status'] ?></span></td></tr>
        </table>
      </div>
    </div>

    <!-- Approvals Trail -->
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Audit & Multi-Stage Approvals Trail</h6>
      </div>
      <div class="card-body p-3">
        <div class="timeline small">
          <?php foreach ($approvals as $ap): ?>
            <div class="p-2 border-bottom">
              <div class="d-flex justify-content-between fw-semibold">
                <span><?= htmlspecialchars($ap['stage']) ?> by <?= htmlspecialchars($ap['by_user']) ?> (<?= htmlspecialchars($ap['by_role']) ?>)</span>
                <span class="text-muted"><?= fmt_date($ap['at']) ?></span>
              </div>
              <div class="text-muted mt-1"><?= htmlspecialchars($ap['remarks'] ?: 'No remarks.') ?></div>
            </div>
          <?php endforeach; ?>
        </div>
      </div>
    </div>
  </div>

  <!-- Underwriting Decision Actions -->
  <div class="col-12 col-lg-5">
    <div class="card shadow-sm border-0 mb-4 border-top border-teal border-3">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Underwriting Decision Action</h6>
      </div>
      <div class="card-body p-3">
        <?php if ($a['status'] === 'submitted'): ?>
          <form method="post" action="<?= url('/applications/' . $a['id'] . '/action') ?>">
            <?= csrf_field() ?>
            <div class="mb-3">
              <label class="form-label small fw-semibold">Verification & Approval Remarks</label>
              <textarea name="remarks" class="form-control form-control-sm" rows="3" placeholder="Credit committee observations, bureau score remarks..."></textarea>
            </div>
            <div class="d-flex gap-2">
              <button type="submit" name="action" value="approve" class="btn btn-success flex-fill fw-semibold">
                <i class="bi bi-check-circle me-1"></i> Approve Application
              </button>
              <button type="submit" name="action" value="reject" class="btn btn-outline-danger flex-fill">
                <i class="bi bi-x-circle me-1"></i> Reject
              </button>
            </div>
          </form>
        <?php elseif ($a['status'] === 'approved'): ?>
          <div class="alert alert-success small mb-3">
            <i class="bi bi-check-circle-fill me-1"></i> Application is approved. Ready for fund disbursement.
          </div>
          <form method="post" action="<?= url('/applications/' . $a['id'] . '/action') ?>">
            <?= csrf_field() ?>
            <div class="mb-3">
              <label class="form-label small fw-semibold">Disbursement Remarks / Bank Reference</label>
              <input type="text" name="remarks" class="form-control form-control-sm" placeholder="e.g. Disbursed via NEFT/IMPS UTR...">
            </div>
            <button type="submit" name="action" value="disburse" class="btn btn-teal text-white w-100 py-2 fw-semibold" style="background-color: #0f766e;">
              <i class="bi bi-cash-stack me-1"></i> Execute Disbursement & Generate Loan Schedule
            </button>
          </form>
        <?php elseif ($a['status'] === 'disbursed' && $loan): ?>
          <div class="alert alert-info small mb-0">
            <strong>Disbursed:</strong> Loan #<?= $loan['id'] ?> is live in the portfolio.<br>
            <a href="<?= url('/loans/' . $loan['id']) ?>" class="btn btn-sm btn-primary mt-2">Open Loan & EMI Card →</a>
          </div>
        <?php else: ?>
          <div class="badge bg-secondary p-2 w-100"><?= ucfirst($a['status']) ?></div>
        <?php endif; ?>
      </div>
    </div>
  </div>
</div>
