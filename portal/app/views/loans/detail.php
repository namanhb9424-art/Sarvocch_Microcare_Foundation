<div class="d-flex justify-content-between align-items-center mb-4">
  <div>
    <h3 class="fw-bold mb-0 text-teal">Loan #<?= $l['id'] ?> · <?= htmlspecialchars($l['customer_name']) ?></h3>
    <div class="text-muted small">SARVOOCCH Microcare Foundation · <?= htmlspecialchars($l['product_name']) ?></div>
  </div>
  <div class="d-flex gap-2">
    <a href="<?= url('/pay/' . $l['id']) ?>" class="btn btn-success btn-sm"><i class="bi bi-cash me-1"></i> Collect EMI</a>
    <?php if ($l['status'] === 'active' && $settleQuote): ?>
      <a href="<?= url('/loans/' . $l['id'] . '/settle') ?>" class="btn btn-warning btn-sm text-dark"><i class="bi bi-check-all me-1"></i> Foreclosure / Settle</a>
    <?php endif; ?>
    <?php if ($l['status'] === 'closed'): ?>
      <a href="<?= url('/loans/' . $l['id'] . '/noc.pdf') ?>" target="_blank" class="btn btn-outline-danger btn-sm"><i class="bi bi-file-earmark-check me-1"></i> Download NOC</a>
    <?php endif; ?>
    <a href="<?= url('/loans/' . $l['id'] . '/kfs.pdf') ?>" target="_blank" class="btn btn-outline-primary btn-sm"><i class="bi bi-file-earmark-text me-1"></i> RBI KFS</a>
    <a href="<?= url('/loans/' . $l['id'] . '/card') ?>" target="_blank" class="btn btn-outline-secondary btn-sm"><i class="bi bi-printer me-1"></i> Passbook Card</a>
  </div>
</div>

<div class="row g-4">
  <!-- Key Loan Parameters -->
  <div class="col-12 col-lg-4">
    <div class="card shadow-sm border-0 mb-4">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark">Loan Information</h6>
      </div>
      <div class="card-body p-3 small">
        <div class="mb-2"><strong>Borrower:</strong> <?= htmlspecialchars($l['customer_name']) ?></div>
        <div class="mb-2"><strong>Mobile:</strong> <?= htmlspecialchars($l['phone'] ?: '-') ?></div>
        <div class="mb-2"><strong>Principal:</strong> <span class="fs-6 fw-bold text-dark"><?= inr($l['principal']) ?></span></div>
        <div class="mb-2"><strong>Interest Rate:</strong> <?= $l['rate'] ?>% p.a. (<?= ucfirst($l['method']) ?>)</div>
        <div class="mb-2"><strong>Monthly EMI:</strong> <span class="fs-6 fw-bold text-teal"><?= inr($l['emi']) ?></span></div>
        <div class="mb-2"><strong>Tenure:</strong> <?= $l['tenure'] ?> Months</div>
        <div class="mb-2"><strong>Disbursed Date:</strong> <?= fmt_date($l['start_date']) ?></div>
        <div class="mb-2"><strong>Branch:</strong> <?= htmlspecialchars($l['branch']) ?></div>
        <div class="mb-3"><strong>Status:</strong> <span class="badge bg-<?= ($l['status'] === 'active') ? 'success' : 'secondary' ?>"><?= ucfirst($l['status']) ?></span></div>

        <?php if ($settleQuote && $l['status'] === 'active'): ?>
          <div class="p-2 border rounded bg-light">
            <div class="text-muted" style="font-size: 0.75rem;">Full Pre-Closure Quote</div>
            <div class="fw-bold fs-6 text-dark"><?= inr($settleQuote['total']) ?></div>
            <div class="text-success" style="font-size: 0.7rem;">Saves <?= inr($settleQuote['saved']) ?> in future interest!</div>
          </div>
        <?php endif; ?>
      </div>
    </div>

    <!-- Payments Ledger -->
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-receipt me-1"></i>Collections Ledger</h6>
      </div>
      <div class="card-body p-3 small" style="max-height: 250px; overflow-y: auto;">
        <?php foreach ($payments as $p): ?>
          <div class="p-2 border-bottom">
            <div class="d-flex justify-content-between align-items-center">
              <div>
                <span class="fw-bold text-success"><?= inr($p['amount']) ?></span>
                <span class="badge bg-light text-dark border ms-1"><?= $p['channel'] ?></span>
              </div>
              <a href="<?= url('/loans/' . $l['id'] . '/receipt/' . $p['id']) ?>" target="_blank" class="btn btn-outline-primary btn-sm py-0 px-2" style="font-size: 11px;">
                <i class="bi bi-printer me-1"></i>Receipt
              </a>
            </div>
            <div class="text-muted" style="font-size: 0.75rem;">Ref: <?= htmlspecialchars($p['ref'] ?: '-') ?> · <?= fmt_date($p['at']) ?></div>
          </div>
        <?php endforeach; ?>
        <?php if (empty($payments)): ?>
          <div class="text-muted text-center py-2">No collections recorded yet.</div>
        <?php endif; ?>
      </div>
    </div>
  </div>

  <!-- Repayment Schedule -->
  <div class="col-12 col-lg-8">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-calendar-check me-1 text-teal"></i>Equated Monthly Instalment (EMI) Schedule</h6>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0 small">
          <thead class="table-light">
            <tr>
              <th>#</th>
              <th>Due Date</th>
              <th class="text-end">Instalment</th>
              <th class="text-end">Principal</th>
              <th class="text-end">Interest</th>
              <th class="text-end">Closing Balance</th>
              <th class="text-center">Status</th>
            </tr>
          </thead>
          <tbody>
            <?php foreach ($schedule as $s): ?>
              <tr class="<?= $s['paid'] ? 'table-success bg-opacity-10' : '' ?>">
                <td><?= $s['no'] ?></td>
                <td><?= fmt_date($s['due_date']) ?></td>
                <td class="text-end fw-bold"><?= inr($s['emi']) ?></td>
                <td class="text-end"><?= inr($s['principal']) ?></td>
                <td class="text-end"><?= inr($s['interest']) ?></td>
                <td class="text-end fw-semibold"><?= inr($s['balance']) ?></td>
                <td class="text-center">
                  <?php if ($s['paid']): ?>
                    <span class="badge bg-success">Paid <?= fmt_date($s['paid_on']) ?></span>
                  <?php else: ?>
                    <span class="badge bg-light text-dark border">Pending</span>
                  <?php endif; ?>
                </td>
              </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
