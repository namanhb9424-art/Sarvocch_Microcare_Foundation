<div class="row justify-content-center">
  <div class="col-12 col-md-6">
    <div class="card shadow-sm border-0">
      <div class="card-header bg-white py-3">
        <h5 class="fw-bold mb-0 text-dark"><i class="bi bi-cash me-2 text-success"></i>Collect Loan EMI Instalment</h5>
      </div>
      <div class="card-body p-4">
        <?php if ($nextEmi): ?>
          <div class="alert alert-light border mb-4">
            <div class="d-flex justify-content-between">
              <span>Borrower: <strong><?= htmlspecialchars($l['customer_name']) ?></strong></span>
              <span>Loan: <strong>#<?= $l['id'] ?></strong></span>
            </div>
            <div class="d-flex justify-content-between mt-2">
              <span>Instalment Due: <strong>#<?= $nextEmi['no'] ?></strong> (Due: <?= fmt_date($nextEmi['due_date']) ?>)</span>
              <span class="fs-5 fw-bold text-success"><?= inr($nextEmi['emi']) ?></span>
            </div>
          </div>

          <form method="post" action="<?= url('/pay/' . $l['id']) ?>">
            <?= csrf_field() ?>
            <input type="hidden" name="schedule_id" value="<?= $nextEmi['id'] ?>">

            <div class="mb-3">
              <label class="form-label small fw-semibold">Payment Channel</label>
              <select name="channel" class="form-select">
                <option value="CASH">Cash Collection (Field Officer)</option>
                <option value="UPI">UPI / QR Code Scan</option>
                <option value="NEFT">Bank Transfer / NEFT / IMPS</option>
                <option value="eNACH">eNACH / Auto-Debit</option>
              </select>
            </div>

            <div class="mb-4">
              <label class="form-label small fw-semibold">Transaction Reference / Receipt No.</label>
              <input type="text" name="ref" class="form-control" placeholder="Optional reference / leave blank for auto-gen">
            </div>

            <div class="d-flex justify-content-between">
              <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-outline-secondary">Cancel</a>
              <button type="submit" class="btn btn-success px-4 fw-semibold">Confirm Payment & Update Ledger</button>
            </div>
          </form>
        <?php else: ?>
          <div class="alert alert-info mb-0">
            All instalments on this loan have already been paid in full!
          </div>
          <div class="mt-3">
            <a href="<?= url('/loans/' . $l['id']) ?>" class="btn btn-primary">Return to Loan</a>
          </div>
        <?php endif; ?>
      </div>
    </div>
  </div>
</div>
